#!/usr/bin/env python3
"""Renders the app's custom SF Symbol templates to PNG.

SF Symbols are compiled by actool on macOS. This project is built without it, so
the Regular-M glyph of each template is rasterized into Resources as a template
image. Run after changing a symbol: `python3 iPad/tools/render_symbols.py`.
"""
import pathlib
import re
import subprocess
import tempfile

IPAD = pathlib.Path(__file__).resolve().parent.parent
ASSETS = IPAD.parent / "App/Sources/SakuraCord/Resources/Assets.xcassets"
OUT = IPAD / "Sources/SakuraCord/Resources"
SYMBOLS = {
    "discord.symbolset/discord.svg": "discord",
    "github.symbolset/github.fill.svg": "github",
    "gif.square.symbolset/gif.square.svg": "gif_square",
    "thread.symbolset/thread.svg": "thread",
}
POINT_HEIGHT = 18
# Symbols whose inner contours are holes only under the even-odd rule.
EVEN_ODD = {"gif_square"}


def regular_glyph(svg: str) -> str:
    for group in ("Regular-M", "Regular-S"):
        match = re.search(rf'<g id="{group}"[^>]*>(.*?)</g>', svg, re.S)
        if match:
            return re.sub(r'\sclass="[^"]*"', "", match.group(1))
    raise ValueError("template has no regular glyph")


def main() -> None:
    from PIL import Image

    for relative, name in SYMBOLS.items():
        glyph = regular_glyph((ASSETS / relative).read_text())
        document = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-40 -140 280 240" width="1680" height="1440">'
            f'<g fill="#000" fill-rule="{"evenodd" if name in EVEN_ODD else "nonzero"}">{glyph}</g></svg>'
        )
        with tempfile.NamedTemporaryFile("w", suffix=".svg") as source, tempfile.NamedTemporaryFile(suffix=".png") as large:
            source.write(document)
            source.flush()
            subprocess.run(["rsvg-convert", source.name, "-o", large.name], check=True)
            image = Image.open(large.name).convert("RGBA")
        image = image.crop(image.getchannel("A").getbbox())
        for scale in (2, 3):
            height = POINT_HEIGHT * scale
            width = round(image.width * height / image.height)
            image.resize((width, height), Image.LANCZOS).save(OUT / f"{name}@{scale}x.png")


if __name__ == "__main__":
    main()
