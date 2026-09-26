"""Renders PRIVACY.md and TERMS.md into the web build as standalone pages.

The App Store requires a subscription paywall to link to Terms of Use and a
Privacy Policy, and those links have to resolve on the open web. Keeping the
markdown as the single source and generating the pages means the app's links
and the repo's documents cannot drift apart.

Output lands in `web/`, which Flutter copies into `build/web` (and so into
`web_dist/`), giving:

    https://<site>/privacy.html
    https://<site>/terms.html

Run: python tool/build_legal_pages.py
"""

from __future__ import annotations

import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAGES = [("PRIVACY.md", "web/privacy.html"), ("TERMS.md", "web/terms.html")]

CSS = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body {
  margin: 0; padding: 48px 20px 96px;
  background: #0A0E13; color: #E4EDF2;
  font: 16px/1.65 "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
}
main { max-width: 680px; margin: 0 auto; }
a { color: #F2712C; }
h1 { font-size: 30px; letter-spacing: .01em; margin: 0 0 4px; }
h2 { font-size: 19px; margin: 40px 0 10px; color: #F2712C; }
p, li { color: #C3CED6; }
li { margin: 6px 0; }
code {
  font-family: "JetBrains Mono", ui-monospace, monospace;
  font-size: 14px; color: #5BC8F5;
}
strong { color: #E4EDF2; }
hr { border: 0; border-top: 1px solid #1C2833; margin: 40px 0; }
.back { display: inline-block; margin-bottom: 28px; font-size: 14px; }
footer { margin-top: 56px; color: #56626E; font-size: 13px; }
"""


def inline(text: str) -> str:
    """Escape, then re-apply the small markdown subset these files use."""
    t = html.escape(text)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    t = re.sub(r"&lt;(https?://[^&]+)&gt;", r'<a href="\1">\1</a>', t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    return t


def render(md: str, title: str) -> str:
    out, in_list = [], False

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            close_list()
            continue
        if line.startswith("# "):
            close_list()
            out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            close_list()
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
        else:
            close_list()
            out.append(f"<p>{inline(line)}</p>")
    close_list()

    body = "\n".join(out)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} — HistoX</title>
<style>{CSS}</style>
</head>
<body>
<main>
<a class="back" href="/">&larr; HistoX</a>
{body}
<footer>HistoX is an educational simulator. It uses virtual capital, places
no real trades, and is not investment advice.</footer>
</main>
</body>
</html>
"""


def main() -> int:
    for src, dest in PAGES:
        md = (ROOT / src).read_text("utf-8")
        title = md.splitlines()[0].lstrip("# ").split("—")[-1].strip()
        (ROOT / dest).write_text(render(md, title), encoding="utf-8")
        print(f"{src} -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
