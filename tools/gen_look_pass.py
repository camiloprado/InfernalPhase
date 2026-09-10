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
ASH = (0x5C, 0x5A, 0x56, 255)
ASH_DARK = (0x3A, 0x39, 0x36, 255)
BONE = (0xE6, 0xD9, 0xC3, 255)
BONE_DIM = (0xB7, 0xAD, 0x9A, 255)
EMBER = (0xE2, 0x5A, 0x1A, 255)
WOUND = (0x7A, 0x1F, 0x1A, 255)
CLEAR = (0, 0, 0, 0)


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


def arch_mask(h: int, w: int, cx: int, y0: int, y1: int, half: int) -> np.ndarray:
    # Tall pointed lancet: spring low, t^1.08 so the crown is a gothic point, not a house roof.
    yy, xx = np.ogrid[:h, :w]
    spring = y0 + int((y1 - y0) * 0.42)
    dx = np.abs(xx - cx)
    t = np.clip((spring - yy) / max(spring - y0, 1), 0, None)
    crown = half * np.maximum(0.0, 1.0 - np.power(t, 1.08)) + 0.5
    maxw = np.where(yy >= spring, half, crown)
    return (yy >= y0) & (yy <= y1) & (dx <= maxw)


def outline(mask: np.ndarray) -> np.ndarray:
    up = np.roll(mask, 1, 0)
    down = np.roll(mask, -1, 0)
    left = np.roll(mask, 1, 1)
    right = np.roll(mask, -1, 1)
    return mask & ~(up & down & left & right)


def thick_lip(mask: np.ndarray, px: int) -> np.ndarray:
    lip = outline(mask)
    acc = lip.copy()
    for _ in range(max(px, 1)):
        acc = acc | np.roll(acc, 1, 0) | np.roll(acc, -1, 0) | np.roll(acc, 1, 1) | np.roll(acc, -1, 1)
    return acc & mask


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
    # Circular fixture on the masonry face. No Bone/white halo — that read as a white oval.
    rr = int(r * (1.12 if huge else 1.0))
    if locked:
        circle_fill(cell, cx, cy, rr + 3, ASH_DARK)
        circle_fill(cell, cx, cy, rr, EMBER)
        ring(cell, cx, cy, rr, max(rr - 4, 8), ASH_DARK)
        return
    circle_fill(cell, cx, cy, rr + 3, ASH)
    circle_fill(cell, cx, cy, rr, VOID)
    ring(cell, cx, cy, rr + 1, max(rr - 5, 8), ASH_DARK)
    for a_deg, span in ((18, 11), (112, 13), (204, 10), (292, 12)):
        for p in range(-span, span + 1):
            ang = math.radians(a_deg + p * 0.55)
            x = int(cx + (rr + 1) * math.cos(ang))
            y = int(cy + (rr + 1) * math.sin(ang))
            put(cell, x, y, VOID)
            put(cell, x + 1, y, VOID)
    # Short irregular Wound chips from the rim — never a crossing X.
    for a_deg, length in ((24, int(rr * 0.42)), (128, int(rr * 0.50)), (246, int(rr * 0.38))):
        ang = math.radians(a_deg)
        for t in range(int(rr * 0.62), int(rr * 0.62) + length):
            x = int(cx + t * math.cos(ang))
            y = int(cy + t * math.sin(ang))
            if (x - cx) ** 2 + (y - cy) ** 2 <= (rr - 2) ** 2:
                put(cell, x, y, WOUND)
                put(cell, x + 1, y, WOUND)


def _masonry(a: np.ndarray, mask: np.ndarray, dark: bool = False) -> None:
    # Huge Ash courses so brick survives ~200×167 game scale. Mortar is Void-dark
    # so the arch reads as stacked stone, not a flat gray shield.
    h, w = mask.shape
    yy, xx = np.ogrid[:h, :w]
    mortar = (0x12, 0x11, 0x10, 255)
    face_c = (0x2E, 0x2D, 0x2A, 255) if dark else ASH
    fill_c = (0x1C, 0x1B, 0x19, 255) if dark else ASH_DARK
    paint_mask(a, mask, fill_c)
    course = 28
    face = mask & (yy % course > 3)
    stagger = ((yy // course) % 2) * 30
    joint = mask & (((xx + stagger) % 52) <= 2)
    paint_mask(a, face & ~joint, face_c)
    paint_mask(a, mask & ((yy % course <= 3) | joint), mortar)
    paint_mask(a, mask & (((xx * 5 + yy * 9) % 31) == 0), fill_c)


def _voussoirs(a: np.ndarray, outer: np.ndarray, cx: int, y0: int, half: int) -> None:
    # Radiating wedge joints on the pointed head — the gothic-arch tell at game scale.
    h, w = outer.shape
    yy, xx = np.ogrid[:h, :w]
    spring = y0 + int((h - y0) * 0.42)
    head = outer & (yy < spring)
    for i in range(-7, 8):
        ang = math.radians(90.0 + i * 11.0)
        vx, vy = math.cos(ang), -abs(math.sin(ang))
        # Distance to the ray from (cx, y0+8).
        px = xx - cx
        py = yy - (y0 + 8)
        cross = np.abs(px * vy - py * vx)
        along = px * vx + py * vy
        ray = head & (along > 8) & (cross <= 1.6)
        paint_mask(a, ray, (0x1A, 0x19, 0x18, 255))


def door_cell(kind: str, locked: bool) -> Image.Image:
    # Tall lancet cell (~200×167 in-game). Squat 92px slabs read as gray shields.
    # Solid masonry face — a punched hole read as a portal.
    w, h = 384, 320
    cell = new(w, h)
    a = arr_of(cell)
    cx, y0, y1 = 192, 6, 314
    half = 148
    huge = kind == "start"
    ribs = 5 if huge else (4 if kind == "boss" else 3)
    if huge:
        half = 154
    outer = arch_mask(h, w, cx, y0, y1, half)
    _masonry(a, outer)
    _voussoirs(a, outer, cx, y0, half)
    # Recessed pointed leaf — architecture, not a filled shield and not a round portal.
    leaf = arch_mask(h, w, cx, y0 + 36, y1 - 8, max(half - 36, 10))
    _masonry(a, leaf, dark=True)
    paint_mask(a, outline(leaf) & outer, BONE_DIM)
    inlay = arch_mask(h, w, cx, y0 + 14, y1 - 6, max(half - 14, 8))
    paint_mask(a, outline(inlay) & outer, BONE_DIM)
    for i in range(ribs):
        t = (i + 1) / (ribs + 1)
        x = int(cx - half + t * half * 2)
        for ox in (0, 1, 2):
            xx = x + ox
            if 0 <= xx < w:
                col = outer[:, xx] & ~leaf[:, xx]
                a[col, xx] = BONE_DIM if ox == 0 else (0x1A, 0x19, 0x18, 255)
    if 0 <= y1 < h:
        a[y1, outer[y1]] = ASH
        if y1 - 1 >= 0:
            a[y1 - 1, outer[y1 - 1]] = ASH_DARK
    cell.paste(from_arr(a))
    # Seal on the lower face, large so it stays a circle at ~167px.
    seal_y = 210
    if huge:
        seal_r = 62 if locked else 56
    elif kind == "boss":
        seal_r = 56 if locked else 50
    else:
        seal_r = 52 if locked else 46
    cracked_seal(cell, cx, seal_y, seal_r, locked, huge)
    return cell


def write_doors() -> None:
    cw, ch = 384, 320
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
    # 0 full Bone + Ember glyph · 1 empty hollow Ash · 2 hit Wound chips · 3 shot glyph
    # No slash-X — hit chips are short rim bites that never cross the disk.
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
    circle_fill(cracked, 32, 32, 28, BONE_DIM)
    ring(cracked, 32, 32, 28, 25, ASH)
    for a_deg, length in ((20, 9), (118, 10), (238, 8)):
        ang = math.radians(a_deg)
        for t in range(18, 18 + length):
            x = int(32 + t * math.cos(ang))
            y = int(32 + t * math.sin(ang))
            if (x - 32) ** 2 + (y - 32) ** 2 <= 26 ** 2:
                put(cracked, x, y, WOUND)
                put(cracked, x + 1, y, WOUND)
    sheet.paste(cracked, (128, 0), cracked)
    glyph = new(64, 64)
    diamond(glyph, 32, 32, 22, 16, EMBER, BONE)
    diamond(glyph, 32, 32, 7, 5, VOID)
    sheet.paste(glyph, (192, 0), glyph)
    sheet.save(SPR / "hearts.png")


def write_pit() -> None:
    n = 1024
    a = np.zeros((n, n, 4), dtype=np.uint8)
    yy, xx = np.ogrid[:n, :n]
    d2 = (xx - n // 2) ** 2 + (yy - n // 2) ** 2
    outer, bone, ash, hole = 390, 372, 358, 340
    paint_mask(a, (d2 <= outer * outer) & (d2 > bone * bone), ASH)
    paint_mask(a, (d2 <= bone * bone) & (d2 > ash * ash), BONE)
    paint_mask(a, (d2 <= ash * ash) & (d2 > hole * hole), ASH_DARK)
    paint_mask(a, d2 <= hole * hole, VOID)
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
    # Default: doors + hearts only. Do not churn pit / shots / Penitent sheets.
    if not only:
        only = {"doors", "hearts"}
    if "all" in only:
        only = {"doors", "shots", "hearts", "pit", "player", "env"}
    if "doors" in only:
        write_doors()
    if "shots" in only:
        write_shots()
    if "hearts" in only:
        write_hearts()
    if "pit" in only:
        write_pit()
    if "player" in only:
        write_player(SPR / "player.png", False)
        write_player(SPR / "player_f.png", True)
        write_baby()
    if "env" in only:
        write_env()
    print("look-pass sheets written:", ", ".join(sorted(only)))


if __name__ == "__main__":
    main()
