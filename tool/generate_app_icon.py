#!/usr/bin/env python3
"""Generate NMW Connect launcher icons from the TVK badge plus the civic grievance mark."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"
BADGE = ROOT / "assets" / "branding" / "tvk-badge-hires.png"
FONT = ROOT / "tool" / "fonts" / "BebasNeue-Regular.ttf"

RED_TOP = (200, 32, 32)
RED_BOT = (122, 18, 18)
RED_HEADER = (220, 38, 38)
CREAM = (253, 249, 242)
LINE = (196, 70, 54)
GOLD = (251, 191, 36)
GOLD_DEEP = (180, 110, 12)
WHITE = (255, 255, 255)


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


def display_font(px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), px)


def circularize(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    size = min(im.size)
    im = im.resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((1, 1, size - 2, size - 2), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.putalpha(mask)
    return out


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


def draw_icon(size: int, scale: float, background: Image.Image | None, wordmark: bool) -> Image.Image:
    img = background.convert("RGBA") if background is not None else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = size / 2
    badge_d = int(size * scale * (0.58 if wordmark else 0.70))
    badge_y = int(size * (0.12 if wordmark else 0.15))
    if not wordmark:
        badge_y = int((size - badge_d) / 2 - size * 0.02)

    badge = circularize(Image.open(BADGE)).resize((badge_d, badge_d), Image.Resampling.LANCZOS)
    # Gold ring
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    pad = max(int(badge_d * 0.035), 8)
    box = (cx - badge_d / 2 - pad, badge_y - pad, cx + badge_d / 2 + pad, badge_y + badge_d + pad)
    rd.ellipse(box, outline=GOLD + (255,), width=max(int(size * 0.012), 6))
    rd.ellipse(
        (box[0] + pad * 0.35, box[1] + pad * 0.35, box[2] - pad * 0.35, box[3] - pad * 0.35),
        outline=(180, 20, 20, 255),
        width=max(int(size * 0.006), 3),
    )
    img = Image.alpha_composite(img, ring)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        (cx - badge_d / 2 + 12, badge_y + 18, cx + badge_d / 2 + 12, badge_y + badge_d + 18),
        fill=(0, 0, 0, 70),
    )
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(radius=max(size * 0.02, 1))))

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(badge, (int(cx - badge_d / 2), badge_y), badge)
    img = Image.alpha_composite(img, layer)

    overlay_d = int(badge_d * 0.38)
    civic = civic_mark(overlay_d)
    ox = int(cx + badge_d * 0.18)
    oy = int(badge_y + badge_d * 0.62)
    img.alpha_composite(civic, (ox, oy))

    if wordmark:
        draw = ImageDraw.Draw(img)
        nmw = display_font(int(size * 0.145))
        conn = display_font(int(size * 0.072))
        ty = badge_y + badge_d + int(size * 0.028)
        draw.text((cx, ty), "NMW", font=nmw, fill=CREAM, anchor="mt")
        draw.text((cx, ty + int(size * 0.13)), "CONNECT", font=conn, fill=GOLD, anchor="mt")
    return img


def save_rgb(img: Image.Image, path: Path) -> None:
    img.convert("RGB").save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def save_rgba(img: Image.Image, path: Path) -> None:
    img.save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {img.size}")


def main() -> None:
    src = 2048
    bg = vertical_gradient(src, RED_TOP, RED_BOT)
    ios = draw_icon(src, 0.92, bg, wordmark=True).resize((1024, 1024), Image.Resampling.LANCZOS)
    android = draw_icon(src, 0.78, bg, wordmark=False).resize((1024, 1024), Image.Resampling.LANCZOS)
    foreground = draw_icon(src, 0.78, None, wordmark=False).resize((1024, 1024), Image.Resampling.LANCZOS)

    save_rgb(ios, OUT / "app_icon.png")
    save_rgb(ios, OUT / "app_icon_ios.png")
    save_rgb(android, OUT / "app_icon_android.png")
    save_rgba(foreground, OUT / "app_icon_android_foreground.png")
    save_rgba(foreground, OUT / "app_icon_foreground.png")
    save_rgba(foreground, OUT / "splash_logo.png")
    save_rgb(ios.resize((512, 512), Image.Resampling.LANCZOS), OUT / "play_store_icon.png")


if __name__ == "__main__":
    main()
