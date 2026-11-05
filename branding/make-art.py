#!/usr/bin/env python3
"""Generate TermOS's wallpaper and boot-splash images.

    python3 branding/make-art.py [--font /path/to/Mono-Bold.ttf]

Writes:
    branding/wallpaper/contents/images/<W>x<H>.png   KDE wallpaper package
                                                     (landscape + phone portrait)
    branding/wallpaper/contents/screenshot.png       wallpaper preview
    branding/plymouth/termos/*.png                   Plymouth boot splash images
    branding/calamares/branding/termos/*.png         installer (Calamares) images
    branding/grub/termos/*.png                       GRUB boot menu theme images

The art is Matrix-style digital rain in TermOS green, with the TermOS
wordmark in the middle. A fixed random seed keeps the output reproducible.
Needs Pillow (python3-pillow on Fedora).
"""
import argparse
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

FONT_CANDIDATES = [
    "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono-Bold.ttf",  # Fedora
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",         # Debian/Ubuntu
    "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",                     # Arch
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
]

BLACK = (2, 8, 4)
DARK = (4, 22, 10)
GREEN = (0, 255, 102)
MID = (0, 170, 68)
DIM = (0, 70, 30)
HEAD = (200, 255, 215)

GLYPHS = "01"


def find_font(path):
    for p in [path] + FONT_CANDIDATES:
        if p and os.path.exists(p):
            return p
    sys.exit("make-art: no monospace TTF found; pass --font /path/to/font.ttf")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(w, h):
    img = Image.new("RGB", (w, h), BLACK)
    d = ImageDraw.Draw(img)
    for y in range(h):
        # Darkest at the top, faint green glow toward the bottom.
        t = (y / h) ** 2
        d.line([(0, y), (w, y)], fill=lerp(BLACK, DARK, t))
    return img


def draw_rain(img, font_path, cell, seed, density=0.55):
    """Columns of falling 0/1 trails: bright head, fading tail."""
    rnd = random.Random(seed)
    w, h = img.size
    font = ImageFont.truetype(font_path, cell)
    layer = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    cols, rows = w // cell + 1, h // cell + 1
    for c in range(cols):
        if rnd.random() > density:
            continue
        for _ in range(rnd.randint(1, 2)):
            length = rnd.randint(6, rows // 2 + 4)
            head = rnd.randint(0, rows + length // 2)
            for i in range(length):
                r = head - i
                if r < 0 or r >= rows:
                    continue
                if i == 0:
                    color = HEAD
                else:
                    t = i / length
                    color = lerp(GREEN, DIM, t) if t < 0.5 else lerp(DIM, DARK, (t - 0.5) * 2)
                d.text((c * cell, r * cell), rnd.choice(GLYPHS), font=font, fill=color)
    # Soft glow to go under the sharp glyphs.
    glow = layer.filter(ImageFilter.GaussianBlur(cell / 3))
    return layer, glow


def add(a, b, k=1.0):
    """Additive blend (light adds up, like a screen glowing)."""
    if k != 1.0:
        b = Image.eval(b, lambda v: int(v * k))
    return ImageChops.add(a, b)


def wordmark(size, font_path, text="TermOS"):
    """Green wordmark with glow on a transparent background."""
    font = ImageFont.truetype(font_path, size)
    l, t, r, b = font.getbbox(text)
    pad = size // 2
    w, h = r - l + pad * 2, b - t + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - l, pad - t), text, font=font, fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(size / 6))
    glow = Image.eval(glow, lambda v: min(255, int(v * 1.6)))
    img = Image.new("RGBA", (w, h), GREEN + (0,))
    img.putalpha(glow)
    solid = Image.new("RGBA", (w, h), HEAD + (0,))
    solid.putalpha(mask)
    return Image.alpha_composite(img, solid)


def make_wallpaper(w, h, font_path, with_mark=True):
    base = gradient(w, h)
    short = min(w, h)
    cell = max(14, short // 54)
    far, far_glow = draw_rain(base, font_path, cell // 2 + 4, seed=7, density=0.5)
    near, near_glow = draw_rain(base, font_path, cell, seed=42, density=0.45)
    img = add(base, far, 0.35)
    img = add(img, far_glow, 0.25)
    img = add(img, near, 0.9)
    img = add(img, near_glow, 0.6)

    # Darken the middle so the wordmark reads clearly.
    vignette = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vignette).ellipse(
        [w / 2 - short * 0.53, h / 2 - short * 0.20,
         w / 2 + short * 0.53, h / 2 + short * 0.22], fill=235)
    vignette = vignette.filter(ImageFilter.GaussianBlur(short / 10))
    img = Image.composite(Image.new("RGB", (w, h), BLACK), img, vignette)

    if not with_mark:
        return img

    # Portrait (phone) screens get a wordmark sized to fit the width.
    mark = wordmark(short // 7 if w >= h else w // 6, font_path)
    img = img.convert("RGBA")
    img.alpha_composite(mark, ((w - mark.width) // 2, (h - mark.height) // 2 - short // 40))

    tag_font = ImageFont.truetype(font_path, max(12, short // 48))
    tag = "fedora  ·  ubuntu  ·  nix"
    tl, tt, tr, tb = tag_font.getbbox(tag)
    ImageDraw.Draw(img).text(
        ((w - (tr - tl)) // 2, h // 2 + mark.height // 2 - short // 50),
        tag, font=tag_font, fill=MID + (255,))
    return img.convert("RGB")


def make_plymouth(out, font_path):
    os.makedirs(out, exist_ok=True)
    wordmark(96, font_path).save(os.path.join(out, "logo.png"))
    # Rain glyph sprites: 0/1 at a few brightness levels (index 0 = head).
    font = ImageFont.truetype(font_path, 22)
    levels = [HEAD, GREEN, lerp(GREEN, DIM, 0.4), MID, DIM, lerp(DIM, DARK, 0.5)]
    for g in GLYPHS:
        for i, color in enumerate(levels):
            im = Image.new("RGBA", (16, 26), (0, 0, 0, 0))
            ImageDraw.Draw(im).text((1, 0), g, font=font, fill=color + (255,))
            im.save(os.path.join(out, f"glyph-{g}-{i}.png"))
    # Dark backdrop behind the logo so it stands out from the rain.
    shade = Image.new("L", (900, 420), 0)
    ImageDraw.Draw(shade).ellipse([60, 40, 840, 380], fill=235)
    shade = shade.filter(ImageFilter.GaussianBlur(50))
    backdrop = Image.new("RGBA", shade.size, BLACK + (0,))
    backdrop.putalpha(shade)
    backdrop.save(os.path.join(out, "shade.png"))
    # Progress bar pieces.
    Image.new("RGBA", (320, 4), DIM + (255,)).save(os.path.join(out, "bar-bg.png"))
    Image.new("RGBA", (320, 4), GREEN + (255,)).save(os.path.join(out, "bar-fg.png"))
    # Password prompt pieces (for encrypted disks).
    box = Image.new("RGBA", (360, 44), (0, 0, 0, 230))
    ImageDraw.Draw(box).rectangle([0, 0, 359, 43], outline=GREEN + (255,), width=2)
    box.save(os.path.join(out, "entry.png"))
    dot = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse([1, 1, 10, 10], fill=GREEN + (255,))
    dot.save(os.path.join(out, "bullet.png"))
    lock_font = ImageFont.truetype(font_path, 18)
    lock = Image.new("RGBA", (360, 26), (0, 0, 0, 0))
    ImageDraw.Draw(lock).text((0, 2), "Disk password:", font=lock_font, fill=MID + (255,))
    lock.save(os.path.join(out, "prompt.png"))


def make_calamares(out, font_path):
    """Installer branding: icon, welcome logo and slideshow background."""
    os.makedirs(out, exist_ok=True)
    # Square app icon: a glowing ">_" prompt on a dark rounded tile.
    size = 256
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(tile).rounded_rectangle(
        [8, 8, size - 9, size - 9], radius=44, fill=BLACK + (255,),
        outline=MID + (255,), width=6)
    prompt = wordmark(110, font_path, ">_")
    tile.alpha_composite(prompt, ((size - prompt.width) // 2, (size - prompt.height) // 2))
    tile.save(os.path.join(out, "logo.png"))
    wordmark(120, font_path).save(os.path.join(out, "welcome.png"))
    # Slideshow background: rain only, darkened so text on top stays readable.
    bg = make_wallpaper(1280, 720, font_path, with_mark=False)
    bg = Image.blend(bg, Image.new("RGB", bg.size, BLACK), 0.35)
    bg.save(os.path.join(out, "slide-bg.png"), optimize=True)


def make_grub(out, font_path):
    """GRUB theme images: background, logo and the selected-item bar."""
    os.makedirs(out, exist_ok=True)
    bg = make_wallpaper(1920, 1080, font_path, with_mark=False)
    bg = Image.blend(bg, Image.new("RGB", bg.size, BLACK), 0.45)
    bg.save(os.path.join(out, "background.png"), optimize=True)
    wordmark(110, font_path).save(os.path.join(out, "logo.png"))
    # GRUB draws highlight boxes from 9 slices: select_{nw,n,ne,w,c,e,sw,s,se}.
    for piece in ["nw", "n", "ne", "w", "c", "e", "sw", "s", "se"]:
        Image.new("RGBA", (4, 4), GREEN + (255,)).save(os.path.join(out, f"select_{piece}.png"))
    # Menu frame: a thin dim-green border around a translucent black box.
    for piece in ["nw", "n", "ne", "w", "e", "sw", "s", "se"]:
        Image.new("RGBA", (2, 2), MID + (255,)).save(os.path.join(out, f"menu_{piece}.png"))
    Image.new("RGBA", (4, 4), (0, 0, 0, 170)).save(os.path.join(out, "menu_c.png"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--font", help="monospace bold TTF to draw with")
    args = ap.parse_args()
    font_path = find_font(args.font)

    images = os.path.join(HERE, "wallpaper", "contents", "images")
    os.makedirs(images, exist_ok=True)
    # Landscape for desktops, portrait for phones. Plasma picks the closest
    # match for each screen; the phone sizes also work as phone wallpapers.
    for w, h in [(3840, 2160), (1920, 1080), (1440, 3200), (1080, 2400)]:
        path = os.path.join(images, f"{w}x{h}.png")
        make_wallpaper(w, h, font_path).save(path, optimize=True)
        print("wrote", os.path.relpath(path))
    shot = os.path.join(HERE, "wallpaper", "contents", "screenshot.png")
    make_wallpaper(1920, 1080, font_path).resize((400, 225), Image.LANCZOS).save(shot)
    print("wrote", os.path.relpath(shot))

    cal = os.path.join(HERE, "calamares", "branding", "termos")
    make_calamares(cal, font_path)
    print("wrote", os.path.relpath(cal) + "/*.png")

    grub = os.path.join(HERE, "grub", "termos")
    make_grub(grub, font_path)
    print("wrote", os.path.relpath(grub) + "/*.png")

    ply = os.path.join(HERE, "plymouth", "termos")
    make_plymouth(ply, font_path)
    print("wrote", os.path.relpath(ply) + "/*.png")


if __name__ == "__main__":
    main()
