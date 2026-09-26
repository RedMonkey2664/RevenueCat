"""Does the Discipline Score measure discipline, or one bias?

Mirrors the beginner-mode rule in `lib/features/simulator/engine/
discipline_score.dart` and plays every campaign level with four baselines
plus seeded random play, then asks:

  * can a trivial strategy (always Hold / always Sell / always Buy the Dip)
    score highly across the campaign? If one can, the score is measuring
    that bias rather than the player's nerve.
  * does random play land mid-table, as it should?
  * is any level so lopsided that the score cannot discriminate on it?

The credits are copied from the Dart, and `test/engine/` covers the Dart
itself; if the two ever disagree this script's numbers are the ones to
distrust.

Run: python tool/validation/score_baselines.py
Appends to: docs/VALIDATION_REPORT.md
"""

from __future__ import annotations

import json
import pathlib
import random
import statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEVELS = ROOT / "data" / "simulator_levels"
OUT = ROOT / "docs" / "VALIDATION_REPORT.md"

EXACT, NON_PANIC_MISMATCH, MISSED_EXIT, PANIC = 1.0, 0.6, 0.3, 0.0
ACTIONS = ("hold", "sell", "buy_dip")
RANDOM_RUNS = 10_000
SEED = 20260926


def credit(chose: str, best: str) -> float:
    """The Dart rule, one moment."""
    if chose == best:
        return EXACT
    if chose != "sell" and best != "sell":
        return NON_PANIC_MISMATCH
    if chose == "sell":
        return PANIC
    return MISSED_EXIT


def score(choices: list[str], bests: list[str]) -> float | None:
    """Ambiguous moments are already stripped by the caller."""
    if not bests:
        return None
    total = sum(credit(c, b) for c, b in zip(choices, bests))
    return total / len(bests) * 100


def main() -> int:
    manifest = json.loads((LEVELS / "level_manifest.json").read_text("utf-8"))
    playable = [l for l in manifest["levels"] if l.get("data_status") == "sourced"]

    rng = random.Random(SEED)
    rows = []
    campaign_baselines = {a: [] for a in ACTIONS}
    ambiguous_total = 0

    for entry in playable:
        lid = entry["id"]
        path = LEVELS / f"{lid}_script.json"
        if not path.exists():
            continue
        pps = json.loads(path.read_text("utf-8"))["pause_points"]

        # Ambiguous moments are not scored (see PausePoint.isAmbiguous).
        graded = [p for p in pps if not p.get("derived", {}).get("ambiguous")]
        ambiguous_total += len(pps) - len(graded)
        bests = [p["optimal_action"] for p in graded]
        if not bests:
            continue

        base = {a: score([a] * len(bests), bests) for a in ACTIONS}
        for a in ACTIONS:
            campaign_baselines[a].append(base[a])

        samples = [
            score([rng.choice(ACTIONS) for _ in bests], bests)
            for _ in range(RANDOM_RUNS)
        ]
        samples.sort()
        rows.append(
            {
                "id": lid,
                "n": len(bests),
                "amb": len(pps) - len(graded),
                "hold": base["hold"],
                "sell": base["sell"],
                "buy": base["buy_dip"],
                "mean": statistics.fmean(samples),
                "median": statistics.median(samples),
                "sd": statistics.pstdev(samples),
                "p5": samples[int(0.05 * len(samples))],
                "p95": samples[int(0.95 * len(samples))],
            }
        )

    with OUT.open("a", encoding="utf-8") as w:
        p = lambda *a: print(*a, file=w)
        p("")
        p("## 4. Discipline Score — baselines and random play")
        p("")
        p(
            f"Every level played with each trivial strategy, plus "
            f"{RANDOM_RUNS:,} random call sequences per level "
            f"(seed {SEED}). {ambiguous_total} ambiguous pause points are "
            f"excluded from scoring, as the app excludes them."
        )
        p("")
        p("| Level | Graded calls | Always Hold | Always Sell | Always Buy | Random mean | Random p5–p95 |")
        p("|---|---|---|---|---|---|---|")
        for r in sorted(rows, key=lambda r: -r["hold"]):
            p(
                f"| {r['id']} | {r['n']} | {r['hold']:.0f} | {r['sell']:.0f} | "
                f"{r['buy']:.0f} | {r['mean']:.0f} | {r['p5']:.0f}–{r['p95']:.0f} |"
            )
        p("")

        means = {a: statistics.fmean(v) for a, v in campaign_baselines.items()}
        p("### Across the campaign")
        p("")
        for a in ACTIONS:
            highs = sum(1 for v in campaign_baselines[a] if v >= 90)
            p(
                f"- **Always {a}**: mean {means[a]:.1f}, "
                f"scores 90+ on {highs} of {len(rows)} levels"
            )
        p(f"- **Random play**: mean {statistics.fmean([r['mean'] for r in rows]):.1f}")
        p("")

        worst = max(means, key=means.get)
        if means[worst] >= 75:
            p(
                f"> **The score is farmable.** Always {worst} averages "
                f"{means[worst]:.0f} without the player reading anything. "
                f"See 'Needs owner decision'."
            )
        else:
            p(
                f"No trivial strategy beats {means[worst]:.0f} on average "
                f"(best is always {worst}), and random play sits near the "
                f"middle, so the score is not reducible to one button."
            )
        p("")
        flat = [r for r in rows if r["p95"] - r["p5"] < 20]
        if flat:
            p(
                "Levels where random play barely spreads (p95 − p5 < 20), so "
                "the score hardly discriminates: "
                + ", ".join(f"`{r['id']}`" for r in flat)
            )
        else:
            p("Every level spreads random play by at least 20 points.")

    print(f"levels={len(rows)} ambiguous_excluded={ambiguous_total}")
    for a in ACTIONS:
        print(f"always {a}: mean {statistics.fmean(campaign_baselines[a]):.1f}")
    print(f"random: mean {statistics.fmean([r['mean'] for r in rows]):.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
