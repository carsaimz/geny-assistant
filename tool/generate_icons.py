"""Generate PrivateAgent 'Genie' launcher icons + in-app logo asset.

Design: golden magic lamp with a white sparkle wisp on an indigo gradient
(brand colors from AppTheme: indigo #6366F1, amber #F59E0B).
All artwork is drawn at 4x supersampling and downscaled with LANCZOS.
"""
import math
import os

from PIL import Image, ImageDraw

BASE = '/Users/orailnoor/Downloads/cline private agent'
RES = f'{BASE}/android/app/src/main/res'
ASSETS = f'{BASE}/assets/icon'

SS = 4          # supersampling factor
S = 1024        # design canvas

INDIGO_TOP = (129, 140, 248)     # indigoLight #818CF8
INDIGO_BOT = (49, 46, 129)       # indigo-900 #312E81
GOLD = (251, 191, 36)            # amber-400 #FBBF24
GOLD_DARK = (245, 158, 11)       # amber-500 #F59E0B (AppTheme.warning)
WHITE = (255, 255, 255)


def sc(v):
    return v * SS


def gradient(size):
    """Vertical two-stop gradient, rendered at final size."""
    img = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(round(INDIGO_TOP[i] + (INDIGO_BOT[i] - INDIGO_TOP[i]) * t)
                  for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return img


def star(d, cx, cy, r, color, inner=0.24):
    """Four-point concave sparkle star."""
    pts = []
    for i in range(8):
        ang = -math.pi / 2 + i * math.pi / 4
        rad = r if i % 2 == 0 else r * inner
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    d.polygon(pts, fill=color)


def draw_artwork(scale_content=1.0):
    """Lamp + wisp + sparkles on a transparent canvas (supersampled)."""
    img = Image.new('RGBA', (S * SS, S * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def E(box, **kw):  # scaled ellipse
        d.ellipse([sc(v) for v in box], **kw)

    def P(pts, **kw):  # scaled polygon
        d.polygon([(sc(x), sc(y)) for x, y in pts], **kw)

    # ---- magic lamp -------------------------------------------------
    # handle (behind body)
    d.arc([sc(650), sc(580), sc(800), sc(730)], start=-75, end=135,
          fill=GOLD_DARK + (255,), width=sc(34))
    # spout
    P([(330, 615), (243, 505), (293, 465), (378, 562)], fill=GOLD + (255,))
    # body
    E((298, 558, 722, 772), fill=GOLD + (255,))
    # body shading (lower arc band)
    d.arc([sc(318), sc(578), sc(702), sc(762)], start=20, end=160,
          fill=GOLD_DARK + (255,), width=sc(20))
    # lid + knob
    E((442, 520, 578, 588), fill=GOLD_DARK + (255,))
    E((490, 492, 530, 532), fill=GOLD + (255,))
    # spout opening
    E((238, 468, 300, 512), fill=GOLD_DARK + (255,))
    # foot
    P([(428, 766), (592, 766), (628, 812), (392, 812)], fill=GOLD_DARK + (255,))
    E((392, 796, 628, 828), fill=GOLD_DARK + (255,))

    # ---- smoke wisp from the spout ----------------------------------
    for i in range(9):
        t = i / 8
        x = 268 + 58 * math.sin(t * math.pi * 1.15)
        y = 452 - 165 * t
        r = 17 - 8 * t
        E((x - r, y - r, x + r, y + r), fill=WHITE + (190,))

    # ---- sparkles ----------------------------------------------------
    # soft glow behind the main star
    star(d, sc(345), sc(228), sc(150), WHITE + (38,))
    star(d, sc(345), sc(228), sc(98), WHITE + (255,))
    star(d, sc(455), sc(330), sc(44), WHITE + (230,))
    star(d, sc(238), sc(318), sc(30), WHITE + (200,))

    if scale_content != 1.0:
        # scale artwork around canvas centre (used to fit safe zones)
        w = img.width
        new_w = round(w * scale_content)
        img = img.resize((new_w, new_w), Image.LANCZOS)
        canvas = Image.new('RGBA', (w, w), (0, 0, 0, 0))
        canvas.paste(img, ((w - new_w) // 2, (w - new_w) // 2), img)
        img = canvas
    return img


def save_scaled(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print(f'  {size:>4}px  {path}')


DENSITIES_FG = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216,
                'xxhdpi': 324, 'xxxhdpi': 432}
DENSITIES_LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96,
                    'xxhdpi': 144, 'xxxhdpi': 192}

print('foreground layers:')
fg = draw_artwork()  # content already inside the central safe zone
for den, px in DENSITIES_FG.items():
    save_scaled(fg, f'{RES}/mipmap-{den}/ic_launcher_foreground.png', px)

print('background layers:')
bg = gradient(S * SS)
for den, px in DENSITIES_FG.items():
    save_scaled(bg, f'{RES}/mipmap-{den}/ic_launcher_background.png', px)

print('legacy launcher icons:')
legacy_art = draw_artwork(scale_content=0.92)
legacy = gradient(S * SS)
legacy.paste(legacy_art, (0, 0), legacy_art)
for den, px in DENSITIES_LEGACY.items():
    save_scaled(legacy, f'{RES}/mipmap-{den}/ic_launcher.png', px)

print('in-app logo asset:')
save_scaled(draw_artwork(), f'{ASSETS}/genie_logo.png', 512)

print('DONE')
