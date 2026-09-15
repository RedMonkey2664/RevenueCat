"""Turn a green-screen mascot export into an app-ready clip.

    python tool/mascot/key_clip.py <source.mp4> <use-name> [key-colour]

    e.g. python tool/mascot/key_clip.py assets/mascot/Kitten_waves.mp4 welcome

Google Flow exports the mascot on a chroma-green ground. The app plays clips
as ordinary H.264, because alpha video does not play on every platform the
app ships to, so the key is baked in once, here:

  * the green becomes the HUD ground #0A0E13, so the clip sits seamlessly on
    any screen that uses the app's background,
  * green spill on the fur and jewels is removed,
  * the audio track is dropped (mascot clips always play silent),
  * the frame is scaled to 540x960 — ample for the largest place a clip is
    shown — and written with faststart so the web can begin playing it
    before it has fully downloaded.

The output is assets/mascot/<use-name>.mp4. Add the file to pubspec.yaml and
a value to MascotClip in lib/app/widgets/mascot.dart.

Needs ffmpeg; `pip install imageio-ffmpeg` provides one.
"""

import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg

GROUND = "0x0A0E13"
DEFAULT_KEY = "0x21C537"  # Flow's green, sampled from its exports.


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    name = sys.argv[2]
    key = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_KEY
    out = Path("assets/mascot") / f"{name}.mp4"

    # The ground is the HUD's #0A0E13 with a soft light behind the character:
    # a black cat on a black page loses its silhouette. The light falls off to
    # exactly the page colour at the edges, so the clip still has no visible
    # border on any screen that uses the app's background.
    glow = "exp(-((X-W/2)*(X-W/2)+(Y-H*0.56)*(Y-H*0.56))/(2*(W*0.42)*(W*0.42)))"
    graph = (
        "color=c=black:s=540x960:r=24,format=rgb24,"
        f"geq=r='10+12*{glow}':g='14+18*{glow}':b='19+26*{glow}'[ground];"
        f"[0:v]scale=540:960,chromakey={key}:0.17:0.07,"
        "despill=type=green:mix=0.6:expand=0.15[cat];"
        "[ground][cat]overlay=shortest=1,format=yuv420p"
    )
    subprocess.run(
        [
            imageio_ffmpeg.get_ffmpeg_exe(),
            "-v", "error", "-y",
            "-i", str(source),
            "-filter_complex", graph,
            "-an",
            "-c:v", "libx264", "-preset", "slow", "-crf", "23",
            "-movflags", "+faststart",
            str(out),
        ],
        check=True,
    )
    print(f"{out}  {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
