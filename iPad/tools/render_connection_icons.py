#!/usr/bin/env python3
"""Renders the profile connection logos to PNG.

UIImage can't decode SVG, so iPadOS loads these instead of the macOS app's files. The
build flattens resource folders, so a prefix keeps them apart from the app's own PNGs.
Run after the logos change: `python3 iPad/tools/render_connection_icons.py`.
"""
import pathlib
import subprocess

IPAD = pathlib.Path(__file__).resolve().parent.parent
SOURCE = IPAD.parent / "App/Sources/SakuraCord/Resources/ConnectionIcons"
OUT = IPAD / "Sources/SakuraCord/Resources/ConnectionIconsPNG"
SIZE = 120


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for stale in OUT.glob("*.png"):
        stale.unlink()
    for svg in sorted(SOURCE.glob("*.svg")):
        subprocess.run(
            ["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE), "--keep-aspect-ratio", str(svg),
             "-o", str(OUT / f"pad-{svg.stem}.png")],
            check=True,
        )


if __name__ == "__main__":
    main()
