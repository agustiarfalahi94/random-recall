#!/usr/bin/env python3
"""Frame the raw phone captures in `store/raw/` for the Play Store listing.

    python3 tools/make_store_screenshots.py           # both locales
    python3 tools/make_store_screenshots.py id        # only Bahasa Indonesia

Raw captures are wider than Play allows: the Xiaomi 12T shoots 1220x2712 (20:9)
and the Xiaomi 15 shoots 1200x2670, both over Play's 2:1 limit on the long side.
Each one is cropped to app content (status bar and the ad banner strip removed),
then centred on a 1080x1920 marketing canvas with a caption, which satisfies the
ratio rule as well as looking deliberate.

`store/raw/` and `store/raw/id/` hold the untouched device captures so the
framing can be redone without touching the phones again. Captions and crops are
per locale because the devices differ: the 15 has a taller status bar (its
courier is now the one in `store/raw/id/`) and its captures were taken with the
ad banner collapsed, so almost nothing needs cutting at the bottom.
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

TOP = (20, 10, 44)
BOTTOM = (74, 36, 156)
INK = (255, 255, 255, 255)
MUTED = (208, 194, 255, 255)

# Per-locale capture set. `overrides` exist because the Settings list sits higher
# than the tab bar, so on the 12T its ad strip had to be cut deeper than the
# default, and the Questions list needed a shallower one under its tab bar.
LOCALES = {
    "en": {
        "raw": RAW,
        "out": OUT,
        "crop": (96, 200),
        "overrides": {"settings": (96, 340), "questions": (96, 110)},
        "captions": [
            ("home", "Practice anytime", "Your own questions, one recall at a time"),
            ("question", "Your questions, your words", "No pre-made decks — it is your material"),
            ("answer", "Reveal, check, repeat", "Self-testing beats re-reading"),
            ("questions", "Organise by topic", "Unlimited questions and categories"),
            ("settings", "Reminders that fit your day", "Pick the days, the time and the frequency"),
        ],
    },
    "id": {
        "raw": RAW / "id",
        "out": OUT / "id",
        "crop": (140, 60),
        # No overrides: on the 15 every screen was captured with the ad banner
        # collapsed, so one crop fits all. Trimming the question screen's empty
        # lower half was tried and looked wrong — the card floated in the canvas.
        "overrides": {},
        "captions": [
            ("home", "Berlatih kapan saja", "Pertanyaanmu sendiri, satu ingatan sekaligus"),
            ("question", "Pertanyaanmu, bahasamu sendiri", "Tanpa paket siap pakai — materimu sendiri"),
            ("answer", "Buka, cek, ulangi", "Menguji diri lebih ampuh daripada membaca ulang"),
            ("questions", "Rapikan per topik", "Pertanyaan dan kategori tanpa batas"),
            ("settings", "Pengingat sesuai harimu", "Pilih hari, jam, dan frekuensinya"),
        ],
    },
}


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


def frame(locale: dict, name: str, title: str, subtitle: str) -> None:
    raw = Image.open(locale["raw"] / f"{name}.png").convert("RGB")
    top_crop, bottom_crop = locale["overrides"].get(name, locale["crop"])
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

    locale["out"].mkdir(parents=True, exist_ok=True)
    path = locale["out"] / f"{name}.png"
    canvas.convert("RGB").resize((W, H), Image.LANCZOS).save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def main() -> None:
    import sys

    wanted = sys.argv[1:] or list(LOCALES)
    for code in wanted:
        if code not in LOCALES:
            raise SystemExit(f"unknown locale {code!r}; pick from {', '.join(LOCALES)}")
        locale = LOCALES[code]
        for name, title, subtitle in locale["captions"]:
            if not (locale["raw"] / f"{name}.png").exists():
                print(f"skip {code}/{name}: no capture in {locale['raw'].relative_to(ROOT)}/")
                continue
            frame(locale, name, title, subtitle)


if __name__ == "__main__":
    main()
