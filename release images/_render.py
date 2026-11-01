#!/usr/bin/env python3
"""Store preview images for the Office of Dr. N. Marie Wilson app."""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.abspath(__file__))
PORTRAIT = "/Users/entrans/project/tvk_proj/n-marie-wilson-mobile/assets/images/marie-wilson-portrait.jpg"
OUTFIT = "/tmp/mw-fonts/outfit-test.ttf"
TAMIL = "/tmp/mw-fonts/NotoSansTamil.ttf"

INK = (32, 14, 8)
RED = (176, 16, 24)
RED_DEEP = (132, 8, 16)
BRAND = (220, 38, 38)
CREAM = (253, 244, 237)
WHITE = (255, 255, 255)
MUTED = (90, 78, 74)
LINE = (228, 228, 231)
FIELD = (250, 250, 250)
GOLD = (212, 160, 48)
DARK = (54, 7, 5)
DARK_2 = (99, 30, 5)
PINK = (255, 236, 236)
NAV_MUTED = (113, 113, 122)

LW, LH = 390, 844
SCALE = 3

_FONTS: dict[tuple, ImageFont.FreeTypeFont] = {}


def font(kind: str, logical: float, weight: int) -> ImageFont.FreeTypeFont:
    size = max(8, int(round(logical * SCALE)))
    key = (kind, size, weight)
    if key not in _FONTS:
        face = ImageFont.truetype(TAMIL if kind == "ta" else OUTFIT, size)
        if kind == "ta":
            face.set_variation_by_axes([weight, 100])
        else:
            face.set_variation_by_axes([weight])
        _FONTS[key] = face
    return _FONTS[key]


def mfont(path: str, px: int, weight: int) -> ImageFont.FreeTypeFont:
    key = ("m", path, px, weight)
    if key not in _FONTS:
        face = ImageFont.truetype(path, px)
        if path == TAMIL:
            face.set_variation_by_axes([weight, 100])
        else:
            face.set_variation_by_axes([weight])
        _FONTS[key] = face
    return _FONTS[key]


class UI:
    def __init__(self):
        self.img = Image.new("RGB", (LW * SCALE, LH * SCALE), WHITE)
        self.d = ImageDraw.Draw(self.img)

    def p(self, n: float) -> int:
        return int(round(n * SCALE))

    def box(self, b):
        return [self.p(v) for v in b]

    def rrect(self, b, r, fill=None, outline=None, width=1.4):
        xy = self.box(b)
        rad = self.p(r)
        kw = {}
        if fill is not None:
            kw["fill"] = fill
        if outline is not None:
            kw["outline"] = outline
            kw["width"] = max(1, self.p(width))
        self.d.rounded_rectangle(xy, radius=rad, **kw)

    def text(self, x, y, s, kind, size, weight, fill, anchor="lt"):
        self.d.text((self.p(x), self.p(y)), s, font=font(kind, size, weight), fill=fill, anchor=anchor)

    def width(self, s, kind, size, weight) -> float:
        return font(kind, size, weight).getlength(s) / SCALE

    def wrap(self, s, kind, size, weight, max_w) -> list[str]:
        words = s.split()
        lines, cur = [], ""
        for word in words:
            trial = word if not cur else f"{cur} {word}"
            if self.width(trial, kind, size, weight) <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
        return lines or [""]

    def paragraph(self, x, y, s, kind, size, weight, fill, max_w, leading=1.38, align="left"):
        lines = self.wrap(s, kind, size, weight, max_w)
        gap = size * leading
        for i, line in enumerate(lines):
            if align == "center":
                self.text(x + max_w / 2, y + i * gap, line, kind, size, weight, fill, anchor="mt")
            else:
                self.text(x, y + i * gap, line, kind, size, weight, fill)
        return y + len(lines) * gap

    def line(self, a, b, fill, width=1.6):
        self.d.line([self.box((*a, *b))[0:2], self.box((*a, *b))[2:4]], fill=fill, width=max(1, self.p(width)))

    def icon(self, name, cx, cy, size, color):
        d = self.d
        s = size
        x0, y0 = cx - s / 2, cy - s / 2
        w = max(1, self.p(1.7))

        def X(v):
            return self.p(v)

        def poly(pts, outline=True, fill=None):
            p = [(X(px), X(py)) for px, py in pts]
            if fill:
                d.polygon(p, fill=fill)
            if outline:
                d.line(p + [p[0]], fill=color, width=w, joint="curve")

        if name == "home":
            poly([(cx, y0 + 1), (x0 + 1, cy - 1), (x0 + 3.5, cy - 1), (x0 + 3.5, y0 + s - 1), (x0 + s - 3.5, y0 + s - 1), (x0 + s - 3.5, cy - 1), (x0 + s - 1, cy - 1), (cx, y0 + 1)], outline=False, fill=None)
            d.line([(X(cx), X(y0 + 1.2)), (X(x0 + 1.2), X(cy))], fill=color, width=w)
            d.line([(X(cx), X(y0 + 1.2)), (X(x0 + s - 1.2), X(cy))], fill=color, width=w)
            d.line([(X(x0 + 4), X(cy - 0.4)), (X(x0 + 4), X(y0 + s - 1.2)), (X(x0 + s - 4), X(y0 + s - 1.2)), (X(x0 + s - 4), X(cy - 0.4))], fill=color, width=w, joint="curve")
        elif name == "file":
            d.rounded_rectangle([X(x0 + 3), X(y0 + 1), X(x0 + s - 3), X(y0 + s - 1)], radius=X(2), outline=color, width=w)
            d.line([(X(x0 + 6), X(cy - 1)), (X(x0 + s - 6), X(cy - 1))], fill=color, width=w)
            d.line([(X(x0 + 6), X(cy + 3)), (X(x0 + s - 8), X(cy + 3))], fill=color, width=w)
        elif name == "search":
            r = s * 0.32
            d.ellipse([X(cx - r - 1), X(cy - r - 1.5), X(cx + r - 1), X(cy + r - 1.5)], outline=color, width=w)
            d.line([(X(cx + r - 2), X(cy + r - 2.5)), (X(x0 + s - 2), X(y0 + s - 2))], fill=color, width=w)
        elif name == "news":
            d.rounded_rectangle([X(x0 + 2), X(y0 + 2), X(x0 + s - 2), X(y0 + s - 2)], radius=X(2), outline=color, width=w)
            d.line([(X(x0 + 5), X(y0 + 7)), (X(x0 + s - 5), X(y0 + 7))], fill=color, width=w)
            d.line([(X(x0 + 5), X(y0 + 11)), (X(x0 + s - 7), X(y0 + 11))], fill=color, width=w)
        elif name == "menu":
            for i, dy in enumerate((-5, 0, 5)):
                d.line([(X(x0 + 2), X(cy + dy)), (X(x0 + s - 2), X(cy + dy))], fill=color, width=w)
        elif name == "back":
            d.line([(X(cx + 3), X(y0 + 3)), (X(x0 + 3), X(cy)), (X(cx + 3), X(y0 + s - 3))], fill=color, width=w, joint="curve")
        elif name == "chevron":
            d.line([(X(cx - 2), X(y0 + 4)), (X(cx + 3), X(cy)), (X(cx - 2), X(y0 + s - 4))], fill=color, width=w, joint="curve")
        elif name == "down":
            d.line([(X(x0 + 2), X(y0 + 5)), (X(cx), X(y0 + s - 4)), (X(x0 + s - 2), X(y0 + 5))], fill=color, width=w, joint="curve")
        elif name == "pin":
            d.ellipse([X(cx - 5), X(y0 + 1), X(cx + 5), X(y0 + 11)], outline=color, width=w)
            d.line([(X(cx), X(y0 + 11)), (X(cx), X(y0 + s - 1))], fill=color, width=w)
            d.ellipse([X(cx - 1.4), X(y0 + 4.2), X(cx + 1.4), X(y0 + 7)], fill=color)
        elif name == "chat":
            d.rounded_rectangle([X(x0 + 1), X(y0 + 2), X(x0 + s - 1), X(y0 + s - 6)], radius=X(4), outline=color, width=w)
            d.polygon([(X(x0 + 5), X(y0 + s - 6)), (X(x0 + 5), X(y0 + s - 1)), (X(x0 + 11), X(y0 + s - 6))], fill=color)
        elif name == "person":
            d.ellipse([X(cx - 4), X(y0 + 1), X(cx + 4), X(y0 + 9)], outline=color, width=w)
            d.arc([X(x0 + 2), X(y0 + 11), X(x0 + s - 2), X(y0 + s + 6)], 200, 340, fill=color, width=w)
        elif name == "bank":
            d.polygon([(X(cx), X(y0 + 1)), (X(x0 + 1), X(y0 + 7)), (X(x0 + s - 1), X(y0 + 7))], outline=color)
            d.line([(X(x0 + 1), X(y0 + 7)), (X(x0 + s - 1), X(y0 + 7))], fill=color, width=w)
            for i in range(3):
                xx = x0 + 4 + i * 6
                d.line([(X(xx), X(y0 + 8)), (X(xx), X(y0 + s - 4))], fill=color, width=w)
            d.line([(X(x0 + 1), X(y0 + s - 3)), (X(x0 + s - 1), X(y0 + s - 3))], fill=color, width=w)
        elif name == "mail":
            d.rounded_rectangle([X(x0 + 1), X(y0 + 4), X(x0 + s - 1), X(y0 + s - 3)], radius=X(2), outline=color, width=w)
            d.line([(X(x0 + 2), X(y0 + 5)), (X(cx), X(cy + 1)), (X(x0 + s - 2), X(y0 + 5))], fill=color, width=w, joint="curve")
        elif name == "badge":
            d.rounded_rectangle([X(x0 + 3), X(y0 + 1), X(x0 + s - 3), X(y0 + s - 5)], radius=X(2), outline=color, width=w)
            d.polygon([(X(x0 + 6), X(y0 + s - 5)), (X(cx), X(y0 + s - 1)), (X(x0 + s - 6), X(y0 + s - 5))], outline=color)
        elif name == "lock":
            d.rounded_rectangle([X(x0 + 3), X(cy - 1), X(x0 + s - 3), X(y0 + s - 1)], radius=X(2), outline=color, width=w)
            d.arc([X(cx - 4), X(y0 + 1), X(cx + 4), X(cy + 1)], 180, 0, fill=color, width=w)
        elif name == "check":
            d.line([(X(x0 + 2), X(cy)), (X(cx - 1), X(y0 + s - 3)), (X(x0 + s - 2), X(y0 + 3))], fill=color, width=w, joint="curve")
        elif name == "hash":
            self.text(cx, cy, "#", "en", size * 0.85, 700, color, anchor="mm")
        elif name == "sparkle":
            d.line([(X(cx), X(y0 + 1)), (X(cx), X(y0 + s - 1))], fill=color, width=w)
            d.line([(X(x0 + 1), X(cy)), (X(x0 + s - 1), X(cy))], fill=color, width=w)
            d.line([(X(x0 + 3), X(y0 + 3)), (X(x0 + s - 3), X(y0 + s - 3))], fill=color, width=max(1, w - 1))
            d.line([(X(x0 + s - 3), X(y0 + 3)), (X(x0 + 3), X(y0 + s - 3))], fill=color, width=max(1, w - 1))
        elif name == "target":
            d.ellipse([X(x0 + 2), X(y0 + 2), X(x0 + s - 2), X(y0 + s - 2)], outline=color, width=w)
            d.ellipse([X(cx - 2.2), X(cy - 2.2), X(cx + 2.2), X(cy + 2.2)], fill=color)
        elif name == "map":
            d.rounded_rectangle([X(x0 + 1), X(y0 + 3), X(x0 + s - 1), X(y0 + s - 2)], radius=X(2), outline=color, width=w)
            d.line([(X(x0 + 1), X(cy)), (X(x0 + s - 1), X(cy))], fill=color, width=w)
            d.line([(X(cx), X(y0 + 3)), (X(cx), X(y0 + s - 2))], fill=color, width=w)
        elif name == "phone":
            d.rounded_rectangle([X(x0 + 5), X(y0 + 1), X(x0 + s - 5), X(y0 + s - 1)], radius=X(2), outline=color, width=w)
            d.line([(X(cx - 2), X(y0 + s - 3.5)), (X(cx + 2), X(y0 + s - 3.5))], fill=color, width=w)
        elif name == "play":
            d.polygon([(X(x0 + 4), X(y0 + 2)), (X(x0 + 4), X(y0 + s - 2)), (X(x0 + s - 2), X(cy))], fill=color)


def status_bar(ui: UI, platform: str):
    ui.text(22, 18, "11:28", "en", 15, 650, INK)
    # signal
    for i in range(4):
        h = 4 + i * 2.3
        ui.rrect((300 + i * 5.2, 30 - h, 303.2 + i * 5.2, 30), 0.6, fill=INK)
    # wifi dot + arc
    ui.d.ellipse(ui.box((328, 26, 332, 30)), fill=INK)
    ui.d.arc(ui.box((323, 20, 337, 34)), 220, 320, fill=INK, width=max(1, ui.p(1.4)))
    ui.d.arc(ui.box((319, 15, 341, 36)), 220, 320, fill=INK, width=max(1, ui.p(1.4)))
    # battery
    ui.rrect((348, 16, 372, 30), 3, outline=INK, width=1.3)
    ui.rrect((350.4, 18.2, 366, 27.8), 1.5, fill=INK)
    ui.rrect((372, 20.5, 374.2, 25.5), 0.6, fill=INK)
    ui.text(358, 23, "82", "en", 8, 700, WHITE, anchor="mm")
    if platform == "ios":
        ui.rrect((136, 11, 254, 36), 13, fill=(12, 12, 14))
    else:
        ui.d.ellipse(ui.box((186, 14, 204, 32)), fill=(12, 12, 14))
        ui.d.ellipse(ui.box((191, 19, 199, 27)), fill=(28, 36, 48))


def app_bar(ui: UI, title: str, title_kind: str, lang: str, lang_kind: str, back: bool):
    if back:
        ui.icon("back", 26, 78, 18, INK)
        ui.text(44, 78, title, title_kind, 17, 650, INK, anchor="lm")
    else:
        ui.text(16, 78, title, title_kind, 17, 650, INK, anchor="lm")
    lang_w = ui.width(lang, lang_kind, 14, 700)
    ui.text(374 - lang_w, 78, lang, lang_kind, 14, 700, BRAND, anchor="lm")
    ui.line((0, 100), (390, 100), (244, 244, 245), 1)


def bottom_nav(ui: UI, labels, kinds, active: int):
    ui.line((0, 758), (390, 758), (238, 238, 240), 1)
    ui.img.paste(Image.new("RGB", (ui.p(390), ui.p(86)), (255, 250, 248)), (0, ui.p(759)))
    for i, (label, kind) in enumerate(zip(labels, kinds)):
        cx = 39 + i * 78
        col = BRAND if i == active else NAV_MUTED
        if i == active:
            ui.rrect((cx - 30, 766, cx + 30, 832), 18, fill=PINK)
        icons = ["home", "file", "search", "news", "menu"]
        ui.icon(icons[i], cx, 786, 20, col)
        size = 10
        while size > 7 and ui.width(label, kind, size, 650 if i == active else 500) > 68:
            size -= 0.5
        ui.text(cx, 812, label, kind, size, 650 if i == active else 500, col, anchor="mm")
    ui.rrect((158, 834, 232, 839), 3, fill=(180, 180, 184))


def chrome(ui, title, title_kind, lang, lang_kind, back, labels, kinds, active, platform):
    status_bar(ui, platform)
    app_bar(ui, title, title_kind, lang, lang_kind, back)
    bottom_nav(ui, labels, kinds, active)


EN_NAV = (["Home", "File", "Track", "News", "More"], ["en"] * 5)
TA_NAV = (["முகப்பு", "புகார்", "நிலை", "செய்திகள்", "மேலும்"], ["ta"] * 5)


def screen_about(platform: str) -> Image.Image:
    ui = UI()
    labels, kinds = TA_NAV
    chrome(ui, "பற்றி", "ta", "EN", "en", True, labels, kinds, 4, platform)
    y = 114
    ui.text(16, y, "பற்றி", "ta", 12, 700, BRAND)
    y += 22
    y = ui.paragraph(16, y, "டாக்டர் நெ. மரிய வில்சன் பற்றி", "ta", 22, 750, INK, 358, leading=1.28)
    y += 8
    y = ui.paragraph(
        16,
        y,
        "பொதுச் சேவகர், அமைப்பாளர், மற்றும் ராதாகிருஷ்ணன் நகர் தமிழ்நாடு சட்டப்பேரவை உறுப்பினர்.",
        "ta",
        13,
        450,
        MUTED,
        358,
        leading=1.45,
    )
    y += 12
    photo_w = 358
    photo_h = min(300, 748 - y - 96)
    photo = Image.open(PORTRAIT).convert("RGB")
    fitted = ImageOps.fit(photo, (ui.p(photo_w), ui.p(photo_h)), Image.Resampling.LANCZOS)
    mask = Image.new("L", fitted.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, fitted.width - 1, fitted.height - 1), radius=ui.p(16), fill=255)
    ui.img.paste(fitted, (ui.p(16), ui.p(y)), mask)
    y += photo_h + 12
    ui.paragraph(
        16,
        y,
        "சுமார் 1979-ல் பிறந்த நெ. மரிய வில்சன், தமிழ்நாட்டைச் சேர்ந்த இந்திய அரசியல்வாதி. தமிழக வெற்றிக் கழகம் (TVK) சார்பில் 2026-ல் தேர்ந்தெடுக்கப்பட்டு, ராதாகிருஷ்ணன் நகர் தொகுதியைப் பிரதிநிதித்துவப்படுத்துகிறார்.",
        "ta",
        12.5,
        450,
        (55, 55, 60),
        358,
        leading=1.45,
    )
    return ui.img


def field(ui: UI, y, label, value, dropdown=False):
    ui.rrect((16, y, 374, y + 48), 10, fill=FIELD, outline=LINE, width=1.2)
    ui.text(28, y + 8, label, "en", 10, 500, MUTED)
    ui.text(28, y + 26, value, "en", 13, 500, (161, 161, 170) if value.startswith("Select") or value in ("Auto-detect",) else INK)
    if dropdown:
        ui.icon("down", 356, y + 26, 12, MUTED)
    return y + 58


def screen_file(platform: str) -> Image.Image:
    ui = UI()
    labels, kinds = EN_NAV
    chrome(ui, "File a grievance", "en", "தமிழ்", "ta", False, labels, kinds, 1, platform)
    # assistant button sits left of the language toggle
    lang_w = ui.width("தமிழ்", "ta", 14, 700)
    ax = 374 - lang_w - 8
    ui.text(ax, 78, "Assistant", "en", 13, 650, BRAND, anchor="rm")
    ui.icon("sparkle", ax - ui.width("Assistant", "en", 13, 650) - 12, 78, 12, BRAND)
    y = 114
    y = ui.paragraph(
        16,
        y,
        "Speak or type in Tamil, English or both — we fill the form for you.",
        "en",
        12.5,
        450,
        MUTED,
        358,
        leading=1.35,
    )
    y += 12
    y = field(ui, y, "Name", "Your full name")
    y = field(ui, y, "Mobile *", "98XXXXXXXX")
    y = field(ui, y, "Constituency *", "Select your constituency", True)
    y = field(ui, y, "Ward number (optional)", "Select constituency first", True)
    y = field(ui, y, "Area / Street / Ward *", "Street, area, or landmark")
    bw = 174
    ui.rrect((16, y, 16 + bw, y + 42), 10, outline=BRAND, width=1.3)
    ui.icon("target", 36, y + 21, 16, BRAND)
    ui.text(50, y + 21, "Use current location", "en", 11, 600, BRAND, anchor="lm")
    ui.rrect((200, y, 374, y + 42), 10, outline=BRAND, width=1.3)
    ui.icon("map", 220, y + 21, 16, BRAND)
    ui.text(234, y + 21, "Choose on map", "en", 11, 600, BRAND, anchor="lm")
    y += 52
    y = field(ui, y, "Category", "Auto-detect", True)
    field(ui, y, "Urgency", "Normal", True)
    return ui.img


def screen_track(platform: str) -> Image.Image:
    ui = UI()
    labels, kinds = EN_NAV
    chrome(ui, "Track Grievance", "en", "தமிழ்", "ta", False, labels, kinds, 2, platform)
    # hero gradient
    card = Image.new("RGB", (ui.p(358), ui.p(248)), DARK)
    px = card.load()
    for yy in range(card.height):
        t = yy / max(1, card.height - 1)
        col = tuple(int(DARK[i] * (1 - t) + DARK_2[i] * t) for i in range(3))
        for xx in range(card.width):
            px[xx, yy] = col
    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius=ui.p(16), fill=255)
    ui.img.paste(card, (ui.p(16), ui.p(114)), mask)
    ui.text(30, 130, "PUBLIC GRIEVANCE PLATFORM  ·  R.K. NAGAR", "en", 9, 700, GOLD)
    ui.paragraph(30, 150, "Every concern, followed through to resolution.", "en", 18, 700, WHITE, 328, leading=1.2)
    ui.paragraph(
        30,
        206,
        "Enter the reference ID you received when filing (e.g. MW-1A2B3C4D) to see its current status.",
        "en",
        11.5,
        450,
        (255, 255, 255),
        328,
        leading=1.35,
    )
    ui.rrect((30, 268, 360, 306), 10, fill=WHITE)
    ui.text(44, 287, "MW-XXXXXXXX", "en", 14, 500, (161, 161, 170), anchor="lm")
    ui.rrect((30, 314, 360, 350), 10, fill=BRAND)
    ui.text(195, 332, "Track grievance", "en", 14, 700, WHITE, anchor="mm")

    ui.rrect((16, 376, 374, 424), 12, fill=(255, 241, 242), outline=(254, 205, 211), width=1.2)
    ui.icon("search", 36, 400, 16, BRAND)
    ui.paragraph(52, 386, "No grievance found with that reference ID.", "en", 12, 550, (159, 18, 57), 306, leading=1.3)

    rows = [
        ("lock", "Privacy first", "Names and phone numbers are never shown publicly."),
        ("check", "Reviewed by the office", "Every grievance is read and routed by the Minister's team."),
        ("hash", "Follow up with your ID", "No sign-in needed — just keep your reference ID."),
    ]
    y = 438
    for icon, title, body in rows:
        ui.rrect((16, y, 374, y + 96), 14, fill=WHITE, outline=LINE, width=1.1)
        ui.icon(icon, 40, y + 28, 18, BRAND)
        ui.text(60, y + 16, title, "en", 13.5, 650, INK)
        ui.paragraph(60, y + 38, body, "en", 12, 450, MUTED, 296, leading=1.3)
        y += 106
    return ui.img


def tile(ui: UI, y, icon, label, highlight=False):
    if highlight:
        ui.rrect((10, y - 4, 380, y + 48), 12, fill=PINK)
    bg = (255, 228, 228) if highlight else (244, 244, 245)
    ui.rrect((16, y, 46, y + 30), 8, fill=bg)
    ui.icon(icon, 31, y + 15, 16, BRAND if highlight else INK)
    ui.text(58, y + 15, label, "en", 15, 650 if highlight else 500, INK, anchor="lm")
    ui.icon("chevron", 360, y + 15, 14, (161, 161, 170))
    return y + 52


def screen_more(platform: str) -> Image.Image:
    ui = UI()
    labels, kinds = EN_NAV
    chrome(ui, "More", "en", "தமிழ்", "ta", False, labels, kinds, 4, platform)
    y = 118
    y = tile(ui, y, "phone", "Emergency & monsoon helplines")
    y = tile(ui, y, "chat", "Wilson AI Assistant", True)
    ui.rrect((0, y, 390, y + 8), 0, fill=(245, 245, 245))
    y += 18
    for icon, label in (
        ("person", "About"),
        ("bank", "Ministry"),
        ("pin", "Constituency"),
        ("news", "Initiatives"),
        ("mail", "Contact"),
    ):
        y = tile(ui, y, icon, label)
    ui.rrect((0, y, 390, y + 8), 0, fill=(245, 245, 245))
    y += 18
    tile(ui, y, "badge", "Staff login")
    ui.text(16, 730, "© 2026 Office of Dr. N. Marie Wilson. All rights reserved.", "en", 10, 450, MUTED)
    return ui.img


def screen_news(platform: str) -> Image.Image:
    ui = UI()
    labels, kinds = EN_NAV
    chrome(ui, "News Feed", "en", "தமிழ்", "ta", False, labels, kinds, 3, platform)
    ui.text(16, 118, "NEWS FEED", "en", 11, 700, BRAND)
    ui.text(16, 140, "The Minister's activities", "en", 22, 750, INK)
    ui.text(16, 176, "24 October 2026", "en", 13, 500, MUTED)
    # video
    ui.rrect((16, 204, 374, 404), 16, fill=(17, 17, 17))
    ui.d.ellipse(ui.box((171, 280, 219, 328)), fill=(255, 255, 255))
    ui.icon("play", 198, 304, 22, BRAND)
    ui.paragraph(
        16,
        420,
        "ராதாகிருஷ்ணன் நகர் இளைஞர்களுக்கான திறன் மேம்பாட்டு மையத்தில் AI, கோடிங் மற்றும் மென்திறன் பயிற்சி.",
        "ta",
        13.5,
        500,
        (39, 39, 42),
        358,
        leading=1.5,
    )
    ui.paragraph(
        16,
        500,
        "Free enrollment for youth of Radhakrishnan Nagar. Courses in AI, coding, and soft skills — run by the constituency office.",
        "en",
        13,
        450,
        MUTED,
        358,
        leading=1.4,
    )
    ui.rrect((16, 590, 374, 742), 16, fill=WHITE, outline=LINE, width=1.1)
    ui.text(30, 608, "CONSTITUENCY", "en", 11, 700, BRAND)
    ui.paragraph(30, 630, "Serving Radhakrishnan Nagar with integrity and vision.", "en", 16, 700, INK, 328, leading=1.25)
    ui.paragraph(
        30,
        678,
        "Elected in 2026 as the voice of R.K. Nagar, Chennai. Infrastructure, welfare, and skills for every family.",
        "en",
        12.5,
        450,
        MUTED,
        328,
        leading=1.35,
    )
    return ui.img


SCREENS = {
    "about": screen_about,
    "file": screen_file,
    "track": screen_track,
    "more": screen_more,
    "news": screen_news,
}

STORIES = [
    ("01-know-your-representative", "about", "Know Your", "Representative", "Profile, public service, and constituency information in one place."),
    ("02-file-a-grievance", "file", "File a", "Grievance", "Raise your concern with ease and reach the office directly."),
    ("03-track-grievance-status", "track", "Track Grievance", "Status", "Check the latest update and progress on your grievance."),
    ("04-ai-assistant", "more", "Get Help from", "the AI Assistant", "Ask questions and get instant support in Tamil or English."),
    ("05-news-and-services", "news", "Access News &", "Constituency Services", "Stay updated on the Minister's activities and explore key services."),
]


def draw_background(im: Image.Image):
    w, h = im.size
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w, h), fill=CREAM)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse((int(w * 0.42), int(-h * 0.08), int(w * 1.18), int(h * 0.34)), fill=(255, 214, 204, 170))
    od.ellipse((int(w * 0.72), int(-h * 0.12), int(w * 1.2), int(h * 0.16)), fill=(244, 176, 168, 110))
    od.ellipse((int(-w * 0.45), int(h * 0.74), int(w * 0.72), int(h * 1.16)), fill=(186, 18, 28, 255))
    od.ellipse((int(w * 0.18), int(h * 0.80), int(w * 1.25), int(h * 1.22)), fill=(146, 10, 20, 255))
    od.ellipse((int(-w * 0.2), int(h * 0.90), int(w * 0.48), int(h * 1.12)), fill=(110, 6, 14, 255))
    im.alpha_composite(overlay)


def fit_line(text, max_px, start, weight=780):
    size = start
    while size > 28:
        face = mfont(OUTFIT, size, weight)
        if face.getlength(text) <= max_px:
            return face, size
        size -= 2
    return mfont(OUTFIT, size, weight), size


def draw_headline(d: ImageDraw.ImageDraw, w: int, y: int, line1: str, line2: str, subtitle: str, scale: float):
    max_w = int(w * 0.86)
    start = int(86 * scale)
    f1, s1 = fit_line(line1, max_w, start, 760)
    f2, s2 = fit_line(line2, max_w, start, 780)
    size = min(s1, s2)
    if size != s1:
        f1 = mfont(OUTFIT, size, 760)
    if size != s2:
        f2 = mfont(OUTFIT, size, 780)
    d.text((w / 2, y), line1, font=f1, fill=INK, anchor="mt")
    y2 = y + int(size * 1.02)
    d.text((w / 2, y2), line2, font=f2, fill=RED_DEEP, anchor="mt")
    bar_y = y2 + size + int(16 * scale)
    bar_w = int(92 * scale)
    d.rounded_rectangle((w / 2 - bar_w / 2, bar_y, w / 2 + bar_w / 2, bar_y + max(6, int(7 * scale))), radius=8, fill=BRAND)
    sub_size = int(32 * scale)
    sub = mfont(OUTFIT, sub_size, 460)
    words = subtitle.split()
    lines, cur = [], ""
    limit = w * 0.78
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        if sub.getlength(trial) <= limit:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    sy = bar_y + int(28 * scale)
    for i, line in enumerate(lines):
        d.text((w / 2, sy + i * int(sub_size * 1.35)), line, font=sub, fill=(78, 62, 56), anchor="mt")
    bottom = sy + len(lines) * int(sub_size * 1.35)
    return bottom


def place_phone(canvas: Image.Image, screen: Image.Image, top_limit: int, platform: str):
    w, h = canvas.size
    d = ImageDraw.Draw(canvas)
    avail_top = top_limit + int(h * 0.018)
    avail_bot = h - int(h * 0.012)
    avail_h = avail_bot - avail_top
    ratio = 0.468
    phone_w = min(w * 0.76, avail_h * ratio)
    phone_h = phone_w / ratio
    if phone_h > avail_h:
        phone_h = avail_h
        phone_w = phone_h * ratio
    phone_w, phone_h = int(phone_w), int(phone_h)
    x = (w - phone_w) // 2
    y = avail_bot - phone_h
    if y < avail_top:
        y = avail_top

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 18, y + 28, x + phone_w - 8, y + phone_h + 16), radius=int(phone_w * 0.14), fill=(70, 10, 16, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(shadow)

    radius = int(phone_w * 0.135)
    d.rounded_rectangle((x, y, x + phone_w, y + phone_h), radius=radius, fill=(22, 22, 24))
    # side buttons
    d.rounded_rectangle((x - int(phone_w * 0.012), y + int(phone_h * 0.18), x, y + int(phone_h * 0.26)), radius=3, fill=(58, 58, 62))
    d.rounded_rectangle((x - int(phone_w * 0.012), y + int(phone_h * 0.29), x, y + int(phone_h * 0.40)), radius=3, fill=(58, 58, 62))
    d.rounded_rectangle((x + phone_w, y + int(phone_h * 0.24), x + phone_w + int(phone_w * 0.012), y + int(phone_h * 0.34)), radius=3, fill=(58, 58, 62))

    bezel = max(8, int(phone_w * 0.028))
    ix, iy = x + bezel, y + bezel
    iw, ih = phone_w - bezel * 2, phone_h - bezel * 2
    inner_r = max(12, radius - bezel)
    fitted = screen.resize((iw, ih), Image.Resampling.LANCZOS)
    mask = Image.new("L", (iw, ih), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, iw - 1, ih - 1), radius=inner_r, fill=255)
    canvas.paste(fitted, (ix, iy), mask)


def render_story(size, story, screen, platform):
    w, h = size
    im = Image.new("RGBA", size, (*CREAM, 255))
    draw_background(im)
    d = ImageDraw.Draw(im)
    scale = w / 1080
    top = int((92 if h / w > 2.05 else 48) * scale)
    bottom = draw_headline(d, w, top, story[2], story[3], story[4], scale)
    place_phone(im, screen, bottom, platform)
    return im.convert("RGB")


def feature_graphic() -> Image.Image:
    w, h = 1024, 500
    im = Image.new("RGBA", (w, h), (*CREAM, 255))
    d = ImageDraw.Draw(im)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse((620, -180, 1280, 680), fill=(168, 14, 24, 255))
    od.ellipse((760, -80, 1200, 560), fill=(120, 8, 16, 255))
    od.ellipse((-80, -160, 420, 220), fill=(255, 214, 204, 160))
    im.alpha_composite(overlay)
    d = ImageDraw.Draw(im)
    kicker = mfont(OUTFIT, 22, 700)
    d.text((56, 78), "RADHAKRISHNAN NAGAR", font=kicker, fill=BRAND)
    title = mfont(OUTFIT, 64, 780)
    d.text((56, 112), "Know your", font=title, fill=INK)
    d.text((56, 176), "representative", font=title, fill=RED_DEEP)
    d.rounded_rectangle((56, 262, 148, 270), radius=4, fill=BRAND)
    sub = mfont(OUTFIT, 24, 460)
    d.text((56, 294), "File a grievance, track it, and reach", font=sub, fill=(78, 62, 56))
    d.text((56, 328), "the office — in Tamil or English.", font=sub, fill=(78, 62, 56))
    pills = ["File", "Track", "Assistant", "News"]
    x = 56
    pf = mfont(OUTFIT, 18, 650)
    for pill in pills:
        tw = pf.getlength(pill)
        d.rounded_rectangle((x, 392, x + tw + 36, 432), radius=20, fill=WHITE)
        d.text((x + 18, 412), pill, font=pf, fill=RED_DEEP, anchor="lm")
        x += tw + 48
    photo = ImageOps.fit(Image.open(PORTRAIT).convert("RGB"), (300, 380), Image.Resampling.LANCZOS, centering=(0.5, 0.28))
    mask = Image.new("L", photo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 299, 379), radius=28, fill=255)
    im.paste(photo, (680, 60), mask)
    return im.convert("RGB")


def main():
    os.makedirs(ROOT, exist_ok=True)
    cache = {}
    for key, fn in SCREENS.items():
        cache[(key, "ios")] = fn("ios")
        cache[(key, "android")] = fn("android")
        print("screen", key)

    specs = [
        ("app-store", (1320, 2868), "ios"),
        ("play-store", (1080, 1920), "android"),
    ]
    for prefix, size, platform in specs:
        for story in STORIES:
            img = render_story(size, story, cache[(story[1], platform)], platform)
            path = os.path.join(ROOT, f"{prefix}-{story[0]}.png")
            img.save(path, "PNG", optimize=True)
            print(path, img.size)

    feat = feature_graphic()
    feat_path = os.path.join(ROOT, "play-store-feature-graphic.png")
    feat.save(feat_path, "PNG", optimize=True)
    print(feat_path, feat.size)


if __name__ == "__main__":
    main()
