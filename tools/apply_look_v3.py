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


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(im)
    m = a[:, :, 3] > 16
    if not m.any():
        return im
    ys, xs = np.where(m)
    y0, y1 = max(0, ys.min() - pad), min(a.shape[0], ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(a.shape[1], xs.max() + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def fit(im: Image.Image, size: int, pad: int = 4) -> Image.Image:
    im = trim(im)
    w, h = im.size
    box = size - pad * 2
    scale = box / max(w, h)
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    im = im.resize((nw, nh), Image.Resampling.NEAREST)
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell.paste(im, ((size - nw) // 2, (size - nh) // 2), im)
    return cell


def key_dark(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    rgb = a[:, :, :3].astype(np.int16)
    # The mock field is near-black grey. Dark reds are ink and stay.
    spread = np.maximum(
        np.abs(rgb[:, :, 0] - rgb[:, :, 1]),
        np.abs(rgb[:, :, 1] - rgb[:, :, 2]),
    )
    grey = (spread < 18) & (rgb.max(2) < 52)
    a[grey, 3] = 0
    fg = a[:, :, 3] > 0
    if fg.any():
        q = quantize(a[:, :, :3])
        a[fg, :3] = q[fg]
    return Image.fromarray(a, "RGBA")


def hotten(im: Image.Image) -> Image.Image:
    a = np.array(im)
    fg = a[:, :, 3] > 0
    rgb = a[:, :, :3].astype(np.int16)
    # Step ember-like pixels one shade hotter. Leave bone/ash.
    emberish = fg & (rgb[:, :, 0] > rgb[:, :, 1] + 20) & (rgb[:, :, 0] > 80)
    rgb[emberish, 0] = np.minimum(255, rgb[emberish, 0] + 24)
    rgb[emberish, 1] = np.minimum(180, rgb[emberish, 1] + 16)
    a[:, :, :3] = quantize(rgb.astype(np.uint8))
    a[~fg, 3] = 0
    return Image.fromarray(a, "RGBA")


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


def _fx_crop(box: tuple) -> Image.Image:
    im = Image.open(REF / "boss_fx_ref_322a.png").convert("RGBA").crop(box)
    return key_dark(im)


def write_fx() -> None:
    slam_src = _fx_crop((48, 42, 236, 198))
    beam_src = _fx_crop((300, 28, 430, 198))
    slam = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    beam = Image.new("RGBA", (384, 192), (0, 0, 0, 0))
    for col in range(4):
        ring = slam_src.rotate(col * 18, resample=Image.Resampling.NEAREST, expand=False)
        slam.paste(fit(ring, 128, 2), (col * 128, 0), fit(ring, 128, 2))
        hot = fit(hotten(ring), 128, 2)
        slam.paste(hot, (col * 128, 128), hot)
        # Nudge each frame so the fork reads as animation, not a stamp.
        nudged = Image.new("RGBA", beam_src.size, (0, 0, 0, 0))
        nudged.paste(beam_src, (col, col % 2))
        cell = fit(nudged, 96, 2)
        beam.paste(cell, (col * 96, 0), cell)
        hot = fit(hotten(nudged), 96, 2)
        beam.paste(hot, (col * 96, 96), hot)
    _require_ink(slam, 128, "fx_slam")
    _require_ink(beam, 96, "fx_beam")
    slam.save(SPR / "fx_slam.png")
    beam.save(SPR / "fx_beam.png")

    wisp_src = np.array(Image.open(REF / "fx_wisp_polish_fcb6.png").convert("RGBA"))
    wisp = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    prev = None
    for col in range(4):
        frame = wisp_src[:, col * 32 : (col + 1) * 32].copy()
        bg = (frame[:, :, 0] == 11) & (frame[:, :, 1] == 12) & (frame[:, :, 2] == 16)
        frame[bg, 3] = 0
        im = Image.fromarray(frame, "RGBA")
        # Nearest scale of the locked 4 frames so the plume fills the cell.
        big = fit(im, 64, 4)
        if prev is not None and np.array_equal(np.array(prev), np.array(big)):
            raise SystemExit(f"wisp frame {col} is a duplicate")
        prev = big
        wisp.paste(big, (col * 64, 0), big)
    _require_ink(wisp, 64, "fx_wisp")
    wisp.save(SPR / "fx_wisp.png")
    print("fx", slam.size, beam.size, wisp.size)


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


def _require_ink(sheet: Image.Image, cell: int, name: str) -> None:
    a = np.array(sheet)
    cols = sheet.size[0] // cell
    rows = sheet.size[1] // cell
    for row in range(rows):
        for col in range(cols):
            block = a[row * cell : (row + 1) * cell, col * cell : (col + 1) * cell]
            n = int((block[:, :, 3] > 16).sum())
            if n < 40:
                raise SystemExit(f"{name} cell {col},{row} empty ({n})")


def _ring(px, cx, cy, r0, r1, col) -> None:
    r0s, r1s = r0 * r0, r1 * r1
    for y in range(64):
        for x in range(64):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if r0s <= d <= r1s:
                px[x, y] = col


def _chunk_ring(px, palette: dict) -> None:
    # Stepped octagon, same ink weight as the pickup icons. Not a 1px circle.
    ink, bone, ember, wound, void = (
        (0x12, 0x08, 0x08, 255),
        (0xE6, 0xD9, 0xC3, 255),
        (0xE2, 0x5A, 0x1A, 255),
        (0x7A, 0x1F, 0x1A, 255),
        (0x0B, 0x0C, 0x10, 255),
    )
    colors = {"ink": ink, "bone": bone, "ember": ember, "wound": wound, "void": void}
    for y in range(64):
        for x in range(64):
            dx = abs(x - 31)
            dy = abs(y - 31)
            r = max(dx, dy, int(round((dx + dy) * 0.72)))
            band = None
            if 26 <= r <= 30:
                band = "ink"
            elif 22 <= r <= 25:
                band = palette["outer"]
            elif 18 <= r <= 21:
                band = palette["inner"]
            if band:
                px[x, y] = colors[band]
            # Chunky notches so the halo is not a smooth ring.
            if band and ((x + y) % 9 == 0) and 20 <= r <= 24:
                px[x, y] = colors[palette["notch"]]


def _chunk_x(px) -> None:
    ink = (0x12, 0x08, 0x08, 255)
    void = (0x0B, 0x0C, 0x10, 255)
    bone = (0xE6, 0xD9, 0xC3, 255)
    for i in range(11):
        for t in range(4):
            x0, y0 = 44 + i, 8 + i + t
            x1, y1 = 44 + i, 18 - i + t
            if 0 <= x0 < 64 and 0 <= y0 < 64:
                px[x0, y0] = void if t in (1, 2) else ink
            if 0 <= x1 < 64 and 0 <= y1 < 64:
                px[x1, y1] = void if t in (1, 2) else bone


def write_aura() -> None:
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    good = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    g = good.load()
    _chunk_ring(g, {"outer": "bone", "inner": "ember", "notch": "wound"})
    bad = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    b = bad.load()
    _chunk_ring(b, {"outer": "wound", "inner": "void", "notch": "ink"})
    _chunk_x(b)
    sheet.paste(good, (0, 0), good)
    sheet.paste(bad, (64, 0), bad)
    sheet.save(SPR / "pickup_aura.png")
    print("aura", sheet.size)


def main() -> None:
    write_pit()
    write_floor()
    write_doors()
    write_fx()
    write_hearts()
    write_aura()


if __name__ == "__main__":
    main()
