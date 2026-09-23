#!/usr/bin/env python3
"""Bake LOOK v3 fail-fix sheets from the locked reference crops.

Shots are not touched. Walls in env.png are not touched.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REF = Path("/home/ubuntu/.cursor/projects/workspace/uploads")
SPR = ROOT / "assets" / "sprites"
ENV = ROOT / "assets" / "env"

PAL = np.array(
    [
        (0x0B, 0x0C, 0x10),
        (0x12, 0x08, 0x08),
        (0x28, 0x10, 0x0C),
        (0x3A, 0x14, 0x10),
        (0x4A, 0x14, 0x08),
        (0x7A, 0x1F, 0x1A),
        (0xA2, 0x32, 0x28),
        (0x7A, 0x28, 0x0C),
        (0xA6, 0x3A, 0x10),
        (0xC6, 0x4C, 0x14),
        (0xE2, 0x5A, 0x1A),
        (0xF0, 0x74, 0x30),
        (0xF4, 0x80, 0x3C),
        (0x2A, 0x28, 0x26),
        (0x5C, 0x5A, 0x56),
        (0x8A, 0x86, 0x80),
        (0x9A, 0x8E, 0x78),
        (0xC4, 0xB4, 0x9E),
        (0xE6, 0xD9, 0xC3),
    ],
    dtype=np.int16,
)


def quantize(rgb: np.ndarray) -> np.ndarray:
    flat = rgb.reshape(-1, 3).astype(np.int32)
    pal = PAL.astype(np.int32)
    # int32: a uint8 delta squared overflows int16 and snaps dark reds onto Bone.
    out = np.empty((flat.shape[0], 3), dtype=np.uint8)
    step = 20000
    for i in range(0, flat.shape[0], step):
        sl = flat[i : i + step]
        d = ((sl[:, None, :] - pal[None, :, :]) ** 2).sum(2)
        out[i : i + step] = pal[d.argmin(1)].astype(np.uint8)
    return out.reshape(rgb.shape)


def write_pit() -> None:
    im = Image.open(REF / "pit_A_transparent_1a65.png").convert("RGBA")
    a = np.array(im)
    m = a[:, :, 3] > 20
    ys, xs = np.where(m)
    crop = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    # Keep the painted well, including its dark depth. Outside stays clear.
    crop.save(ENV / "pit.png")
    print("pit", crop.size)


def write_floor() -> None:
    src = np.array(Image.open(REF / "floor_ref_9265.png").convert("RGBA"))
    # Rock panel only — drop the caption band.
    # Skip the mock's grey frame. The rock itself starts inside that gutter.
    rock = src[38:214, 64:500, :3]
    q = quantize(rock)
    img = Image.fromarray(q, "RGB").resize((q.shape[1] // 2, q.shape[0] // 2), Image.Resampling.NEAREST)
    tile = np.array(img)
    env = Image.open(SPR / "env.png").convert("RGBA")
    sheet = np.array(env)
    # Four windows across the cracked field. Walls (cols 4–5) and blank cols stay.
    offsets = (0, 48, 96, 140)
    for col, ox in enumerate(offsets):
        ox = min(ox, tile.shape[1] - 64)
        cell = tile[8 : 8 + 64, ox : ox + 64]
        if cell.shape != (64, 64, 3):
            raise SystemExit(f"floor cell {cell.shape}")
        rgba = np.zeros((64, 64, 4), dtype=np.uint8)
        rgba[:, :, :3] = cell
        rgba[:, :, 3] = 255
        colors = len({tuple(p) for p in cell.reshape(-1, 3)})
        if colors < 5:
            raise SystemExit(f"floor variant {col} still flat ({colors})")
        for row in range(5):
            sheet[row * 64 : (row + 1) * 64, col * 64 : (col + 1) * 64] = rgba
    Image.fromarray(sheet, "RGBA").save(SPR / "env.png")
    print("floor tiles", offsets, "env", sheet.shape)


def write_doors() -> None:
    cell = Image.open(REF / "door_lit_readable_8ac9.png").convert("RGBA")
    if cell.size != (256, 96):
        raise SystemExit(f"door helper {cell.size}")
    locked = np.array(cell)
    open_a = locked.copy()
    # Door face only (y44–83, the Wound slab). Lintel flames sit above y44
    # and the stone jambs / side drips sit outside x78–177.
    open_a[44:84, 78:178, 3] = 0
    clear = int((open_a[:, :, 3] == 0).sum())
    if clear < 4000:
        raise SystemExit(f"open door hole {clear}")
    ember = (locked[:, :, 0] > 160) & (locked[:, :, 0] > locked[:, :, 1] + 40) & (locked[:, :, 3] == 255)
    if int(ember.sum()) < 200:
        raise SystemExit("locked door lost its ember")
    open_ember = (open_a[:, :, 0] > 160) & (open_a[:, :, 0] > open_a[:, :, 1] + 40) & (open_a[:, :, 3] == 255)
    if int(open_ember.sum()) < 200:
        raise SystemExit("open door ate the lintel flames")
    sheet = Image.new("RGBA", (1024, 192), (0, 0, 0, 0))
    locked_im = Image.fromarray(locked, "RGBA")
    open_im = Image.fromarray(open_a, "RGBA")
    for col in range(4):
        sheet.paste(open_im, (col * 256, 0))
        sheet.paste(locked_im, (col * 256, 96))
    sheet.save(SPR / "doors.png")
    print("doors", sheet.size, "open clear", clear)


def _followup():
    import importlib.util

    path = Path(__file__).with_name("bake_followup_f5.py")
    spec = importlib.util.spec_from_file_location("bake_followup_f5", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write_fx() -> None:
    """S / Z / wavy brand / trident, star to broken-C, wisp squash. See bake_followup_f5."""
    _followup().write_fx()


def write_hearts() -> None:
    src = np.array(Image.open(REF / "hearts_sheet_8a20.png").convert("RGBA"))
    bg = (src[:, :, 0] == 11) & (src[:, :, 1] == 12) & (src[:, :, 2] == 16)
    src[bg, 3] = 0
    spans = [(8, 28), (36, 56), (65, 83)]
    sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    for i, (x0, x1) in enumerate(spans):
        glyph = Image.fromarray(src[7:23, x0:x1], "RGBA")
        big = glyph.resize((glyph.size[0] * 3, glyph.size[1] * 3), Image.Resampling.NEAREST)
        cell = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        cell.paste(big, ((64 - big.size[0]) // 2, (64 - big.size[1]) // 2), big)
        sheet.paste(cell, (i * 64, 0), cell)
    # Ember pip (HUD slot, column 3). Asymmetric flame, same inks as the hearts.
    pip = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = pip.load()
    flame = [
        "....E.....",
        "...EEE....",
        "..EEWWEE..",
        "..EWWWWE..",
        ".EEWWWWEE.",
        ".EEWWWWWe.",
        "..EWWWWE..",
        "..EEWWEE..",
        "...EEE....",
        "....E.....",
    ]
    cmap = {
        "E": (0xE2, 0x5A, 0x1A, 255),
        "e": (0xF0, 0x8A, 0x3A, 255),
        "W": (0x7A, 0x1F, 0x1A, 255),
    }
    ox, oy = 16, 14
    for y, row in enumerate(flame):
        for x, ch in enumerate(row):
            if ch in cmap:
                for dy in range(3):
                    for dx in range(3):
                        px[ox + x * 3 + dx, oy + y * 3 + dy] = cmap[ch]
    sheet.paste(pip, (192, 0), pip)
    sheet.save(SPR / "hearts.png")
    print("hearts", sheet.size)


def write_aura() -> None:
    """Horned heart and skull+X. Halo is in the item cell."""
    _followup().write_aura()


def main() -> None:
    write_pit()
    write_floor()
    write_doors()
    write_fx()
    write_hearts()
    write_aura()


if __name__ == "__main__":
    main()
