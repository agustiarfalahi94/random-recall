#!/usr/bin/env python3
"""Rebuild the Play Store graphics that are checked into `store/assets/`.

    python3 tools/make_store_graphics.py

Outputs (Play Console requirements):
  store/assets/feature-graphic-en.png   1024x500
  store/assets/feature-graphic-id.png   1024x500
  store/assets/play-store-icon-512.png  512x512, 32-bit PNG

Everything is drawn with Pillow so the assets can be regenerated from the
source icon at any time; nothing here is hand-edited in an image editor.

Note on alpha: `ImageDraw` on an RGBA image *replaces* pixels (alpha included)
instead of blending, so anything translucent is drawn on its own layer and
`alpha_composite`d — drawing a 10%-white pill straight onto the canvas gives a
solid white blob instead.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON_SRC = ROOT / "assets" / "icon" / "app_icon.png"
OUT = ROOT / "store" / "assets"

W, H = 1024, 500
SS = 2  # supersample factor: draw at 2x, downscale for smooth edges

INK = (255, 255, 255, 255)
MUTED = (210, 196, 255, 255)
BODY = (237, 232, 255, 255)
TOP = (22, 11, 48)
BOTTOM = (88, 43, 178)
ACCENT = (178, 142, 255, 255)


def L(n: float) -> int:
    return int(round(n * SS))


def font(size: float, bold: bool = True) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
        if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
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


def glow(size: tuple[int, int], centre: tuple[int, int], radius: int, colour: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    x, y = centre
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=colour)
    return layer.filter(ImageFilter.GaussianBlur(radius // 2))


def letter_spaced(draw: ImageDraw.ImageDraw, xy, text: str, fnt, fill, tracking: int) -> float:
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking
    return x - xy[0]


def pill(img: Image.Image, xy, text: str, fnt, tracking: int = 3) -> int:
    """Translucent rounded pill with tracked capitals. Returns its bottom y."""
    x, y = xy
    text_w = sum(fnt.getlength(c) for c in text) + tracking * (len(text) - 1)
    ascent, descent = fnt.getmetrics()
    pad_x, pad_y = L(18), L(11)
    height = ascent + descent + pad_y * 2
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(
        (x, y, x + text_w + pad_x * 2, y + height),
        radius=height // 2,
        fill=(255, 255, 255, 38),
        outline=(255, 255, 255, 70),
        width=max(1, L(1)),
    )
    letter_spaced(d, (x + pad_x, y + pad_y), text, fnt, INK, tracking)
    img.alpha_composite(layer)
    return int(y + height)


def cards() -> Image.Image:
    """Three floating flashcard shapes plus a recall arrow, transparent bg."""
    layer = Image.new("RGBA", (L(410), L(470)), (0, 0, 0, 0))
    cw, ch = L(160), L(210)
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle(
        (0, 0, cw - 1, ch - 1), radius=L(18), fill=(255, 255, 255, 24), outline=(255, 255, 255, 86), width=L(1.5)
    )
    d.rounded_rectangle((L(18), L(24), L(66), L(42)), radius=L(9), fill=(*ACCENT[:3], 170))
    for i, width in enumerate((104, 84, 118, 70)):
        top = L(64 + i * 32)
        d.rounded_rectangle((L(18), top, L(18 + width), top + L(10)), radius=L(5), fill=(255, 255, 255, 66))

    for x, y, angle in ((L(0), L(90), -13), (L(115), L(48), -3), (L(238), L(104), 9)):
        layer.alpha_composite(card.rotate(angle, resample=Image.BICUBIC, expand=True), (x, y))

    arrow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(arrow)
    cx, cy, r = L(150), L(150), L(62)
    d.arc((cx - r, cy - r, cx + r, cy + r), start=-75, end=195, fill=(255, 255, 255, 215), width=L(6))
    d.polygon(
        [(cx + L(50), cy - L(52)), (cx + L(88), cy - L(34)), (cx + L(44), cy - L(14))],
        fill=(255, 255, 255, 215),
    )
    layer.alpha_composite(arrow)
    return layer


COPY = {
    "en": {
        "pill": "FREE · NO SUBSCRIPTION",
        "title": "Random Recall",
        "tagline": ["Daily recall drills", "from your own notes."],
        "bullets": [
            "Unlimited questions, works offline",
            "Streaks, challenges & statistics",
            "English & Bahasa Indonesia",
        ],
    },
    "id": {
        "pill": "GRATIS · TANPA LANGGANAN",
        "title": "Random Recall",
        "tagline": ["Latihan recall harian", "dari catatanmu sendiri."],
        "bullets": [
            "Soal tanpa batas, bisa offline",
            "Streak, tantangan & statistik",
            "Bahasa Indonesia & Inggris",
        ],
    },
}


def feature_graphic(lang: str) -> Image.Image:
    w, h = W * SS, H * SS
    img = gradient(w, h)
    img.alpha_composite(glow((w, h), (L(900), L(120)), L(300), (150, 110, 255, 110)))
    img.alpha_composite(glow((w, h), (L(120), L(470)), L(220), (92, 58, 200, 100)))
    img.alpha_composite(cards(), (L(596), L(30)))

    d = ImageDraw.Draw(img)
    c = COPY[lang]
    left = L(72)

    pill_bottom = pill(img, (left, L(74)), c["pill"], font(16))
    d = ImageDraw.Draw(img)

    d.text((left, pill_bottom + L(20)), c["title"], font=font(62), fill=INK)

    f_tag = font(25, bold=False)
    y = L(268)
    for line in c["tagline"]:
        d.text((left, y), line, font=f_tag, fill=MUTED)
        y += L(38)

    f_bullet = font(19, bold=False)
    y = L(362)
    for item in c["bullets"]:
        d.ellipse((left, y + L(8), left + L(9), y + L(17)), fill=ACCENT)
        d.text((left + L(23), y), item, font=f_bullet, fill=BODY)
        y += L(38)

    return img.resize((W, H), Image.LANCZOS).convert("RGB")


def icon_512() -> Image.Image:
    src = Image.open(ICON_SRC).convert("RGBA")
    square = min(src.size)
    left = (src.width - square) // 2
    top = (src.height - square) // 2
    return src.crop((left, top, left + square, top + square)).resize((512, 512), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for lang in ("en", "id"):
        path = OUT / f"feature-graphic-{lang}.png"
        feature_graphic(lang).save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")
    icon = OUT / "play-store-icon-512.png"
    icon_512().save(icon, "PNG", optimize=True)
    print(f"wrote {icon.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
