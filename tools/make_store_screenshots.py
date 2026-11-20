#!/usr/bin/env python3
"""Frame the raw phone captures in `store/raw/` for the Play Store listing.

    python3 tools/make_store_screenshots.py

Raw captures are 1220x2712 (Xiaomi 12T, 20:9) — too tall for Play, which caps a
screenshot at 2:1. Each one is cropped to app content (status bar and the ad
banner strip removed), then centred on a 1080x1920 marketing canvas with a
caption, which satisfies the ratio rule as well as looking deliberate.

`store/raw/` holds the untouched device captures so the framing can be redone
without touching the phone again.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store" / "raw"
OUT = ROOT / "store" / "assets" / "screenshots"

W, H = 1080, 1920
SS = 2

# Device crops: the 12T draws a 100px status bar and a ~190px ad/nav strip.
CROP_TOP = 96
CROP_BOTTOM = 200
# Per-capture overrides: the Settings list sits higher than the tab bar, so its
# ad strip needs a deeper cut or the banner would ride along inside the card.
CROP_OVERRIDES = {"settings": (96, 340), "questions": (96, 110)}

TOP = (20, 10, 44)
BOTTOM = (74, 36, 156)
INK = (255, 255, 255, 255)
MUTED = (208, 194, 255, 255)

CAPTIONS = [
    ("home", "Practice anytime", "Your own questions, one recall at a time"),
    ("question", "Your questions, your words", "No pre-made decks — it is your material"),
    ("answer", "Reveal, check, repeat", "Self-testing beats re-reading"),
    ("questions", "Organise by topic", "Unlimited questions and categories"),
    ("settings", "Reminders that fit your day", "Pick the days, the time and the frequency"),
]


def L(n: float) -> int:
    return int(round(n * SS))


def font(size: float, bold: bool = True) -> ImageFont.FreeTypeFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
        if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, L(size))
            except OSError:
                continue
    return ImageFont.load_default()


def gradient(w: int, h: int) -> Image.Image:
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / (h - 1)
        px[0, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
    return strip.resize((w, h), Image.BILINEAR).convert("RGBA")


def glow(size: tuple[int, int], centre: tuple[int, int], radius: int, colour) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    x, y = centre
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=colour)
    return layer.filter(ImageFilter.GaussianBlur(radius // 2))


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width, img.height), radius=radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def centred(draw: ImageDraw.ImageDraw, y: int, text: str, fnt, fill) -> int:
    w = draw.textlength(text, font=fnt)
    draw.text(((W * SS - w) / 2, y), text, font=fnt, fill=fill)
    return int(y + fnt.size)


def frame(name: str, title: str, subtitle: str) -> None:
    raw = Image.open(RAW / f"{name}.png").convert("RGB")
    top_crop, bottom_crop = CROP_OVERRIDES.get(name, (CROP_TOP, CROP_BOTTOM))
    shot = raw.crop((0, top_crop, raw.width, raw.height - bottom_crop))

    canvas = gradient(W * SS, H * SS)
    canvas.alpha_composite(glow((W * SS, H * SS), (L(880), L(120)), L(420), (150, 110, 255, 105)))
    canvas.alpha_composite(glow((W * SS, H * SS), (L(150), L(1800)), L(340), (92, 58, 200, 95)))

    d = ImageDraw.Draw(canvas)
    y = L(112)
    y = centred(d, y, title, font(52), INK) + L(16)
    centred(d, y, subtitle, font(27, bold=False), MUTED)

    # Fit the phone capture into the area under the captions.
    avail_h = L(H - 252 - 56)
    avail_w = L(W - 130)
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, L(26))

    x = (W * SS - shot.width) // 2
    top = L(252)  # captions end here; 56px are kept clear at the bottom

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + L(6), top + L(14), x + shot.width + L(6), top + shot.height + L(14)),
        radius=L(26),
        fill=(0, 0, 0, 130),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(L(14))))
    canvas.alpha_composite(shot, (x, top))

    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.png"
    canvas.convert("RGB").resize((W, H), Image.LANCZOS).save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def main() -> None:
    for name, title, subtitle in CAPTIONS:
        if not (RAW / f"{name}.png").exists():
            print(f"skip {name}: no capture in store/raw/")
            continue
        frame(name, title, subtitle)


if __name__ == "__main__":
    main()
