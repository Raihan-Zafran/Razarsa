#!/usr/bin/env python3
"""Menyiapkan aset profil dari PNG mentah (latar putih) menjadi WebP kecil bertransparansi.

Pemakaian:  python3 -I tools/prepare_profile_assets.py <folder_png_mentah> [folder_keluaran]
Keluaran bawaan: assets/profile/{avatars,frames,badges,covers}.
PNG mentah tidak ikut repo (±1,3 MB per file); jalankan ulang skrip ini bila aset diganti.
"""
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

# nama berkas mentah -> (jenis, id)
MAP = {
    'Cute Green Dragon Mascot with Wings.png': ('avatars', 'a1'),
    'Chibi Dragon Holding a Leaf.png': ('avatars', 'a2'),
    'Chibi Green Dragon with Glasses.png': ('avatars', 'a3'),
    'Chibi Green Dragon Wizard Mascot.png': ('avatars', 'a4'),
    'Happy Dragon Holding a Shiny Gold Coin.png': ('avatars', 'a5'),
    'Sleeping Green Dragon with Floating Zzz.png': ('avatars', 'a6'),
    'Surprised Mint Dragon Mascot.png': ('avatars', 'a7'),
    'Winking Chibi Green Dragon Sticker.png': ('avatars', 'a8'),
    'Cartoon Vine Wreath with Green Leaves.png': ('frames', 'f1'),
    'Glossy Golden Ring with Sparkles.png': ('frames', 'f2'),
    'Blazing Circular Flame Ring.png': ('frames', 'f3'),
    'Royal Purple Jeweled Ornament Frame.png': ('frames', 'f4'),
    'Mint Green Star Badge.png': ('badges', 'b01'),
    'Mint Flame Shield Badge.png': ('badges', 'b02'),
    'Golden Piggy Bank Shield.png': ('badges', 'b03'),
    'Golden Trophy Checklist Shield.png': ('badges', 'b04'),
    'Golden Fountain Pen Shield Badge.png': ('badges', 'b05'),
    'Golden Star Medal Badge.png': ('badges', 'b06'),
    'Notebook and Golden Star Coin Shield.png': ('badges', 'b07'),
    'Gold-Rimmed Mint Calendar Badge.png': ('badges', 'b08'),
    'Mint Leaf Calendar Shield.png': ('badges', 'b09'),
    'Golden Star Shield Badge.png': ('badges', 'b10'),
    'Golden Crown Shield Badge.png': ('badges', 'b11'),
    'Mint Badge with Golden Star.png': ('badges', 'b12'),
    'Pastel Desert Dunes Under a Mint Sky.png': ('covers', 'desert_day'),
    'Moonlit Lavender Desert Dunes.png': ('covers', 'desert_night'),
}
SIZE = {'avatars': 512, 'frames': 512, 'badges': 256}
GRAY_SAT = 14  # selisih kanal maksimum untuk dianggap abu-abu/putih


def background_mask(rgb, seeds):
    """Piksel abu-abu/putih yang terhubung ke [seeds] (latar + bayangan lembut)."""
    mx = rgb.max(axis=2).astype(int)
    mn = rgb.min(axis=2).astype(int)
    grayish = ((mx - mn) <= GRAY_SAT) & (mn >= 90)
    h, w = grayish.shape
    seen = np.zeros_like(grayish)
    q = deque()
    for (x, y) in seeds:
        if grayish[y, x] and not seen[y, x]:
            seen[y, x] = True
            q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and grayish[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((nx, ny))
    return seen


def cut_out(im, kind):
    rgb = np.array(im.convert('RGB'))
    h, w, _ = rgb.shape
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    if kind == 'frames':
        seeds.append((w // 2, h // 2))  # bagian dalam bingkai ikut transparan
    bg = background_mask(rgb, seeds)
    lum = rgb.mean(axis=2)
    # Latar putih -> transparan penuh; bayangan abu-abu -> hitam translusen (setia pada aslinya).
    alpha = np.where(bg, np.clip(255 - lum, 0, 255), 255).astype(np.uint8)
    alpha[bg & (lum >= 244)] = 0
    out = rgb.copy()
    out[bg] = 0
    return Image.fromarray(np.dstack([out, alpha]), 'RGBA')


def crop_square(im, pad=0.03):
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 12)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    side = int(max(x1 - x0, y1 - y0) * (1 + pad * 2)) + 2
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(im, (-box[0], -box[1]))
    return canvas


def hole_ratio(frame):
    """Diameter lubang bingkai (terbesar, di pusat) dibanding lebar bingkai."""
    a = np.array(frame)[:, :, 3]
    h, w = a.shape
    cy = h // 2
    row = a[cy]
    # dari pusat ke kiri/kanan sampai ketemu piksel bingkai
    x = w // 2
    l = x
    while l > 0 and row[l] < 40:
        l -= 1
    r = x
    while r < w - 1 and row[r] < 40:
        r += 1
    return round((r - l) / w, 3)


def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', 'assets', 'profile')
    meta = {}
    total = 0
    for fname, (kind, ident) in MAP.items():
        path = os.path.join(src, fname)
        if not os.path.exists(path):
            print('TIDAK ADA:', fname)
            continue
        im = Image.open(path)
        os.makedirs(os.path.join(dst, kind), exist_ok=True)
        out_path = os.path.join(dst, kind, f'{ident}.webp')
        if kind == 'covers':
            out = im.convert('RGB').resize((1200, 400), Image.LANCZOS)
            out.save(out_path, 'WEBP', quality=82, method=6)
        else:
            cut = crop_square(cut_out(im, kind))
            size = SIZE[kind]
            cut = cut.resize((size, size), Image.LANCZOS)
            if kind == 'frames':
                meta[ident] = {'hole': hole_ratio(cut)}
            cut.save(out_path, 'WEBP', quality=88, alpha_quality=100, method=6)
        sz = os.path.getsize(out_path)
        total += sz
        print(f'{kind:8} {ident:12} {sz/1024:6.1f} KB  <- {fname}')
    print(f'TOTAL {total/1024:.0f} KB')
    with open(os.path.join(dst, 'frames_meta.json'), 'w') as f:
        json.dump(meta, f, indent=2)
    print('frames_meta:', meta)


if __name__ == '__main__':
    main()
