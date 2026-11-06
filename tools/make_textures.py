import math, os, struct
import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
# source package: ../AZSGW2UI/Textures; repository layout (the addon is the repo root): ../Textures
_PKG = os.path.join(_HERE, "..", "AZSGW2UI")
OUT = os.environ.get("AZS_TEXTURES") or os.path.join(_PKG if os.path.isdir(_PKG) else os.path.join(_HERE, ".."), "Textures")
os.makedirs(OUT, exist_ok=True)


def write_tga(name, rgba):
    """rgba: float array (h, w, 4) in 0..1, row 0 = top. Writes 32-bit uncompressed, bottom-left origin."""
    h, w, _ = rgba.shape
    a = np.clip(rgba, 0, 1)
    a = (a * 255 + 0.5).astype(np.uint8)
    bgra = a[:, :, [2, 1, 0, 3]]
    bgra = bgra[::-1]  # bottom row first
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(hdr)
        f.write(bgra.tobytes())
    print("wrote", name, w, h)


def clamp01(x):
    return np.clip(x, 0.0, 1.0)


def sstep(a, b, x):
    t = clamp01((x - a) / (b - a))
    return t * t * (3 - 2 * t)


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    return x, y


# ---------------------------------------------------------------- orb fill
# Grey-scale shaded sphere; tinted red / gold / dark in game via SetVertexColor.
def orb_fill(n=128):
    x, y = grid(n)
    c = (n - 1) / 2.0
    R = n / 2.0 - 1.0
    dx, dy = x - c, y - c
    d = np.hypot(dx, dy)
    alpha = clamp01(R + 0.5 - d)
    nx = dx / R
    ny = -dy / R
    r2 = np.minimum(nx * nx + ny * ny, 1.0)
    nz = np.sqrt(1.0 - r2)
    L = np.array([-0.45, 0.55, 0.70])
    L = L / np.linalg.norm(L)
    diff = clamp01(nx * L[0] + ny * L[1] + nz * L[2])
    v = 0.42 + 0.58 * diff ** 0.85
    v = v * (0.50 + 0.50 * nz ** 0.55)      # deeper edge, rounder look
    # slightly brighter lower rim (bounce light)
    rim = sstep(0.55, 1.0, np.sqrt(r2)) * clamp01(-ny) * 0.10
    v = clamp01(v + rim)
    rgba = np.zeros((n, n, 4))
    rgba[..., 0] = v
    rgba[..., 1] = v
    rgba[..., 2] = v
    rgba[..., 3] = alpha
    write_tga("orb_fill.tga", rgba)


# ---------------------------------------------------------------- orb gloss
def orb_gloss(n=128):
    x, y = grid(n)
    c = (n - 1) / 2.0
    R = n / 2.0 - 1.0
    d = np.hypot(x - c, y - c)
    inside = clamp01(R + 0.5 - d)
    u = x / (n - 1)
    v = y / (n - 1)
    # main highlight, upper left
    ang = math.radians(-35)
    cu, cv = 0.36, 0.27
    du, dv = u - cu, v - cv
    ru = du * math.cos(ang) - dv * math.sin(ang)
    rv = du * math.sin(ang) + dv * math.cos(ang)
    g = np.exp(-((ru / 0.20) ** 2 + (rv / 0.10) ** 2))
    hi = 0.62 * g
    # soft secondary glow lower right
    du2, dv2 = u - 0.64, v - 0.80
    g2 = np.exp(-((du2 / 0.22) ** 2 + (dv2 / 0.08) ** 2))
    hi = hi + 0.12 * g2
    # crisp curved reflection near the top
    cu2, cv2 = 0.50, 0.19
    g3 = np.exp(-(((u - cu2) / 0.30) ** 2 + ((v - cv2) / 0.085) ** 2) ** 1.5)
    hi = hi + 0.34 * g3
    # faint top-edge sheen
    sheen = sstep(0.0, 0.45, 1.0 - v) * 0.05
    a = clamp01(hi + sheen) * inside
    rgba = np.zeros((n, n, 4))
    rgba[..., 0:3] = 1.0
    rgba[..., 3] = a
    write_tga("orb_gloss.tga", rgba)


# ---------------------------------------------------------------- orb ring
def orb_ring(n=256):
    x, y = grid(n)
    c = (n - 1) / 2.0
    R_out = 125.0
    R_in = 96.5
    dx, dy = x - c, y - c
    d = np.hypot(dx, dy)
    th = np.arctan2(-dy, dx)  # math angle, y up
    t = (d - R_in) / (R_out - R_in)

    light = 0.5 + 0.5 * np.cos(th - math.radians(125))  # light from upper-left

    def col(r, g, b):
        return np.stack([np.full_like(d, r), np.full_like(d, g), np.full_like(d, b)], axis=-1)

    inner_dark = col(0.05, 0.04, 0.03)
    edge_dark = col(0.05, 0.045, 0.04)

    gold_light = (0.55 + 0.60 * light)[..., None]
    gold_in = col(0.90, 0.74, 0.44) * gold_light
    gold_in = gold_in * (1.0 - 0.30 * clamp01((t - 0.06) / 0.16))[..., None]
    gold_out = col(0.82, 0.66, 0.38) * (0.50 + 0.60 * light)[..., None]

    fine = (0.03 * np.sin(th * 90.0))[..., None]
    body = col(0.22, 0.185, 0.15) * (0.55 + 0.85 * light)[..., None] + fine
    # gentle radial gradient on the body for a rounded look
    body = body * (0.85 + 0.30 * np.sin(clamp01((t - 0.20) / 0.58) * math.pi))[..., None]

    def mix(a, b, w):
        return a * (1 - w[..., None]) + b * w[..., None]

    rgb = inner_dark
    rgb = mix(rgb, gold_in, sstep(0.05, 0.085, t))
    rgb = mix(rgb, body, sstep(0.20, 0.24, t))
    rgb = mix(rgb, gold_out, sstep(0.76, 0.80, t))
    rgb = mix(rgb, edge_dark, sstep(0.90, 0.945, t))

    # diamond studs every 45 degrees
    mid = (R_in + R_out) / 2.0
    for k in range(8):
        phi = math.radians(k * 45.0 + 22.5)
        dth = np.arctan2(np.sin(th - phi), np.cos(th - phi))
        s = dth * d              # arc length in px
        u = d - mid              # radial offset in px
        dia = np.abs(s) / 6.0 + np.abs(u) / 9.5
        w = clamp01((1.0 - dia) * 4.0)
        stud_light = (0.65 + 0.55 * light)[..., None]
        stud = col(0.95, 0.80, 0.50) * stud_light
        # darker centre bevel
        core = clamp01((0.45 - dia) * 4.0)
        stud = mix(stud, col(0.40, 0.30, 0.16) * stud_light, core)
        rgb = mix(rgb, stud, w)

    alpha = clamp01(R_out + 0.5 - d) * clamp01(d - R_in + 0.5)
    rgba = np.zeros((n, n, 4))
    rgba[..., 0:3] = clamp01(rgb)
    rgba[..., 3] = alpha
    write_tga("orb_ring.tga", rgba)


# ---------------------------------------------------------------- thin orb rim (steel, no studs)
def orb_rim(n=256):
    x, y = grid(n)
    c = (n - 1) / 2.0
    R0, R1 = 97.0, 109.0
    dx, dy = x - c, y - c
    d = np.hypot(dx, dy)
    th = np.arctan2(-dy, dx)
    t = (d - R0) / (R1 - R0)
    light = 0.5 + 0.5 * np.cos(th - math.radians(125))
    steel = np.stack([np.full_like(d, 0.74), np.full_like(d, 0.70), np.full_like(d, 0.62)], axis=-1)
    steel = steel * (0.30 + 0.80 * light)[..., None]
    steel = steel * (0.85 + 0.35 * np.exp(-((t - 0.32) / 0.12) ** 2))[..., None]   # bright bevel line
    dark = np.array([0.03, 0.03, 0.035])
    w_in = sstep(0.10, 0.20, t)
    w_out = 1.0 - sstep(0.80, 0.90, t)
    w = (w_in * w_out)[..., None]
    rgb = dark * (1 - w) + steel * w
    alpha = clamp01(d - R0 + 0.5) * clamp01(R1 + 0.5 - d)
    rgba = np.zeros((n, n, 4))
    rgba[..., 0:3] = clamp01(rgb)
    rgba[..., 3] = alpha
    write_tga("orb_rim.tga", rgba)


# ---------------------------------------------------------------- slot border
def slot(n=64):
    x, y = grid(n)
    e_l, e_t, e_r, e_b = x, y, (n - 1) - x, (n - 1) - y
    e = np.minimum(np.minimum(e_l, e_t), np.minimum(e_r, e_b))
    # bevel: top/left lit, bottom/right in shade
    lit = np.minimum(e_l, e_t)
    shade = np.minimum(e_r, e_b)
    k = clamp01(0.5 + (shade - lit) * 0.25)   # 1 -> lit side (top/left closer)
    k = np.where(lit < shade, 1.0, np.where(lit > shade, 0.0, 0.5))
    base = np.array([0.74, 0.60, 0.34])
    rgba = np.zeros((n, n, 4))
    bevel = 0.60 + 0.65 * k  # lit 1.25, shade 0.60
    for i in range(3):
        rgba[..., i] = base[i] * bevel
    a = np.zeros((n, n))
    # outer black line
    outer = e < 1
    rgba[outer, 0:3] = 0.02
    a[outer] = 0.95
    ring = (e >= 1) & (e < 4)
    a[ring] = 1.0
    # slight fade of the gold toward the inner edge
    fade = np.where(ring, 1.0 - 0.22 * (e - 1) / 2.0, 1.0)
    for i in range(3):
        rgba[..., i] *= np.where(ring, fade, 1.0)
    inner = e == 4
    rgba[inner, 0:3] = 0.02
    a[inner] = 0.85
    vign = (e >= 5) & (e < 10)
    rgba[vign, 0:3] = 0.0
    a[vign] = 0.38 * (1.0 - (e[vign] - 5) / 5.0)
    rgba[..., 3] = a
    write_tga("slot.tga", rgba)


# ---------------------------------------------------------------- bar gloss
def bar_gloss(w=16, h=32):
    rgba = np.zeros((h, w, 4))
    for yy in range(h):
        if yy < 12:
            rgba[yy, :, 0:3] = 1.0
            rgba[yy, :, 3] = 0.30 * (1 - yy / 12.0)
        elif yy >= 16:
            rgba[yy, :, 0:3] = 0.0
            rgba[yy, :, 3] = 0.28 * ((yy - 16) / 15.0)
    write_tga("bar_gloss.tga", rgba)


# ---------------------------------------------------------------- band (horizontal fade, white)
def band(w=128, h=16):
    rgba = np.zeros((h, w, 4))
    xs = (np.arange(w) + 0.5) / w
    a = np.sin(np.pi * xs) ** 0.45
    rgba[..., 0:3] = 1.0
    rgba[..., 3] = a[None, :]
    write_tga("band.tga", rgba)



# ================================================================ round 4: action bar wings, frames, minimap art
from PIL import Image, ImageDraw

SLOT, GAP, PADX, NECK, WH = 44, 4, 7, 16, 58


def mix(a, b, w):
    w = np.asarray(w)[..., None] if np.ndim(w) == 2 else w
    return a * (1 - w) + b * w


def metal_bands(de, light, interior):
    """de: distance inside the shape (px), light 0..1, interior: (h,w,3). Returns rgb (h,w,3)."""
    steel = np.stack([np.full_like(de, 0.72), np.full_like(de, 0.72), np.full_like(de, 0.75)], axis=-1)
    steel = steel * (0.26 + 0.62 * light)[..., None]
    gold = np.array([0.62, 0.50, 0.28]) * 0.9
    dark = np.array([0.035, 0.035, 0.04])
    black = np.array([0.015, 0.015, 0.02])
    m = lambda cond: cond[..., None]
    col = interior.copy()
    col = np.where(m((de >= 5) & (de < 6)), col * 0.35 + gold * 0.65, col)
    col = np.where(m((de >= 4) & (de < 5)), dark, col)
    col = np.where(m((de >= 1) & (de < 4)), steel, col)
    col = np.where(m(de < 1), black, col)
    return col


def wing(name, n, canvas_w, flip):
    W = PADX + n * SLOT + (n - 1) * GAP + PADX + NECK
    H = WH
    c = 13.0
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    x += 0.5
    y += 0.5
    r2 = math.sqrt(2.0)
    d = np.stack([y, H - y, x, (x + y - c) / r2, (x - y + H - c) / r2])
    de = d.min(axis=0)
    which = d.argmin(axis=0)
    nrm = np.array([[0, -1], [0, 1], [-1, 0], [-1 / r2, -1 / r2], [-1 / r2, 1 / r2]])
    nx, ny = nrm[which, 0], nrm[which, 1]
    L = np.array([-0.35, -0.94])
    L = L / np.linalg.norm(L)
    light = clamp01(0.5 + 0.5 * (nx * L[0] + ny * L[1]))
    t = (y / H)[..., None]
    v = 0.17 - 0.12 * t
    interior = np.concatenate([v * 1.0, v * 0.97, v * 1.03], axis=-1)
    # soft sheen just inside the trim
    sheen = (np.exp(-((de - 7.0) / 2.5) ** 2) * 0.07 * light)[..., None]
    interior = interior + sheen
    rgb = metal_bands(de, light, interior)
    # recessed wells for the slots
    sy = (H - SLOT) // 2
    for i in range(n):
        sx = PADX + i * (SLOT + GAP)
        x0, x1, y0, y1 = sx - 1, sx + SLOT + 1, sy - 1, sy + SLOT + 1
        inside = (x >= x0) & (x < x1) & (y >= y0) & (y < y1)
        rgb[inside] = np.array([0.012, 0.012, 0.016])
        top = inside & (y < y0 + 1)
        left = inside & (x < x0 + 1)
        bot = inside & (y >= y1 - 1)
        right = inside & (x >= x1 - 1)
        rgb[top | left] = 0.0
        rgb[bot | right] = np.array([0.30, 0.29, 0.30])
    alpha = clamp01(de + 0.5)
    img = np.zeros((H, W, 4))
    img[..., 0:3] = clamp01(rgb)
    img[..., 3] = alpha
    if flip:
        img = img[:, ::-1]
    canvas = np.zeros((64, canvas_w, 4))
    canvas[:H, :W] = img
    write_tga(name, canvas)
    return W, H


def frame9(n=64):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    x += 0.5
    y += 0.5
    d = np.stack([y, n - y, x, n - x])
    de = d.min(axis=0)
    which = d.argmin(axis=0)
    nrm = np.array([[0, -1], [0, 1], [-1, 0], [1, 0]])
    nx, ny = nrm[which, 0], nrm[which, 1]
    L = np.array([-0.35, -0.94])
    L = L / np.linalg.norm(L)
    light = clamp01(0.5 + 0.5 * (nx * L[0] + ny * L[1]))
    interior = np.zeros((n, n, 3))
    rgb = metal_bands(de, light, interior)
    alpha = np.where(de < 6, 1.0, 0.0) * clamp01(de + 0.5)
    # corner studs
    for cx, cy in ((4, 4), (n - 4, 4), (4, n - 4), (n - 4, n - 4)):
        dd = np.hypot(x - cx, y - cy)
        stud = clamp01(3.0 - dd)
        rgb = mix(rgb, np.array([0.88, 0.74, 0.45]), (stud * 0.9))
        alpha = np.maximum(alpha, stud)
    img = np.zeros((n, n, 4))
    img[..., 0:3] = clamp01(rgb)
    img[..., 3] = alpha
    write_tga("frame9.tga", img)


def slot_frame(n=64):
    """Icon frame: dark outline, steel bevel, dark inner line, soft vignette. Icons sit inside it."""
    k = n / 44.0                       # texture px per slot px
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    x += 0.5
    y += 0.5
    d = np.stack([y, n - y, x, n - x])
    de = d.min(axis=0) / k             # distance inside, in slot px
    which = d.argmin(axis=0)
    nrm = np.array([[0, -1], [0, 1], [-1, 0], [1, 0]])
    L = np.array([-0.35, -0.94])
    L = L / np.linalg.norm(L)
    light = clamp01(0.5 + 0.5 * (nrm[which, 0] * L[0] + nrm[which, 1] * L[1]))
    steel = np.stack([np.full((n, n), 0.66), np.full((n, n), 0.66), np.full((n, n), 0.69)], axis=-1) * (0.30 + 0.75 * light)[..., None]
    rgb = np.zeros((n, n, 3))
    alpha = np.zeros((n, n))
    outer = de < 1.0
    ring = (de >= 1.0) & (de < 3.6)
    inner = (de >= 3.6) & (de < 4.6)
    vign = (de >= 4.6) & (de < 9.0)
    rgb[outer] = 0.015
    alpha[outer] = 1.0
    rgb[ring] = steel[ring]
    alpha[ring] = 1.0
    rgb[inner] = 0.02
    alpha[inner] = 0.9
    alpha[vign] = 0.34 * (1.0 - (de[vign] - 4.6) / 4.4)
    img = np.zeros((n, n, 4))
    img[..., 0:3] = clamp01(rgb)
    img[..., 3] = alpha
    write_tga("slot.tga", img)


def mask_square(n=128):
    img = np.ones((n, n, 4))
    write_tga("mm_mask.tga", img)


SS = 8


def _cell():
    return Image.new("RGBA", (32 * SS, 32 * SS), (0, 0, 0, 0))


def _rgb(c, a=255):
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), a)


def _s(pts):
    return [(px * SS, py * SS) for px, py in pts]


def icon_chest():
    im = _cell()
    d = ImageDraw.Draw(im)
    out = _rgb((0.05, 0.03, 0.02))
    d.rounded_rectangle([5 * SS, 14 * SS, 27 * SS, 26 * SS], radius=2 * SS, fill=_rgb((0.50, 0.30, 0.11)), outline=out, width=SS)
    d.pieslice([5 * SS, 4 * SS, 27 * SS, 24 * SS], 180, 360, fill=_rgb((0.62, 0.38, 0.14)), outline=out, width=SS)
    d.rectangle([5 * SS, 14 * SS, 27 * SS, 16.5 * SS], fill=_rgb((0.86, 0.70, 0.32)))
    d.rectangle([14 * SS, 6 * SS, 18 * SS, 26 * SS], fill=_rgb((0.86, 0.70, 0.32)), outline=out, width=SS // 2)
    d.rectangle([15 * SS, 16 * SS, 17 * SS, 20 * SS], fill=_rgb((0.25, 0.16, 0.06)))
    return im


def _skull(d, cx, cy, s, bone, dark):
    d.ellipse([(cx - 7 * s) * SS, (cy - 8 * s) * SS, (cx + 7 * s) * SS, (cy + 5 * s) * SS], fill=bone)
    d.rounded_rectangle([(cx - 4 * s) * SS, (cy + 2 * s) * SS, (cx + 4 * s) * SS, (cy + 9 * s) * SS], radius=SS, fill=bone)
    d.ellipse([(cx - 5 * s) * SS, (cy - 4 * s) * SS, (cx - 1 * s) * SS, (cy + 1 * s) * SS], fill=dark)
    d.ellipse([(cx + 1 * s) * SS, (cy - 4 * s) * SS, (cx + 5 * s) * SS, (cy + 1 * s) * SS], fill=dark)
    d.polygon(_s([(cx - 1 * s, cy + 2 * s), (cx + 1 * s, cy + 2 * s), (cx, cy + 0.2 * s)]), fill=dark)
    for k in (-2, 0, 2):
        d.line([(cx + k * s) * SS, (cy + 5.5 * s) * SS, (cx + k * s) * SS, (cy + 8.5 * s) * SS], fill=dark, width=max(1, SS // 3))


def icon_guardian(awake):
    im = _cell()
    d = ImageDraw.Draw(im)
    if awake:
        d.ellipse([1 * SS, 1 * SS, 31 * SS, 31 * SS], fill=_rgb((1.0, 0.45, 0.10), 110))
    body = (0.95, 0.15, 0.10) if awake else (0.62, 0.10, 0.10)
    d.ellipse([3.5 * SS, 3.5 * SS, 28.5 * SS, 28.5 * SS], fill=_rgb(body), outline=_rgb((0.90, 0.74, 0.40)), width=int(1.6 * SS))
    _skull(d, 16, 15.5, 0.95, _rgb((0.96, 0.94, 0.88)), _rgb((0.12, 0.03, 0.03)))
    return im


def icon_lair_empty():
    im = _cell()
    d = ImageDraw.Draw(im)
    d.ellipse([4 * SS, 4 * SS, 28 * SS, 28 * SS], fill=_rgb((0.18, 0.18, 0.20), 200), outline=_rgb((0.62, 0.62, 0.66)), width=int(1.6 * SS))
    _skull(d, 16, 15.5, 0.8, _rgb((0.50, 0.50, 0.52)), _rgb((0.08, 0.08, 0.09)))
    return im


def icon_downed():
    im = _cell()
    d = ImageDraw.Draw(im)
    d.ellipse([3.5 * SS, 3.5 * SS, 28.5 * SS, 28.5 * SS], fill=_rgb((0.16, 0.62, 0.22)), outline=_rgb((0.95, 0.95, 0.95)), width=int(1.6 * SS))
    d.rectangle([13.5 * SS, 8 * SS, 18.5 * SS, 24 * SS], fill=_rgb((1, 1, 1)))
    d.rectangle([8 * SS, 13.5 * SS, 24 * SS, 18.5 * SS], fill=_rgb((1, 1, 1)))
    return im


def mm_icons():
    sheet = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cells = [icon_chest(), icon_guardian(False), icon_guardian(True), icon_lair_empty(), icon_downed()]
    for i, c in enumerate(cells):
        sheet.paste(c.resize((32, 32), Image.LANCZOS), ((i % 4) * 32, (i // 4) * 32))
    save_img("mm_icons.tga", sheet)


def save_img(name, im):
    a = np.asarray(im.convert("RGBA")).astype(np.float64) / 255.0
    write_tga(name, a)


def arrows():
    """32 rotations of a white arrow (tinted in game), 8 x 4 cells of 64 px, counter-clockwise from up."""
    S2 = 256
    base = Image.new("RGBA", (S2, S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    k = S2 / 64.0
    tip, wl, wr, notch = (32, 8), (13, 55), (51, 55), (32, 45)
    cx, cy = 32, 32

    def grow(p, f):
        return (cx + (p[0] - cx) * f, cy + (p[1] - 31.5) * f + 0)

    outline = [grow(p, 1.12) for p in (tip, wr, notch, wl)]
    d.polygon([(px * k, py * k) for px, py in outline], fill=(18, 14, 10, 255))
    d.polygon([(px * k, py * k) for px, py in (tip, wl, notch)], fill=(255, 255, 255, 255))
    d.polygon([(px * k, py * k) for px, py in (tip, wr, notch)], fill=(186, 186, 192, 255))
    sheet = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    for i in range(32):
        r = base.rotate(i * 11.25, resample=Image.BICUBIC, center=(S2 / 2, S2 / 2))
        sheet.paste(r.resize((64, 64), Image.LANCZOS), ((i % 8) * 64, (i // 8) * 64))
    save_img("arrows.tga", sheet)


def mm_button():
    S2 = 256
    im = Image.new("RGBA", (S2, S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 4, S2 - 4, S2 - 4], fill=(10, 8, 6, 255))
    d.ellipse([10, 10, S2 - 10, S2 - 10], fill=(190, 188, 196, 255))
    d.ellipse([22, 22, S2 - 22, S2 - 22], fill=(70, 68, 74, 255))
    d.ellipse([30, 30, S2 - 30, S2 - 30], fill=(14, 14, 22, 255))
    d.ellipse([30, 30, S2 - 30, S2 - 30], outline=(214, 176, 100, 255), width=6)
    c = S2 / 2
    star = []
    for k in range(8):
        a = math.radians(k * 45 - 90)
        rr = 78 if k % 2 == 0 else 28
        star.append((c + rr * math.cos(a), c + rr * math.sin(a)))
    d.polygon(star, fill=(232, 196, 112, 255), outline=(60, 40, 12, 255))
    d.ellipse([c - 16, c - 16, c + 16, c + 16], fill=(190, 24, 20, 255), outline=(60, 10, 8, 255), width=4)
    save_img("mm_button.tga", im.resize((64, 64), Image.LANCZOS))


# ---------------------------------------------------------------- Turn 5: XP arcs and the bar's smoke
R_IN, R_OUT, A0, A1 = 64.0, 72.0, 15.0, 58.0     # ring radii (px from the orb's centre) and angles from straight up


def _block(arr, f):
    """premultiplied box downsample of an RGBA float array by factor f"""
    h, w, _ = arr.shape
    pm = arr.copy()
    pm[..., :3] *= pm[..., 3:4]
    pm = pm.reshape(h // f, f, w // f, f, 4).mean(axis=(1, 3))
    a = pm[..., 3:4]
    out = pm.copy()
    out[..., :3] = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 0)
    return out


def xp_arc(name, kind):
    """left experience arc on a 64 x 64 canvas covering x -72..-8, y 32..96 (centre-up) of the orb"""
    n, f = 64, 8
    N = n * f
    ys, xs = np.mgrid[0:N, 0:N]
    u = (xs + 0.5) / f
    v = (ys + 0.5) / f
    x = u - 72.0
    y = 96.0 - v
    r = np.hypot(x, y)
    ang = np.degrees(np.arctan2(-x, y))
    img = np.zeros((N, N, 4), dtype=np.float64)

    def band(grow):
        da = np.degrees(grow / ((R_IN + R_OUT) / 2))
        return (r >= R_IN - grow) & (r <= R_OUT + grow) & (ang >= A0 - da) & (ang <= A1 + da)

    outer = band(0.0)
    inner = band(-1.3)
    t = clamp01((r - R_IN) / (R_OUT - R_IN))
    if kind == "track":
        img[outer] = (0.56, 0.47, 0.27, 0.95)
        base = np.stack([0.07 + 0.05 * t, 0.06 + 0.045 * t, 0.045 + 0.03 * t, np.full_like(t, 0.90)], axis=-1)
        img[inner] = base[inner]
    else:
        lo = np.array([0.84, 0.58, 0.06])
        hi = np.array([1.00, 0.90, 0.36])
        col = lo[None, None, :] * (1 - t[..., None]) + hi[None, None, :] * t[..., None]
        shine = np.exp(-((t - 0.78) / 0.10) ** 2)[..., None] * 0.22
        col = np.minimum(col + shine, 1.0)
        img[inner, :3] = col[inner]
        img[inner, 3] = 1.0
    # transparent pixels carry the band colour, so the downsample leaves no dark fringe
    img[~outer if kind == "track" else ~inner, :3] = img[outer if kind == "track" else inner][:, :3].mean(axis=0)
    write_tga(name, _block(img, f))
    return (72.0 - R_OUT * math.sin(math.radians(A1)), 72.0 - R_IN * math.sin(math.radians(A0)))


def _noise(h, w, cells, rng):
    g = rng.random((cells[1] + 1, cells[0] + 1))
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, dtype=np.float64) / 255.0


def smoke(name="smoke.tga", w=256, h=64):
    """a soft, smoky dark plate for behind the skill slots (own art: noise-eroded rounded rectangle)"""
    rng = np.random.default_rng(7)
    ys, xs = np.mgrid[0:h, 0:w]
    px = xs - w / 2 + 0.5
    py = ys - h / 2 + 0.5
    bx, by, rad = w / 2 - 26, h / 2 - 17, 14.0
    qx = np.abs(px) - bx + rad
    qy = np.abs(py) - by + rad
    sdf = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rad
    n = 0.55 * _noise(h, w, (10, 3), rng) + 0.3 * _noise(h, w, (24, 7), rng) + 0.15 * _noise(h, w, (60, 16), rng)
    sdf = sdf + (n - 0.5) * 30.0
    a = 1.0 - sstep(-16.0, 7.0, sdf)
    mott = 0.80 + 0.20 * _noise(h, w, (16, 4), rng)
    a = a * mott * 0.80
    img = np.zeros((h, w, 4))
    img[..., 0], img[..., 1], img[..., 2] = 0.02, 0.02, 0.03
    img[..., 3] = a
    write_tga(name, img)



# ---------------------------------------------------------------- Turn 5: boss list icons and the gold timer bar
from PIL import ImageFilter


def _shape_with_outline(mask_img, out_px, size):
    """white shape (L mask at SS scale) with a dark outline -> RGBA image at SS scale"""
    k = int(out_px * 2 + 1) | 1
    grown = mask_img.filter(ImageFilter.MaxFilter(k))
    im = Image.new("RGBA", mask_img.size, (0, 0, 0, 0))
    dark = Image.new("RGBA", mask_img.size, (14, 10, 10, 255))
    im.paste(dark, (0, 0), grown)
    white = Image.new("RGBA", mask_img.size, (255, 255, 255, 255))
    im.paste(white, (0, 0), mask_img)
    return im


def _horn(d, side, fill):
    # a curved horn: quadratic bezier from the temple out and up, tapering to a point
    p0, p1, p2 = (21.0, 27.0), (3.0, 31.0), (4.0, 8.0)
    left, right = [], []
    N = 28
    for i in range(N + 1):
        t = i / N
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        dx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
        dy = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        w = (10.5 * (1 - t) + 0.8) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    pts = left + right[::-1]
    if side > 0:
        pts = [(64 - x, y) for (x, y) in pts]
    d.polygon([(x * SS, y * SS) for (x, y) in pts], fill=fill)


def bar_icons(name="bar_icons.tga"):
    """128 x 128 sheet, drawn at twice the size they are shown at (white with a dark outline, tinted in game):
    (0,0) 64 px horned skull for the header (shown 32), (64,0) 48 px skull for the rows (shown 24),
    (0,64) 32 px crown (shown 16), (64,64) 32 px skull for the small list (shown 16)"""
    sheet = Image.new("RGBA", (128 * SS, 128 * SS), (0, 0, 0, 0))
    # --- skull
    m = Image.new("L", (64 * SS, 64 * SS), 0)
    d = ImageDraw.Draw(m)
    _horn(d, -1, 255)
    _horn(d, 1, 255)
    d.ellipse([16 * SS, 14 * SS, 48 * SS, 42 * SS], fill=255)                      # cranium
    d.rounded_rectangle([22 * SS, 34 * SS, 42 * SS, 50 * SS], radius=4 * SS, fill=255)   # jaw
    # features cut out of the shape
    f = Image.new("L", (64 * SS, 64 * SS), 0)
    g = ImageDraw.Draw(f)
    g.polygon([(20 * SS, 28 * SS), (30 * SS, 30 * SS), (29 * SS, 37 * SS), (21 * SS, 36 * SS)], fill=255)   # eyes
    g.polygon([(44 * SS, 28 * SS), (34 * SS, 30 * SS), (35 * SS, 37 * SS), (43 * SS, 36 * SS)], fill=255)
    g.polygon([(32 * SS, 38 * SS), (29.5 * SS, 43 * SS), (34.5 * SS, 43 * SS)], fill=255)                  # nose
    for x in (26, 29.5, 33, 36.5):
        g.rectangle([x * SS, 46 * SS, (x + 1.2) * SS, 50 * SS], fill=255)                                      # teeth gaps
    arr = np.asarray(m, dtype=np.float64) / 255.0
    arr = arr * (1 - np.asarray(f, dtype=np.float64) / 255.0)
    skull = _shape_with_outline(Image.fromarray((arr * 255).astype(np.uint8)), 2.0 * SS / 4, SS)
    # the cut-out features are dark, not clear: paint them in
    dark = Image.new("RGBA", skull.size, (14, 10, 10, 255))
    skull.paste(dark, (0, 0), f)
    skulls = skull
    # --- crown
    m2 = Image.new("L", (64 * SS, 64 * SS), 0)
    d2 = ImageDraw.Draw(m2)
    pts = [(8, 50), (8, 24), (20, 36), (32, 18), (44, 36), (56, 24), (56, 50)]
    d2.polygon([(x * SS, y * SS) for (x, y) in pts], fill=255)
    for (cx, cy) in ((8, 22), (32, 16), (56, 22)):
        d2.ellipse([(cx - 4) * SS, (cy - 4) * SS, (cx + 4) * SS, (cy + 4) * SS], fill=255)
    crown = _shape_with_outline(m2, 2.0 * SS / 4, SS)
    dd = ImageDraw.Draw(crown)
    dd.rectangle([8 * SS, 44 * SS, 56 * SS, 45.6 * SS], fill=(14, 10, 10, 255))     # band line
    def put(img, px, x, y):
        sheet.alpha_composite(img.resize((px * SS, px * SS), Image.LANCZOS), (x * SS, y * SS))
    put(skulls, 64, 0, 0)
    put(skulls, 48, 64, 0)
    put(crown, 32, 0, 64)
    put(skulls, 32, 64, 64)
    arr = np.asarray(sheet, dtype=np.float64) / 255.0
    write_tga(name, _block(arr, SS))


def bar_gold(name="bar_gold.tga", w=128, h=16):
    """a mottled gold-to-orange streak texture for the timer bar of a boss row (own art)"""
    rng = np.random.default_rng(11)
    n = 0.5 * _noise(h, w, (6, 2), rng) + 0.3 * _noise(h, w, (18, 4), rng) + 0.2 * _noise(h, w, (48, 8), rng)
    x = np.linspace(0, 1, w)[None, :]
    base = 0.55 + 0.35 * np.sin(x * math.pi * 1.5 + 0.4) * 0.5
    t = clamp01(base * 0.5 + n * 0.8)
    lo = np.array([0.78, 0.38, 0.04])
    hi = np.array([1.00, 0.82, 0.22])
    col = lo[None, None, :] * (1 - t[..., None]) + hi[None, None, :] * t[..., None]
    yy = np.linspace(0, 1, h)[:, None, None]
    col = col * (0.78 + 0.32 * (1 - np.abs(yy - 0.35) * 1.4))
    img = np.concatenate([np.clip(col, 0, 1), np.ones((h, w, 1))], axis=-1)
    write_tga(name, img)



# ---------------------------------------------------------------- the red blot behind big (critical) numbers
def splat(name="splat.tga"):
    """two 64 x 64 round red blots side by side (128 x 64): a soft round body with a rough edge, a few short
    bulges and some droplets. The blot is about 60% of a cell wide. Own drawing."""
    rng = np.random.default_rng(31)
    SSs = 8
    cell = 64 * SSs
    sheet = Image.new("RGBA", (128 * SSs, cell), (0, 0, 0, 0))
    for v in range(2):
        cx = cy = cell / 2
        R0 = cell * 0.27
        lobes = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.04, 0.09), k) for k in (2, 3, 5, 7)]
        bulges = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.16, 0.34), rng.uniform(0.12, 0.22)) for _ in range(5 + v)]
        pts = []
        N = 480
        for i in range(N):
            th = 2 * math.pi * i / N
            r = 1.0 + sum(a_ * math.sin(k * th + ph) for (ph, a_, k) in lobes)
            for (ta, L, w) in bulges:
                dth = (th - ta + math.pi) % (2 * math.pi) - math.pi
                r += L * math.exp(-(dth / w) ** 2)
            pts.append((cx + R0 * r * math.cos(th), cy + R0 * r * math.sin(th)))
        m = Image.new("L", (cell, cell), 0)
        d = ImageDraw.Draw(m)
        d.polygon(pts, fill=255)
        for _ in range(4):
            ta = rng.uniform(0, 2 * math.pi)
            dist = R0 * rng.uniform(1.35, 1.7)
            rr = R0 * rng.uniform(0.05, 0.10)
            x = cx + dist * math.cos(ta)
            y = cy + dist * math.sin(ta)
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(0.7 * SSs / 2))
        a = np.asarray(m, dtype=np.float64) / 255.0
        yy, xx = np.mgrid[0:cell, 0:cell]
        rad = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (R0 * 1.3)
        t = np.clip(rad, 0, 1)
        col = np.zeros((cell, cell, 4))
        col[..., 0] = 0.80 - 0.22 * t
        col[..., 1] = 0.08 - 0.05 * t
        col[..., 2] = 0.07 - 0.04 * t
        col[..., 3] = a * 0.93
        tile = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGBA")
        sheet.alpha_composite(tile, (v * cell, 0))
    arr = np.asarray(sheet, dtype=np.float64) / 255.0
    write_tga(name, _block(arr, SSs))


# ---------------------------------------------------------------- pictograms for the character panel's attributes
def stat_icons(name="stat_icons.tga"):
    """256 x 128 sheet, 8 x 4 cells of 32 px (shown at 16 px), white pictograms, tinted in game:
    0 sword, 1 crosshair, 2 burst, 3 clock, 4 chevrons, 5 rings, 6 cluster, 7 waves, 8 heart, 9 shield, 10 plus,
    11 drop, 12 thorns, 13 plus in ring, 14 hollow heart, 15 magnet, 16 star, 17 clover, 18 coin, 19 diamond"""
    S = 8
    C = 32 * S
    sheet = Image.new("L", (8 * C, 4 * C), 0)

    def cell(idx, fn):
        m = Image.new("L", (C, C), 0)
        d = ImageDraw.Draw(m)

        def P(pts):
            return [(x * S, y * S) for x, y in pts]

        def line(a, b, w, fill=255):
            d.line(P([a, b]), fill=fill, width=int(w * S))
            for (x, y) in (a, b):
                d.ellipse([(x - w / 2) * S, (y - w / 2) * S, (x + w / 2) * S, (y + w / 2) * S], fill=fill)

        def circ(cx, cy, r, fill=255):
            d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=fill)

        def ring(cx, cy, r, w):
            circ(cx, cy, r)
            circ(cx, cy, r - w, 0)

        def poly(pts, fill=255):
            d.polygon(P(pts), fill=fill)

        fn(d, line, circ, ring, poly)
        sheet.paste(m, ((idx % 8) * C, (idx // 8) * C))

    def heart(d, line, circ, ring, poly, fill=255, k=1.0, cy=0.0):
        def X(x):
            return 16 + (x - 16) * k
        def Y(y):
            return 17 + (y - 17) * k + cy
        circ(X(11), Y(12), 6.5 * k, fill)
        circ(X(21), Y(12), 6.5 * k, fill)
        poly([(X(4.9), Y(14.6)), (X(27.1), Y(14.6)), (X(16), Y(27.5))], fill)

    def sword(d, line, circ, ring, poly):
        line((12, 20), (25, 7), 3.4)
        poly([(24, 4), (28, 8), (27.5, 4.5)])
        line((8, 15), (17, 24), 2.8)
        line((9.5, 22.5), (5.5, 26.5), 3.0)
        circ(5, 27, 2.0)

    def crosshair(d, line, circ, ring, poly):
        ring(16, 16, 9.5, 2.4)
        line((16, 2), (16, 9), 2.4); line((16, 23), (16, 30), 2.4)
        line((2, 16), (9, 16), 2.4); line((23, 16), (30, 16), 2.4)
        circ(16, 16, 2.2)

    def burst(d, line, circ, ring, poly):
        pts = []
        for k in range(16):
            r = 13.5 if k % 2 == 0 else 6.0
            a = math.pi * k / 8 - math.pi / 2
            pts.append((16 + r * math.cos(a), 16 + r * math.sin(a)))
        poly(pts)

    def clock(d, line, circ, ring, poly):
        ring(16, 16, 12, 2.6)
        line((16, 16), (16, 8), 2.4)
        line((16, 16), (21.5, 19), 2.4)

    def chevrons(d, line, circ, ring, poly):
        for dx in (0, 9):
            line((6 + dx, 7), (14 + dx, 16), 3.2)
            line((14 + dx, 16), (6 + dx, 25), 3.2)

    def rings(d, line, circ, ring, poly):
        ring(16, 16, 13, 2.4)
        ring(16, 16, 7, 2.4)
        circ(16, 16, 2.0)

    def cluster(d, line, circ, ring, poly):
        circ(9.5, 21, 4.8); circ(22.5, 21, 4.8); circ(16, 9.5, 4.8)

    def waves(d, line, circ, ring, poly):
        for r in (6, 11.5, 17):
            m2 = Image.new("L", (C, C), 0)
            d2 = ImageDraw.Draw(m2)
            d2.ellipse([(6 - r) * S, (16 - r) * S, (6 + r) * S, (16 + r) * S], fill=255)
            d2.ellipse([(6 - r + 2.6) * S, (16 - r + 2.6) * S, (6 + r - 2.6) * S, (16 + r - 2.6) * S], fill=0)
            # keep the right-hand arc only
            keep = Image.new("L", (C, C), 0)
            ImageDraw.Draw(keep).pieslice([(6 - r - 2) * S, (16 - r - 2) * S, (6 + r + 2) * S, (16 + r + 2) * S], -55, 55, fill=255)
            arr = np.minimum(np.asarray(m2), np.asarray(keep))
            d.bitmap((0, 0), Image.fromarray(arr), fill=255)
        circ(6, 16, 2.4)

    def heart_(d, line, circ, ring, poly):
        heart(d, line, circ, ring, poly)

    def shield(d, line, circ, ring, poly):
        poly([(5, 5), (16, 2), (27, 5), (27, 16), (16, 29), (5, 16)])
        line((16, 7), (16, 24), 1.8, 0)
        line((8, 12), (24, 12), 1.8, 0)

    def plus(d, line, circ, ring, poly):
        d.rounded_rectangle([12.5 * S, 4 * S, 19.5 * S, 28 * S], radius=2 * S, fill=255)
        d.rounded_rectangle([4 * S, 12.5 * S, 28 * S, 19.5 * S], radius=2 * S, fill=255)

    def drop(d, line, circ, ring, poly):
        circ(16, 19, 9)
        poly([(16, 2.5), (8.3, 16.5), (23.7, 16.5)])

    def thorns(d, line, circ, ring, poly):
        poly([(3, 28), (7, 11), (11.5, 22), (16, 4), (20.5, 22), (25, 11), (29, 28)])

    def plusring(d, line, circ, ring, poly):
        ring(16, 16, 12.5, 2.4)
        d.rectangle([14.3 * S, 8.5 * S, 17.7 * S, 23.5 * S], fill=255)
        d.rectangle([8.5 * S, 14.3 * S, 23.5 * S, 17.7 * S], fill=255)

    def hollow(d, line, circ, ring, poly):
        heart(d, line, circ, ring, poly)
        heart(d, line, circ, ring, poly, fill=0, k=0.5, cy=1.4)

    def magnet(d, line, circ, ring, poly):
        d.pieslice([5 * S, 8 * S, 27 * S, 30 * S], 0, 180, fill=255)
        d.pieslice([11.5 * S, 14.5 * S, 20.5 * S, 23.5 * S], 0, 180, fill=0)
        d.rectangle([5 * S, 4 * S, 11.5 * S, 19 * S], fill=255)
        d.rectangle([20.5 * S, 4 * S, 27 * S, 19 * S], fill=255)
        d.rectangle([5 * S, 4 * S, 11.5 * S, 8.5 * S], fill=0)
        d.rectangle([20.5 * S, 4 * S, 27 * S, 8.5 * S], fill=0)

    def star(d, line, circ, ring, poly):
        pts = []
        for k in range(10):
            r = 13.5 if k % 2 == 0 else 5.6
            a = math.pi * k / 5 - math.pi / 2
            pts.append((16 + r * math.cos(a), 16.6 + r * math.sin(a)))
        poly(pts)

    def clover(d, line, circ, ring, poly):
        for (x, y) in ((16, 9), (16, 21), (9, 15), (23, 15)):
            circ(x, y, 5.6)
        line((16, 17), (22, 29), 2.2)

    def coin(d, line, circ, ring, poly):
        circ(16, 16, 13)
        ring(16, 16, 9.2, 1.8) if False else None
        circ(16, 16, 9.6, 0)
        circ(16, 16, 8.0)
        d.rectangle([14.6 * S, 10 * S, 17.4 * S, 22 * S], fill=0)

    def diamond(d, line, circ, ring, poly):
        poly([(16, 3), (29, 16), (16, 29), (3, 16)])
        poly([(16, 9), (23, 16), (16, 23), (9, 16)], 0)

    fns = [sword, crosshair, burst, clock, chevrons, rings, cluster, waves, heart_, shield, plus, drop, thorns,
           plusring, hollow, magnet, star, clover, coin, diamond]
    for i, fn in enumerate(fns):
        cell(i, fn)
    a = np.asarray(sheet, dtype=np.float64) / 255.0
    rgba = np.zeros(a.shape + (4,))
    rgba[..., 0:3] = 1.0
    rgba[..., 3] = a
    write_tga(name, _block(rgba, S))


# ---------------------------------------------------------------- 1.8.1: nameplate / target bar fill
def plate_fill(name="plate_fill.tga", w=64, h=32):
    """the fill of the nameplates and of the target bar (own art): a lit, slightly rounded bar in grey that is tinted
    in game. A bright line under the top edge, a body that darkens towards the bottom, a faint diagonal sheen along the
    length and a dark line at the very bottom."""
    rng = np.random.default_rng(23)
    y = (np.arange(h) + 0.5) / h
    x = (np.arange(w) + 0.5) / w
    X, Y = np.meshgrid(x, y)
    lum = 0.90 - 0.46 * Y
    lum += 0.22 * np.exp(-(((Y - 0.16) / 0.09) ** 2))
    lum += 0.06 * np.sin((X * 2.0 + Y * 0.8) * math.pi)
    lum += (_noise(h, w, (12, 4), rng) - 0.5) * 0.07
    lum[0, :] += 0.20
    lum[h - 3:, :] *= 0.62
    rgba = np.ones((h, w, 4))
    rgba[..., 0:3] = clamp01(lum)[..., None]
    write_tga(name, rgba)


orb_fill()
orb_gloss()
orb_rim()
bar_gloss()
band()
frame9()
mask_square()
mm_icons()
arrows()
mm_button()
print("arc u range", xp_arc("xp_track.tga", "track"), xp_arc("xp_fill.tga", "fill"))
smoke()
bar_icons()
bar_gold()
splat()
stat_icons()
plate_fill()
