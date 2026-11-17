#!/usr/bin/env python3
"""Generate NMW Connect icons from the civic grievance mark only.

The Play hi-res icon must not show a party emblem, flag, or portrait.
The grievance card and pin are the app's own mark.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"
# One column of the original icon red, and the original "NMW Connect" letters.
# The letters stay pixel-for-pixel. Only the emblem above them is redrawn.
GRADIENT_COLUMN = OUT / "icon_red_column.png"
WORDMARK_STRIP = OUT / "nmw_wordmark_strip.png"
WORDMARK_TOP = 714  # y on the 1024 master where the original wordmark begins

RED_HEADER = (220, 38, 38)
CREAM = (253, 249, 242)
LINE = (196, 70, 54)
GOLD = (251, 191, 36)
GOLD_DEEP = (180, 110, 12)
WHITE = (255, 255, 255)


def rr(draw: ImageDraw.ImageDraw, xy: tuple[float, float, float, float], radius: float, fill) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_pin(layer: Image.Image, cx: float, top: float, height: float) -> None:
    draw = ImageDraw.Draw(layer)
    head_r = height * 0.28
    head_cy = top + head_r
    point_y = top + height
    body = [
        (cx - head_r * 0.92, head_cy + head_r * 0.18),
        (cx, point_y),
        (cx + head_r * 0.92, head_cy + head_r * 0.18),
    ]
    draw.polygon(body, fill=GOLD_DEEP)
    draw.ellipse((cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r), fill=GOLD)
    hole_r = head_r * 0.38
    draw.ellipse(
        (cx - hole_r, head_cy - hole_r - head_r * 0.05, cx + hole_r, head_cy + hole_r - head_r * 0.05),
        fill=CREAM,
    )


def civic_mark(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s = size * 0.92
    card_w = s * 0.58
    card_h = s * 0.62
    cx = size / 2
    card_top = size / 2 - card_h * 0.28
    card_left = cx - card_w / 2
    card_right = cx + card_w / 2
    card_bot = card_top + card_h
    radius = card_w * 0.14
    header_h = card_h * 0.16

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shift = s * 0.02
    rr(
        ImageDraw.Draw(shadow),
        (card_left + shift, card_top + shift * 1.4, card_right + shift, card_bot + shift * 1.4),
        radius,
        (0, 0, 0, 80),
    )
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(radius=max(size * 0.02, 1))))

    card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rr(ImageDraw.Draw(card), (card_left, card_top, card_right, card_bot), radius, CREAM)
    header = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rr(ImageDraw.Draw(header), (card_left, card_top, card_right, card_bot), radius, RED_HEADER)
    eraser = Image.new("L", (size, size), 0)
    ImageDraw.Draw(eraser).rectangle((0, card_top + header_h, size, size), fill=255)
    r, g, b, a = header.split()
    header = Image.merge("RGBA", (r, g, b, ImageChops.subtract(a, eraser)))
    card = Image.alpha_composite(card, header)
    draw = ImageDraw.Draw(card)
    line_left = card_left + card_w * 0.16
    line_h = max(s * 0.04, 6)
    gap = card_h * 0.14
    first_y = card_top + header_h + card_h * 0.18
    for i, width in enumerate((0.68, 0.52, 0.60)):
        y = first_y + i * gap
        rr(draw, (line_left, y, line_left + card_w * width, y + line_h), line_h / 2, LINE + (230,))
    img = Image.alpha_composite(img, card)
    pin = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_pin(pin, cx, card_top - s * 0.22 * 0.7, s * 0.22)
    return Image.alpha_composite(img, pin)


def place_mark(canvas: Image.Image, mark: Image.Image, origin: tuple[int, int]) -> Image.Image:
    """Drop the civic mark onto the canvas with a soft shadow under the card."""
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = mark.getchannel("A")
    tint = Image.new("RGBA", mark.size, (0, 0, 0, 110))
    tint.putalpha(alpha)
    shift = max(int(canvas.size[0] * 0.012), 4)
    shadow.alpha_composite(tint, (origin[0] + shift, origin[1] + shift))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(radius=max(canvas.size[0] * 0.018, 1))))
    canvas.alpha_composite(mark, origin)
    return canvas


def original_background(size: int) -> Image.Image:
    column = Image.open(GRADIENT_COLUMN).convert("RGB")
    return column.resize((size, size), Image.Resampling.NEAREST).convert("RGBA")


def draw_icon(size: int) -> Image.Image:
    """Civic card on the original red, with the original NMW Connect wordmark locked below it."""
    if size != 1024:
        raise ValueError("master icon is 1024 so the wordmark strip stays the original size")
    img = original_background(size)
    mark_d = int(size * 0.70)
    mark = civic_mark(mark_d)
    top = int(size * 0.025)
    img = place_mark(img, mark, ((size - mark_d) // 2, top))
    strip = Image.open(WORDMARK_STRIP).convert("RGBA")
    if strip.size != (size, size - WORDMARK_TOP):
        raise ValueError(f"wordmark strip is {strip.size}, expected {(size, size - WORDMARK_TOP)}")
    img.alpha_composite(strip, (0, WORDMARK_TOP))
    return img


def save_rgb(img: Image.Image, path: Path) -> None:
    img.convert("RGB").save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def save_rgba(img: Image.Image, path: Path) -> None:
    img.save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def main() -> None:
    if not GRADIENT_COLUMN.is_file() or not WORDMARK_STRIP.is_file():
        raise SystemExit("missing original wordmark assets in assets/branding")
    listed = draw_icon(1024)
    play = listed.resize((512, 512), Image.Resampling.LANCZOS)

    save_rgb(listed, OUT / "app_icon.png")
    save_rgb(listed, OUT / "app_icon_ios.png")
    save_rgb(listed, OUT / "app_icon_android.png")
    save_rgb(listed, OUT / "nmw_connect_app_icon.png")
    save_rgba(listed, OUT / "app_icon_android_foreground.png")
    save_rgba(listed, OUT / "app_icon_foreground.png")
    save_rgba(listed, OUT / "splash_logo.png")
    save_rgb(play, OUT / "play_store_icon.png")


if __name__ == "__main__":
    main()
