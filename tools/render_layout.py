"""render a layout dump (harness.lua) with the real textures and the shipped font.
usage: render_layout.py layout.txt out.png [x0,y0,x1,y1 (canvas, bottom-left origin)] [scale]"""
import sys, struct, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.environ.get("AZS_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ADDON = os.path.join(ROOT, "AZSGW2UI")          # AZS_ROOT/AZSGW2UI, or AZS_ROOT itself in the repository layout
if not os.path.exists(os.path.join(ADDON, "AZSGW2UI.toc")):
    ADDON = ROOT
TEX = os.path.join(ADDON, "Textures")
FONT = os.path.join(ADDON, "Fonts", "azs_numbers.ttf")
FALLBACK = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

src, dst = sys.argv[1], sys.argv[2]
rows = [l.rstrip("\n").split("|") for l in open(src, encoding="utf-8") if l.strip()]
SW, SH = int(rows[0][1]), int(rows[0][2])
crop = None
scale = 2
if len(sys.argv) > 3 and sys.argv[3] != "-":
    crop = [float(v) for v in sys.argv[3].split(",")]
if len(sys.argv) > 4:
    scale = int(sys.argv[4])
if crop is None:
    crop = [0, 0, SW, SH]
cx0, cy0, cx1, cy1 = crop
W, H = int((cx1 - cx0) * scale), int((cy1 - cy0) * scale)

BG = tuple(int(v) for v in os.environ.get("BG", "34,26,24").split(","))
img = Image.new("RGBA", (W, H), BG + (255,))
_cache = {}


def load_tga(name):
    if name in _cache:
        return _cache[name]
    p = os.path.join(TEX, name)
    if not os.path.exists(p):
        _cache[name] = None
        return None
    d = open(p, "rb").read()
    w, h = struct.unpack("<HH", d[12:16])
    px = np.frombuffer(d[18:18 + w * h * 4], dtype=np.uint8).reshape(h, w, 4)[::-1][:, :, [2, 1, 0, 3]]
    im = Image.fromarray(px.copy(), "RGBA")
    _cache[name] = im
    return im


def px(l, b, w, h):
    """canvas rect (bottom-left origin) -> image box"""
    x0 = (l - cx0) * scale
    y0 = (cy1 - (b + h)) * scale
    return x0, y0, w * scale, h * scale


LAYER = {"BACKGROUND": 0, "BORDER": 1, "ARTWORK": 2, "OVERLAY": 3, "HIGHLIGHT": 4}
xs = []
for r in rows[1:]:
    if r[0] == "X":
        xs.append(r)
xs.sort(key=lambda r: (int(r[9]), LAYER.get(r[8], 2), int(r[10])))

for r in xs:
    _, tex, l, b, w, h, tc, vc, layer, depth, idx = r
    l, b, w, h = float(l), float(b), float(w), float(h)
    if l + w < cx0 or l > cx1 or b + h < cy0 or b > cy1:
        continue
    x0, y0, ww, hh = px(l, b, w, h)
    vc = [float(v) for v in vc.split(",")]
    tcv = [float(v) for v in tc.split(",")]
    iw, ih = max(1, int(round(ww))), max(1, int(round(hh)))
    if tex == "SOLID":
        tile = Image.new("RGBA", (iw, ih), (int(vc[0] * 255), int(vc[1] * 255), int(vc[2] * 255), int(vc[3] * 255)))
    else:
        name = tex.replace("\\", "/").split("/")[-1]
        src_im = load_tga(name)
        if src_im is None and "Icons" in tex:
            # the game's own icon art is not available outside the game: a plain stand-in square, so the layout
            # (where an icon sits, how big it is) can still be judged. Its colour comes from the file name.
            import hashlib
            hc = hashlib.md5(name.encode()).digest()
            base = (70 + hc[0] % 110, 70 + hc[1] % 110, 70 + hc[2] % 110, int(vc[3] * 255))
            tile = Image.new("RGBA", (iw, ih), base)
            dd = ImageDraw.Draw(tile)
            dd.rectangle([0, 0, iw - 1, ih - 1], outline=(15, 15, 15, 255))
            dd.polygon([(0, 0), (iw * 0.55, 0), (0, ih * 0.55)], fill=(255, 255, 255, 40))
            layer_im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            layer_im.paste(tile, (int(round(x0)), int(round(y0))))
            img.alpha_composite(layer_im)
            continue
        if src_im is None:
            continue
        SWd, SHd = src_im.size
        u0, u1, v0, v1 = tcv[0], tcv[1], tcv[2], tcv[3]
        flipx, flipy = u0 > u1, v0 > v1
        a0, a1 = sorted((u0, u1)); c0, c1 = sorted((v0, v1))
        part = src_im.crop((int(round(a0 * SWd)), int(round(c0 * SHd)), int(round(a1 * SWd)), int(round(c1 * SHd))))
        if flipx:
            part = part.transpose(Image.FLIP_LEFT_RIGHT)
        if flipy:
            part = part.transpose(Image.FLIP_TOP_BOTTOM)
        tile = part.resize((iw, ih), Image.BILINEAR if part.size[0] <= iw else Image.LANCZOS)
        arr = np.asarray(tile, dtype=np.float64) / 255.0
        arr[..., 0] *= vc[0]; arr[..., 1] *= vc[1]; arr[..., 2] *= vc[2]; arr[..., 3] *= vc[3]
        tile = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    layer_im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer_im.paste(tile, (int(round(x0)), int(round(y0))))
    img.alpha_composite(layer_im)

d = ImageDraw.Draw(img, "RGBA")
for r in rows[1:]:
    if r[0] != "T":
        continue
    _, text, l, b, w, h, size, just, col, fpath = r[:10]
    flags = r[10] if len(r) > 10 else ""
    l, b, w, h, size = float(l), float(b), float(w), float(h), int(size)
    if l + w < cx0 or l > cx1 or b + h < cy0 or b > cy1:
        continue
    ours = "azs_numbers" in fpath
    fnt = ImageFont.truetype(FONT if ours else FALLBACK, int(size * scale * (1.0 if ours else 0.88)))
    x0, y0, ww, hh = px(l, b, w, h)
    ym = y0 + hh / 2
    c = [int(float(v) * 255) for v in col.split(",")]
    tw = d.textlength(text, font=fnt)
    if just == "CENTER":
        x, anchor = x0 + ww / 2, "mm"
    elif just == "RIGHT":
        x, anchor = x0 + ww, "rm"
    else:
        x, anchor = x0, "lm"
    if ours and flags == "OUTLINE":
        d.text((x, ym), text, fill=tuple(c) + (255,), font=fnt, anchor=anchor, stroke_width=max(1, scale // 2), stroke_fill=(0, 0, 0, 255))
    elif ours:
        d.text((x + scale, ym + scale), text, fill=(0, 0, 0, 235), font=fnt, anchor=anchor)
        d.text((x, ym), text, fill=tuple(c) + (255,), font=fnt, anchor=anchor)
    else:
        d.text((x, ym), text, fill=tuple(c) + (255,), font=fnt, anchor=anchor, stroke_width=max(1, scale // 2), stroke_fill=(0, 0, 0, 255))

img.convert("RGB").save(dst)
print("saved", dst, img.size)
