#!/usr/bin/env python3
"""Generate Play-safe Citizen Desk launcher icons (no face, name, emblem, or party mark)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"

RED_TOP = (200, 32, 32)
RED_BOT = (122, 18, 18)
RED_HEADER = (220, 38, 38)
CREAM = (253, 249, 242)
LINE = (196, 70, 54)
GOLD = (251, 191, 36)
GOLD_DEEP = (180, 110, 12)


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def vertical_gradient(size: int, top: tuple[int, int, int], bot: tuple[int, int, int]) -> Image.Image:
    strip = Image.new("RGB", (1, size))
    px = strip.load()
    last = size - 1
    for y in range(size):
        px[0, y] = lerp(top, bot, y / last)
    return strip.resize((size, size), Image.Resampling.BILINEAR)


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


def draw_mark(size: int, scale: float, background: Image.Image | None) -> Image.Image:
    img = background.convert("RGBA") if background is not None else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s = size * scale
    card_w = s * 0.46
    card_h = s * 0.54
    cx = size / 2
    card_top = size / 2 - card_h * 0.38
    card_left = cx - card_w / 2
    card_right = cx + card_w / 2
    card_bot = card_top + card_h
    radius = card_w * 0.12
    header_h = card_h * 0.16

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shift = s * 0.018
    rr(
        ImageDraw.Draw(shadow),
        (card_left + shift, card_top + shift * 1.6, card_right + shift, card_bot + shift * 1.6),
        radius,
        (0, 0, 0, 72),
    )
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(radius=max(size * 0.018, 1))))

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
    line_h = max(s * 0.028, 8)
    gap = card_h * 0.12
    first_y = card_top + header_h + card_h * 0.16
    for i, width in enumerate((0.68, 0.54, 0.62)):
        y = first_y + i * gap
        rr(draw, (line_left, y, line_left + card_w * width, y + line_h), line_h / 2, LINE + (230,))

    img = Image.alpha_composite(img, card)

    pin = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_pin(pin, cx, card_top - s * 0.28 * 0.62, s * 0.28)
    return Image.alpha_composite(img, pin)


def save_rgb(img: Image.Image, path: Path) -> None:
    img.convert("RGB").save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def save_rgba(img: Image.Image, path: Path) -> None:
    img.save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def main() -> None:
    src = 2048
    bg = vertical_gradient(src, RED_TOP, RED_BOT)
    ios = draw_mark(src, 0.92, bg).resize((1024, 1024), Image.Resampling.LANCZOS)
    android = draw_mark(src, 0.78, bg).resize((1024, 1024), Image.Resampling.LANCZOS)
    foreground = draw_mark(src, 0.78, None).resize((1024, 1024), Image.Resampling.LANCZOS)

    save_rgb(ios, OUT / "app_icon.png")
    save_rgb(ios, OUT / "app_icon_ios.png")
    save_rgb(android, OUT / "app_icon_android.png")
    save_rgba(foreground, OUT / "app_icon_android_foreground.png")
    save_rgba(foreground, OUT / "app_icon_foreground.png")
    save_rgba(foreground, OUT / "splash_logo.png")


if __name__ == "__main__":
    main()
