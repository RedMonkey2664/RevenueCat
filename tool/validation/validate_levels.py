"""Checks every bundled campaign level against its own data.

Offline: it reads `data/simulator_levels/` only. Re-fetching each source
series is a separate job (`refetch_levels.py`) because it needs network and
the provider terms are unsettled; this script is the part that can run
anywhere, including CI.

What it asserts, per level:
  * ordering        - timestamps strictly increasing, no duplicates
  * OHLC sanity     - low <= min(open, close), high >= max(open, close),
                      every price > 0, volume never negative
  * outliers        - single-candle log returns beyond 5 sigma are listed for
                      a human to check against the source, not auto-failed:
                      a real crash contains real outliers, and 1987-10-19 is
                      supposed to be one
  * the crash       - peak-to-trough drawdown inside the played window, when
                      it happened, and whether price recovered before the
                      window ended
  * pause points    - that each trigger_date exists in the series, and the
                      forward return from it over 1, 5 and 20 days and to the
                      end of the window
  * optimal move    - recomputed independently from the series and compared
                      with the stored value

Run: python tool/validation/validate_levels.py
Writes: docs/VALIDATION_REPORT.md
"""

from __future__ import annotations

import json
import math
import pathlib
import statistics
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEVELS = ROOT / "data" / "simulator_levels"
OUT = ROOT / "docs" / "VALIDATION_REPORT.md"

# The rule the recomputation uses, stated so the report can print it and the
# Debrief can quote the same words. It is a hindsight benchmark, not advice.
OPTIMAL_RULE_HORIZON = 20
OPTIMAL_RULE = (
    "From the pause point, compare the next {h} trading days: SELL if price "
    "fell more than 5% below the pause close before recovering to it, BUY THE "
    "DIP if price rose more than 5% above it, HOLD otherwise."
).format(h=OPTIMAL_RULE_HORIZON)


def load(level_id: str):
    prices = json.loads((LEVELS / f"{level_id}.json").read_text("utf-8"))
    script_path = LEVELS / f"{level_id}_script.json"
    script = (
        json.loads(script_path.read_text("utf-8")) if script_path.exists() else None
    )
    return prices, script


def candles(prices) -> list[dict]:
    for key in ("candles", "series", "data"):
        if isinstance(prices, dict) and key in prices:
            return prices[key]
    return prices if isinstance(prices, list) else []


def date_of(c: dict) -> str:
    return str(c.get("date") or c.get("t") or c.get("timestamp"))[:10]


def check_ordering(cs) -> list[str]:
    problems, seen, prev = [], set(), None
    for c in cs:
        d = date_of(c)
        if d in seen:
            problems.append(f"duplicate timestamp {d}")
        seen.add(d)
        if prev is not None and d <= prev:
            problems.append(f"out of order at {d} (after {prev})")
        prev = d
    return problems


def check_ohlc(cs) -> list[str]:
    problems = []
    for i, c in enumerate(cs):
        o, h, l, cl = c["open"], c["high"], c["low"], c["close"]
        if min(o, h, l, cl) <= 0:
            problems.append(f"non-positive price at {date_of(c)} (index {i})")
        if l > min(o, cl) + 1e-9:
            problems.append(f"low above open/close at {date_of(c)}")
        if h < max(o, cl) - 1e-9:
            problems.append(f"high below open/close at {date_of(c)}")
        if (c.get("volume") or 0) < 0:
            problems.append(f"negative volume at {date_of(c)}")
    return problems


def outliers(cs) -> list[str]:
    rets = []
    for a, b in zip(cs, cs[1:]):
        if a["close"] > 0 and b["close"] > 0:
            rets.append(math.log(b["close"] / a["close"]))
    if len(rets) < 30:
        return []
    mu, sd = statistics.fmean(rets), statistics.pstdev(rets)
    if sd == 0:
        return []
    out = []
    for i, r in enumerate(rets):
        z = (r - mu) / sd
        if abs(z) > 5:
            out.append(f"{date_of(cs[i + 1])} {r * 100:+.1f}% ({z:+.1f} sigma)")
    return out


def drawdown(cs):
    """Deepest peak-to-trough fall inside the window."""
    peak, peak_i = cs[0]["close"], 0
    worst = {"depth": 0.0, "peak_i": 0, "trough_i": 0}
    for i, c in enumerate(cs):
        if c["close"] > peak:
            peak, peak_i = c["close"], i
        depth = 1 - c["close"] / peak
        if depth > worst["depth"]:
            worst = {"depth": depth, "peak_i": peak_i, "trough_i": i}
    peak_close = cs[worst["peak_i"]]["close"]
    recovered = next(
        (
            i
            for i in range(worst["trough_i"], len(cs))
            if cs[i]["close"] >= peak_close
        ),
        None,
    )
    worst["recovered_i"] = recovered
    return worst


def forward(cs, i, days):
    j = min(i + days, len(cs) - 1)
    return cs[j]["close"] / cs[i]["close"] - 1


def recompute_optimal(cs, i) -> str:
    """The stated rule, applied to the series. No look-ahead beyond it."""
    base = cs[i]["close"]
    end = min(i + OPTIMAL_RULE_HORIZON, len(cs) - 1)
    lo = min(c["close"] for c in cs[i : end + 1])
    hi = max(c["close"] for c in cs[i : end + 1])
    fell = lo / base - 1 <= -0.05
    rose = hi / base - 1 >= 0.05
    if fell and not rose:
        return "sell"
    if rose and not fell:
        return "buy_dip"
    if fell and rose:
        # Whichever came first is what the player would have lived through.
        first_fall = next(
            i2 for i2 in range(i, end + 1) if cs[i2]["close"] / base - 1 <= -0.05
        )
        first_rise = next(
            i2 for i2 in range(i, end + 1) if cs[i2]["close"] / base - 1 >= 0.05
        )
        return "sell" if first_fall < first_rise else "buy_dip"
    return "hold"


def main() -> int:
    manifest = json.loads((LEVELS / "level_manifest.json").read_text("utf-8"))
    playable = [l for l in manifest["levels"] if l.get("data_status") == "sourced"]

    rows, pause_rows, problems = [], [], []
    stored_moves, recomputed_moves, mismatches = Counter(), Counter(), []
    not_recovered = []

    for entry in playable:
        lid = entry["id"]
        prices, script = load(lid)
        cs = candles(prices)
        if not cs:
            problems.append((lid, "no candles found in the level file"))
            continue

        for p in check_ordering(cs) + check_ohlc(cs):
            problems.append((lid, p))

        dd = drawdown(cs)
        recovered = dd["recovered_i"] is not None
        if not recovered:
            not_recovered.append(lid)

        rows.append(
            {
                "id": lid,
                "market": entry.get("asset_class", "?"),
                "bars": len(cs),
                "from": date_of(cs[0]),
                "to": date_of(cs[-1]),
                "start": cs[0]["close"],
                "trough": cs[dd["trough_i"]]["close"],
                "dd": dd["depth"] * 100,
                "peak_date": date_of(cs[dd["peak_i"]]),
                "trough_date": date_of(cs[dd["trough_i"]]),
                "days_to_trough": dd["trough_i"] - dd["peak_i"],
                "recovery": (
                    dd["recovered_i"] - dd["trough_i"] if recovered else None
                ),
                "outliers": outliers(cs),
            }
        )

        if not script:
            continue
        by_date = {date_of(c): i for i, c in enumerate(cs)}
        for pp in script["pause_points"]:
            d = pp["trigger_date"]
            if d not in by_date:
                problems.append((lid, f"pause point {d} has no candle"))
                continue
            i = by_date[d]
            stored = pp["optimal_action"]
            mine = recompute_optimal(cs, i)
            stored_moves[stored] += 1
            recomputed_moves[mine] += 1
            amb = bool(pp.get("derived", {}).get("ambiguous"))
            if stored != mine and not amb:
                mismatches.append((lid, d, stored, mine))
            pause_rows.append(
                {
                    "id": lid,
                    "date": d,
                    "index": i,
                    "close": cs[i]["close"],
                    "dd": pp.get("derived", {}).get("from_peak_pct"),
                    "f1": forward(cs, i, 1) * 100,
                    "f5": forward(cs, i, 5) * 100,
                    "f20": forward(cs, i, 20) * 100,
                    "fend": (cs[-1]["close"] / cs[i]["close"] - 1) * 100,
                    "stored": stored,
                    "mine": mine,
                    "ambiguous": amb,
                }
            )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    w = OUT.open("w", encoding="utf-8")
    p = lambda *a: print(*a, file=w)

    total_pp = sum(stored_moves.values())
    p("# HistoX — validation report")
    p("")
    p("Generated by `tool/validation/validate_levels.py` from the bundled data.")
    p("No network: this checks the files the app actually ships.")
    p("")
    p("## Summary")
    p("")
    p(f"- Levels checked: **{len(rows)}**")
    p(f"- Data problems found: **{len(problems)}**")
    p(f"- Pause points: **{total_pp}**")
    p(f"- Optimal move mismatches vs the recomputed rule: **{len(mismatches)}**")
    p(
        f"- Levels where price never regained its peak in the window: "
        f"**{len(not_recovered)}** of {len(rows)}"
    )
    p("")

    p("## 1. Level integrity and the crash each level claims")
    p("")
    p("| Level | Market | Bars | Window | Max drawdown | Peak to trough | Recovered in window |")
    p("|---|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda r: -r["dd"]):
        rec = f"{r['recovery']} bars" if r["recovery"] is not None else "**no**"
        p(
            f"| {r['id']} | {r['market']} | {r['bars']} | {r['from']} to {r['to']} | "
            f"**-{r['dd']:.1f}%** | {r['peak_date']} to {r['trough_date']} "
            f"({r['days_to_trough']} bars) | {rec} |"
        )
    p("")

    if problems:
        p("### Problems")
        p("")
        for lid, msg in problems:
            p(f"- `{lid}`: {msg}")
    else:
        p("No ordering, duplicate, OHLC or volume problems in any level.")
    p("")

    p("### Return outliers (beyond 5 sigma)")
    p("")
    p(
        "Listed, not failed. A crash replay is supposed to contain extreme "
        "days; these are the ones worth eyeballing against the source."
    )
    p("")
    any_out = False
    for r in rows:
        if r["outliers"]:
            any_out = True
            p(f"- `{r['id']}`: " + "; ".join(r["outliers"]))
    if not any_out:
        p("- none")
    p("")

    p("## 2. Pause points and the optimal move")
    p("")
    p(f"Recomputation rule: {OPTIMAL_RULE}")
    p("")
    p("Stored distribution: " + ", ".join(f"{k} {v}" for k, v in stored_moves.most_common()))
    p("Recomputed distribution: " + ", ".join(f"{k} {v}" for k, v in recomputed_moves.most_common()))
    p("")
    if stored_moves:
        top, n = stored_moves.most_common(1)[0]
        share = n / total_pp * 100
        p(
            f"The most common stored answer is **{top}** at **{share:.0f}%** of "
            f"pause points."
        )
        if share > 60:
            p("")
            p(
                "> **Survivorship warning.** One answer dominates, so a player "
                "can score well by always pressing it. See 'Needs owner "
                "decision' in AUDIT_REPORT.md."
            )
    p("")
    p("| Level | Date | Fall from peak | +1d | +5d | +20d | To window end | Stored | Recomputed |")
    p("|---|---|---|---|---|---|---|---|---|")
    for r in pause_rows:
        flag = " ⚠" if r["stored"] != r["mine"] and not r["ambiguous"] else ""
        amb = " *(ambiguous)*" if r["ambiguous"] else ""
        dd = f"{r['dd']:.0f}%" if r["dd"] is not None else "?"
        p(
            f"| {r['id']} | {r['date']} | {dd} | {r['f1']:+.1f}% | {r['f5']:+.1f}% | "
            f"{r['f20']:+.1f}% | {r['fend']:+.1f}% | {r['stored']}{amb} | "
            f"{r['mine']}{flag} |"
        )
    p("")
    if mismatches:
        p(f"### {len(mismatches)} mismatches")
        p("")
        p(
            "These are not automatically bugs: the stored value and the rule "
            "above answer slightly different questions. They are the moments "
            "to review by hand."
        )
        p("")
        for lid, d, stored, mine in mismatches:
            p(f"- `{lid}` {d}: stored **{stored}**, rule says **{mine}**")
    p("")

    p("## 3. Recovery mix")
    p("")
    if not_recovered:
        p("Levels where price never regained its pre-crash peak inside the window:")
        p("")
        for lid in not_recovered:
            p(f"- `{lid}`")
    else:
        p(
            "> **Every level recovers inside its window.** A player who always "
            "buys the dip is rewarded everywhere, which teaches a lesson that "
            "is only true of crashes famous enough to be worth shipping. See "
            "'Needs owner decision' in AUDIT_REPORT.md."
        )
    w.close()

    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"levels={len(rows)} problems={len(problems)} pause_points={total_pp} "
          f"mismatches={len(mismatches)} never_recovered={len(not_recovered)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
