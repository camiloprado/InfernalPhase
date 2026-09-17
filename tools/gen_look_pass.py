#!/usr/bin/env python3
"""Generate locked-look sheets: Void/Ash/Bone/Ember/Wound. Hard edges, no AA."""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
ENV = ROOT / "assets" / "env"

VOID = (0x0B, 0x0C, 0x10, 255)
VOID_DEEP = (0x04, 0x05, 0x07, 255)
ASH = (0x5C, 0x5A, 0x56, 255)
ASH_DARK = (0x3A, 0x39, 0x36, 255)
ASH_MID = (0x4A, 0x48, 0x45, 255)
BONE = (0xE6, 0xD9, 0xC3, 255)
BONE_DIM = (0xB7, 0xAD, 0x9A, 255)
EMBER = (0xE2, 0x5A, 0x1A, 255)
WOUND = (0x7A, 0x1F, 0x1A, 255)
CLEAR = (0, 0, 0, 0)

# Portrait door cell — same atlas layout as the hell sheet (4×2 of 384×512)
# so sprites.gd cell(path, 4, 2, col, row) keeps working. Uniform scale
# opening/cell.x (~0.521) yields a 200×267 arch that sits on the wall band.
DOOR_W, DOOR_H = 384, 512


def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), CLEAR)


def arr_of(img: Image.Image) -> np.ndarray:
    return np.array(img)


def from_arr(a: np.ndarray) -> Image.Image:
    return Image.fromarray(a, "RGBA")


def put(px: Image.Image, x: int, y: int, c) -> None:
    w, h = px.size
    if 0 <= x < w and 0 <= y < h:
        px.putpixel((x, y), c)


def paint_mask(a: np.ndarray, mask: np.ndarray, col) -> None:
    a[mask] = col


def diamond_mask(h: int, w: int, cx: int, cy: int, rx: int, ry: int) -> np.ndarray:
    yy, xx = np.ogrid[:h, :w]
    return (np.abs(xx - cx) / max(rx, 1) + np.abs(yy - cy) / max(ry, 1)) <= 1.0


def ring_mask(h: int, w: int, cx: int, cy: int, ro: int, ri: int) -> np.ndarray:
    yy, xx = np.ogrid[:h, :w]
    d2 = (xx - cx) ** 2 + (yy - cy) ** 2
    return (d2 <= ro * ro) & (d2 >= ri * ri)


def circle_mask(h: int, w: int, cx: int, cy: int, r: int) -> np.ndarray:
    yy, xx = np.ogrid[:h, :w]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r


def gothic_arch_mask(h: int, w: int, cx: int, y_top: int, y_bot: int, half: int) -> tuple[np.ndarray, int, int]:
    """Equilateral lancet: r = 2*half so the head meets the jambs at full width.
    Shallower rise made a brick rectangle with a spike on top (the house-roof FAIL)."""
    yy, xx = np.ogrid[:h, :w]
    head_rise = int(round(half * math.sqrt(3.0)))
    max_rise = max(y_bot - y_top - 64, 48)
    if head_rise > max_rise:
        half = max(int(max_rise / math.sqrt(3.0)), 24)
        head_rise = int(round(half * math.sqrt(3.0)))
    spring = y_top + head_rise
    r2 = float((2.0 * half) ** 2)
    dx = np.abs(xx - cx)
    jambs = (yy >= spring) & (yy <= y_bot) & (dx <= half)
    d1 = (xx - (cx - half)).astype(np.float64) ** 2 + (yy - spring).astype(np.float64) ** 2
    d2 = (xx - (cx + half)).astype(np.float64) ** 2 + (yy - spring).astype(np.float64) ** 2
    head = (yy >= y_top) & (yy < spring) & (d1 <= r2) & (d2 <= r2)
    return jambs | head, spring, half


def erode(mask: np.ndarray, px: int) -> np.ndarray:
    acc = mask.copy()
    for _ in range(max(px, 0)):
        acc = (
            acc
            & np.roll(acc, 1, 0)
            & np.roll(acc, -1, 0)
            & np.roll(acc, 1, 1)
            & np.roll(acc, -1, 1)
        )
    return acc


def outline(mask: np.ndarray) -> np.ndarray:
    up = np.roll(mask, 1, 0)
    down = np.roll(mask, -1, 0)
    left = np.roll(mask, 1, 1)
    right = np.roll(mask, -1, 1)
    return mask & ~(up & down & left & right)


def diamond(px: Image.Image, cx: int, cy: int, rx: int, ry: int, fill, edge=None) -> None:
    a = arr_of(px)
    h, w = a.shape[:2]
    m = diamond_mask(h, w, cx, cy, rx, ry)
    paint_mask(a, m, fill)
    if edge:
        paint_mask(a, outline(m), edge)
    px.paste(from_arr(a))


def ring(px: Image.Image, cx: int, cy: int, ro: int, ri: int, fill, edge=None) -> None:
    a = arr_of(px)
    h, w = a.shape[:2]
    m = ring_mask(h, w, cx, cy, ro, ri)
    paint_mask(a, m, fill)
    if edge:
        paint_mask(a, outline(m), edge)
    px.paste(from_arr(a))


def circle_fill(px: Image.Image, cx: int, cy: int, r: int, fill) -> None:
    a = arr_of(px)
    h, w = a.shape[:2]
    paint_mask(a, circle_mask(h, w, cx, cy, r), fill)
    px.paste(from_arr(a))


def cracked_seal(cell: Image.Image, cx: int, cy: int, r: int, locked: bool, huge: bool) -> None:
    """Circular fixture. Locked = Ember lit. Open = cracked Ash/Void, no Ember."""
    rr = int(r * (1.10 if huge else 1.0))
    if locked:
        circle_fill(cell, cx, cy, rr + 4, ASH_DARK)
        circle_fill(cell, cx, cy, rr, EMBER)
        ring(cell, cx, cy, rr, max(rr - 6, 8), ASH_DARK)
        # Small brand glyph — still a circle, not a face.
        diamond(cell, cx, cy, max(7, rr // 5), max(5, rr // 7), VOID)
        diamond(cell, cx, cy, max(3, rr // 9), max(2, rr // 12), EMBER)
        return
    circle_fill(cell, cx, cy, rr + 4, ASH)
    circle_fill(cell, cx, cy, rr, VOID)
    ring(cell, cx, cy, rr, max(rr - 7, 8), ASH_DARK)
    _wound_rim_faults(cell, cx, cy, rr)
    _wound_fissures(cell, cx, cy, rr)


def _wound_rim_faults(px: Image.Image, cx: int, cy: int, r: int) -> None:
    for a_deg, span, inward in ((28, 7, 0.24), (78, 8, 0.28), (168, 6, 0.22), (312, 7, 0.26)):
        ang = math.radians(a_deg)
        nx, ny = math.cos(ang), math.sin(ang)
        tx, ty = -ny, nx
        for t in range(int(r * (1.0 - inward)), r + 1):
            for s in range(-span, span + 1):
                x = int(cx + t * nx + s * 0.35 * tx)
                y = int(cy + t * ny + s * 0.35 * ty)
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 <= r * r and d2 >= (r * 0.62) ** 2:
                    put(px, x, y, WOUND)
                    put(px, x + 1, y, WOUND)


def _wound_fissures(px: Image.Image, cx: int, cy: int, r: int) -> None:
    """Jagged Wound cracks. Not a diameter, not a crossing X."""
    specs = ((38, 0.22, 0.92), (118, 0.30, 0.96), (205, 0.26, 0.90), (300, 0.24, 0.94))
    for a_deg, t0, t1 in specs:
        ang = math.radians(a_deg)
        nx, ny = math.cos(ang), math.sin(ang)
        tx, ty = -ny, nx
        steps = max(int(r * (t1 - t0)), 4)
        for i in range(steps):
            t = t0 + (t1 - t0) * i / steps
            wobble = 1.6 * math.sin(i * 0.7)
            x = int(cx + t * r * nx + wobble * tx)
            y = int(cy + t * r * ny + wobble * ty)
            put(px, x, y, WOUND)
            put(px, x + 1, y, WOUND)
            put(px, x, y + 1, ASH_DARK)


def _masonry_frame(a: np.ndarray, frame: np.ndarray) -> None:
    """Ash stone on the arch ring only. Mortar stays in-family — no brown brick."""
    h, w = frame.shape
    yy, xx = np.ogrid[:h, :w]
    mortar = ASH_DARK
    paint_mask(a, frame, ASH_MID)
    course = 22
    face = frame & (yy % course > 3)
    stagger = ((yy // course) % 2) * 18
    joint = frame & (((xx + stagger) % 40) <= 2)
    paint_mask(a, face & ~joint, ASH)
    paint_mask(a, frame & ((yy % course <= 3) | joint), mortar)
    paint_mask(a, frame & (((xx * 5 + yy * 9) % 37) == 0), ASH_DARK)


def _voussoirs(a: np.ndarray, frame: np.ndarray, cx: int, spring: int, y_top: int, half: int) -> None:
    h, w = frame.shape
    yy, xx = np.ogrid[:h, :w]
    head = frame & (yy < spring)
    for i in range(-8, 9):
        ang = math.radians(90.0 + i * 10.0)
        vx, vy = math.cos(ang), -abs(math.sin(ang))
        px = xx - cx
        py = yy - (y_top + 10)
        cross = np.abs(px * vy - py * vx)
        along = px * vx + py * vy
        ray = head & (along > 6) & (cross <= 1.4)
        paint_mask(a, ray, ASH_DARK)


def door_cell(kind: str, locked: bool) -> Image.Image:
    """Gothic stone FRAME on transparent field + circular seal in the opening."""
    w, h = DOOR_W, DOOR_H
    cell = new(w, h)
    a = arr_of(cell)
    cx = w // 2
    huge = kind in ("start", "boss")
    half = 152 if huge else 140
    y_top, y_bot = 16, h - 12
    stone = 42 if huge else 34
    outer, spring, half = gothic_arch_mask(h, w, cx, y_top, y_bot, half)
    inner = erode(outer, stone)
    frame = outer & ~inner
    _masonry_frame(a, frame)
    _voussoirs(a, frame, cx, spring, y_top, half)
    # Thin Bone inlay on inner soffit and outer drip.
    paint_mask(a, outline(outer) & outer, BONE_DIM)
    paint_mask(a, outline(inner) & frame, BONE)
    # Sill — arch sits on the Ash wall band.
    yy, xx = np.ogrid[:h, :w]
    sill = frame & (yy >= y_bot - 14)
    paint_mask(a, sill, ASH)
    paint_mask(a, sill & (yy >= y_bot - 4), ASH_DARK)
    paint_mask(a, sill & (yy == y_bot - 14), BONE_DIM)
    ribs = 5 if kind == "start" else (4 if kind == "boss" else 0)
    if ribs:
        for i in range(ribs):
            t = (i + 1) / (ribs + 1)
            x = int(cx - half + t * half * 2)
            for ox in (0, 1):
                xx_ = x + ox
                if 0 <= xx_ < w:
                    col = frame[:, xx_]
                    a[col, xx_] = BONE_DIM if ox == 0 else ASH_DARK
    cell.paste(from_arr(a))
    # Seal in the opening, lower-center so it reads on the wall band not the point.
    seal_y = spring + int((y_bot - spring) * 0.38)
    seal_r = 62 if kind == "start" else (56 if kind == "boss" else 48)
    cracked_seal(cell, cx, seal_y, seal_r, locked, huge)
    return cell


def write_doors() -> None:
    cw, ch = DOOR_W, DOOR_H
    sheet = new(cw * 4, ch * 2)
    kinds = ["start", "combat", "npc", "boss"]
    for col, kind in enumerate(kinds):
        for row, locked in enumerate((False, True)):
            cell = door_cell(kind, locked)
            sheet.paste(cell, (col * cw, row * ch), cell)
    sheet.save(SPR / "doors.png")


def shot_diamond(frame: int) -> Image.Image:
    cell = new(64, 64)
    cx, cy = 32, 32
    rx, ry = 26, 18
    inset = (0, 1, 2, 1)[frame % 4]
    diamond(cell, cx, cy, rx, ry, EMBER, BONE)
    if inset:
        diamond(cell, cx, cy, max(4, rx - 8 - inset), max(3, ry - 6 - inset), VOID)
        diamond(cell, cx, cy, max(3, 6 - inset), max(2, 4 - inset), EMBER)
    else:
        diamond(cell, cx, cy, 6, 4, VOID)
        diamond(cell, cx, cy, 3, 2, EMBER)
    return cell


def shot_ring(frame: int) -> Image.Image:
    cell = new(64, 64)
    cx, cy = 32, 32
    ro, ri = 22, 13
    ring(cell, cx, cy, ro, ri, BONE, ASH_DARK)
    for i in range(4):
        ang = math.radians(frame * 22.5 + i * 90)
        rm = (ro + ri) * 0.5
        x = int(cx + rm * math.cos(ang))
        y = int(cy + rm * math.sin(ang))
        put(cell, x, y, VOID)
        put(cell, x + 1, y, VOID)
        put(cell, x, y + 1, VOID)
    return cell


def write_shots() -> None:
    diamond_rows = {0, 1, 4, 5, 7}
    sheet = new(256, 512)
    for row in range(8):
        for col in range(4):
            cell = shot_diamond(col) if row in diamond_rows else shot_ring(col)
            sheet.paste(cell, (col * 64, row * 64), cell)
    sheet.save(SPR / "shots.png")


def write_hearts() -> None:
    # 0 full Bone + Ember glyph · 1 empty hollow Ash · 2 hit Wound cracks · 3 shot glyph
    sheet = new(256, 64)
    filled = new(64, 64)
    circle_fill(filled, 32, 32, 28, BONE)
    ring(filled, 32, 32, 28, 25, BONE_DIM)
    diamond(filled, 32, 32, 12, 8, EMBER, ASH_DARK)
    diamond(filled, 32, 32, 4, 3, VOID)
    sheet.paste(filled, (0, 0), filled)

    empty = new(64, 64)
    ring(empty, 32, 32, 28, 20, ASH)
    ring(empty, 32, 32, 28, 26, ASH_DARK)
    sheet.paste(empty, (64, 0), empty)

    cracked = new(64, 64)
    circle_fill(cracked, 32, 32, 28, BONE)
    ring(cracked, 32, 32, 28, 25, BONE_DIM)
    _wound_rim_faults(cracked, 32, 32, 28)
    _wound_fissures(cracked, 32, 32, 28)
    sheet.paste(cracked, (128, 0), cracked)

    glyph = new(64, 64)
    diamond(glyph, 32, 32, 22, 16, EMBER, BONE)
    diamond(glyph, 32, 32, 7, 5, VOID)
    sheet.paste(glyph, (192, 0), glyph)
    sheet.save(SPR / "hearts.png")


def write_pit() -> None:
    """Void hole, thin Ash lip, 1px Bone hairline.
    Outside the lip is opaque Void (#0B0C10), not alpha 0. A transparent
    sprite quad punches the editor F5 viewport checkerboard.
    """
    n = 1024
    a = np.zeros((n, n, 4), dtype=np.uint8)
    a[:, :] = VOID
    yy, xx = np.ogrid[:n, :n]
    d2 = (xx - n // 2) ** 2 + (yy - n // 2) ** 2
    # Radii in px. At 0.30 scale: outer ~114px, lip ~11px, hole ~103px.
    bone, ash, shade, hole = 380, 377, 360, 348
    paint_mask(a, d2 <= hole * hole, VOID_DEEP)
    paint_mask(a, (d2 <= shade * shade) & (d2 > hole * hole), ASH_DARK)
    paint_mask(a, (d2 <= ash * ash) & (d2 > shade * shade), ASH)
    paint_mask(a, (d2 <= bone * bone) & (d2 > ash * ash), BONE)
    # Faint ritual ticks on the lip — still Ash/Bone, not lava.
    cx = cy = n // 2
    for i in range(12):
        ang = math.radians(i * 30.0)
        x = int(cx + 365 * math.cos(ang))
        y = int(cy + 365 * math.sin(ang))
        for ox in range(-1, 2):
            for oy in range(-1, 2):
                px, py = x + ox, y + oy
                if 0 <= px < n and 0 <= py < n and a[py, px, 3] > 0:
                    a[py, px] = BONE_DIM
    from_arr(a).save(ENV / "pit.png")


def penitent_cell(w: int, h: int, frame_row: int, frame_col: int, lilith: bool) -> Image.Image:
    cell = new(w, h)
    a = arr_of(cell)
    cx, cy = w // 2, h // 2 + (2 if frame_row == 1 else 0)
    rx, ry = (46, 62) if not lilith else (42, 68)
    if frame_row == 2:
        rx += 2
        ry += 2
    bob = (0, 1, 0, -1)[frame_col % 4] if frame_row == 1 else 0
    cy += bob
    body = diamond_mask(h, w, cx, cy, rx, ry)
    paint_mask(a, body, BONE)
    paint_mask(a, outline(body), ASH_DARK)
    hood_h = 44 if lilith else 38
    yy, xx = np.ogrid[:h, :w]
    hood = body & (yy < cy - ry + hood_h)
    paint_mask(a, hood, ASH)
    paint_mask(a, hood & (yy < cy - ry + 6), ASH_DARK)
    well = diamond_mask(h, w, cx, cy - ry + hood_h + 4, 10, 8)
    paint_mask(a, well, VOID)
    brand = 5 + (1 if frame_row == 2 and frame_col % 2 == 0 else 0)
    paint_mask(a, diamond_mask(h, w, cx, cy + 6, brand, brand + 1), EMBER)
    cell.paste(from_arr(a))
    return cell


def write_player(path: Path, lilith: bool) -> None:
    fw, fh = 144, 128
    sheet = new(fw * 4, fh * 3)
    for row in range(3):
        for col in range(4):
            cell = penitent_cell(fw, fh, row, col, lilith)
            sheet.paste(cell, (col * fw, row * fh), cell)
    sheet.save(path)


def write_baby() -> None:
    n = 1024
    a = np.zeros((n, n, 4), dtype=np.uint8)
    cx = cy = n // 2
    rx, ry = 380, 460
    body = diamond_mask(n, n, cx, cy, rx, ry)
    paint_mask(a, body, BONE)
    paint_mask(a, outline(body), ASH_DARK)
    yy, xx = np.ogrid[:n, :n]
    hood = body & (yy < cy - ry + 280)
    paint_mask(a, hood, ASH)
    paint_mask(a, hood & (yy < cy - ry + 70), ASH_DARK)
    paint_mask(a, diamond_mask(n, n, cx, cy - ry + 300, 80, 64), VOID)
    paint_mask(a, diamond_mask(n, n, cx, cy + 40, 28, 32), EMBER)
    from_arr(a).save(SPR / "baby.png")


def write_env() -> None:
    fw = fh = 64
    sheet = new(fw * 3, fh * 5)
    for row in range(5):
        for col in range(3):
            cell = new(fw, fh)
            a = arr_of(cell)
            yy, xx = np.ogrid[:fh, :fw]
            if col == 0:
                speck = (xx * 13 + yy * 7 + row * 11) % 17 == 0
                a[:, :] = VOID
                a[speck] = ASH_DARK
            elif col == 1:
                a[:, :] = ASH
                a[(xx + yy + row) % 9 == 0] = ASH_DARK
            else:
                a[:, :] = CLEAR
                for i in range(6):
                    x = 8 + (i * 9 + row * 3) % 48
                    y = 10 + (i * 11) % 44
                    a[y, x] = BONE_DIM
                    if x + 1 < fw:
                        a[y, x + 1] = ASH
            sheet.paste(from_arr(a), (col * fw, row * fh))
    sheet.save(SPR / "env.png")


def main() -> None:
    import sys

    SPR.mkdir(parents=True, exist_ok=True)
    ENV.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    if not only:
        only = {"doors", "hearts", "pit", "shots"}
    blocked = {"player", "env", "baby"} & only
    if blocked or "all" in only:
        raise SystemExit(
            "refusing to overwrite pixel character/env sheets with look-pass "
            "geometry. Allowed: doors hearts pit shots."
        )
    if "doors" in only:
        write_doors()
    if "shots" in only:
        write_shots()
    if "hearts" in only:
        write_hearts()
    if "pit" in only:
        write_pit()
    print("look-pass sheets written:", ", ".join(sorted(only)))


if __name__ == "__main__":
    main()
