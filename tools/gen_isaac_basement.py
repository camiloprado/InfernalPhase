#!/usr/bin/env python3
"""Pacote A — Isaac basement / Sheol sheets.

Hard-pixel drawings in the Infernal ramp (shades of Void, Ash, Bone, Ember,
Wound). No diamond, ring, ellipse, checker, wood, or brown.

    shots.png   4×8 of 64     (256×512)
    doors.png   4×2 of 256×96 (1024×192)  flush wall-band doorways
    env.png     8×5 of 64     (512×320)   rows 1–3 are the room themes
    pit.png     1024×1024                 stepped Ash rim, opaque Void field
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
ENV = ROOT / "assets" / "env"

# Locked hues plus shade steps of those hues only. No gold, green, or brown.
VOID = (0x0B, 0x0C, 0x10, 255)
VOID_DEEP = (0x06, 0x07, 0x0A, 255)
ASH = (0x5C, 0x5A, 0x56, 255)
ASH_HI = (0x8A, 0x88, 0x84, 255)
ASH_MID = (0x45, 0x43, 0x40, 255)
ASH_LO = (0x32, 0x31, 0x2E, 255)
ASH_MORT = (0x1A, 0x19, 0x18, 255)
BONE = (0xE6, 0xD9, 0xC3, 255)
BONE_DIM = (0xB4, 0xA8, 0x96, 255)
BONE_SHADE = (0x7A, 0x72, 0x64, 255)
EMBER = (0xE2, 0x5A, 0x1A, 255)
EMBER_HI = (0xF0, 0x7A, 0x38, 255)
EMBER_LO = (0xA3, 0x3A, 0x10, 255)
WOUND = (0x7A, 0x1F, 0x1A, 255)
WOUND_LO = (0x4A, 0x12, 0x10, 255)
CLEAR = (0, 0, 0, 0)

ALLOWED = {
    VOID, VOID_DEEP, ASH, ASH_HI, ASH_MID, ASH_LO, ASH_MORT,
    BONE, BONE_DIM, BONE_SHADE, EMBER, EMBER_HI, EMBER_LO,
    WOUND, WOUND_LO, CLEAR,
}

# env.png: 8×5 of 64. Rows 0 and 4 stay a Void field (not stamped).
# Rows 1–3 are Start / Combat / NPC. Cols 0–3 floor grit, 4–5 walls, 6–7 sigils.
ENV_COLS, ENV_ROWS, TILE = 8, 5, 64
DOOR_W, DOOR_H = 256, 96


def new(w: int, h: int, fill=CLEAR) -> Image.Image:
    return Image.new("RGBA", (w, h), fill)


def put(px: Image.Image, x: int, y: int, c) -> None:
    w, h = px.size
    if 0 <= x < w and 0 <= y < h and c in ALLOWED:
        px.putpixel((x, y), c)


def blit_rows(dst: Image.Image, rows: list[str], ox: int, oy: int, scale: int, cmap: dict) -> None:
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in " .":
                continue
            col = cmap[ch]
            for yy in range(scale):
                for xx in range(scale):
                    put(dst, ox + i * scale + xx, oy + j * scale + yy, col)


def center_blit(cell: Image.Image, rows: list[str], scale: int, cmap: dict, nudge=(0, 0)) -> None:
    gh = len(rows) * scale
    gw = max(len(r) for r in rows) * scale
    ox = (cell.size[0] - gw) // 2 + nudge[0]
    oy = (cell.size[1] - gh) // 2 + nudge[1]
    blit_rows(cell, rows, ox, oy, scale, cmap)


def assert_palette(img: Image.Image, name: str) -> None:
    colors = img.getcolors(max(img.size[0] * img.size[1], 1))
    if not colors:
        raise SystemExit(f"{name}: too many colors")
    bad = [c for _n, c in colors if c not in ALLOWED]
    if bad:
        raise SystemExit(f"{name}: off-palette {bad[:6]}")


# ---------------------------------------------------------------------------
# Shots — drawn silhouettes, 4 frames. Pointing +X so travel-facing rows aim.
# ---------------------------------------------------------------------------

COAL_MAP = {
    "o": ASH_MORT,
    "e": EMBER,
    "E": EMBER_HI,
    "l": EMBER_LO,
    "w": WOUND,
    "W": WOUND_LO,
    "b": BONE_DIM,
}
BONE_MAP = {
    "o": ASH_MORT,
    "B": BONE,
    "h": BONE_DIM,
    "s": BONE_SHADE,
    "w": WOUND,
    "W": WOUND_LO,
    "e": EMBER,
}
TEAR_MAP = {
    "o": ASH_LO,
    "A": ASH,
    "h": ASH_HI,
    "s": ASH_MID,
    "w": WOUND,
    "W": WOUND_LO,
    "b": BONE_DIM,
}

# Asymmetric ember coal. Tail on the left, chipped nose to the right, wound core.
COAL = [
    "..............oooo......",
    "............ooEEEEoo....",
    "..........ooEEEEEEEoo...",
    ".oooo....oEEEwwEEEElo...",
    "oEEEEo..oEEwwwwEEElEo...",
    "oEEwwwo.oEwWWWwwEElEo...",
    ".owwWWo.EwWWWWWwElo.....",
    "..owWWo.oEWWWEloo.......",
    "...ooo...ooEloo.........",
    "...........ooo..........",
]
COAL_HOT = [
    ".............ooooo......",
    "...........ooEEEEEoo....",
    ".........ooEEEEEEEEoo...",
    "oooo....oEEEwwEEEEElo...",
    "EEEEo..oEEwwwwwEEElEo...",
    "EEwwwo.oEwWWWWWwEElEo...",
    "owwWWo.EwWWWWWWwElo.....",
    ".owWWo..oWWWEloo........",
    "..ooo....ooEloo.........",
    "...........ooo..........",
]
# Deflected coal keeps the shard but picks up a Bone rim on the nose.
COAL_BONE = [
    "..............oooo......",
    "............ooEEEEbo....",
    "..........ooEEEEEEbbo...",
    ".oooo....oEEEwwEEEbbo...",
    "oEEEEo..oEEwwwwEEbEo....",
    "oEEwwwo.oEwWWWwwbEo.....",
    ".owwWWo.EwWWWWWbbo......",
    "..owWWo.oEWWEboo........",
    "...ooo...ooboo..........",
    "...........ooo..........",
]
# Bone chip — irregular flake, wound crack, not a ring.
BONE_CHIP = [
    "......ooooooo...........",
    "....ooBBBBBBhho.........",
    "...oBBBBBBBBBBho........",
    "..oBBBBwwBBBBBBho.......",
    "..oBBBwwwwBBBBBo........",
    "..oBBwwWWWBBBhho........",
    "...oBwwWWBBBhho.........",
    "....oBBBBBhho...........",
    ".....oBBBho.............",
    "......ooo...............",
]
BONE_BOSS = [
    ".....ooooooooo..........",
    "...ooBBBBBBBBhho........",
    "..oBBBBBBBBBBBBho.......",
    ".oBBBwwwwBBBBBBBho......",
    ".oBBwwWWWwwBBBBBo.......",
    ".oBwwWWWWWWwBBBhho......",
    "..oBwwWWWWwBBBhho.......",
    "...oBBBBBBBhho..........",
    "....oBBBBhho............",
    ".....ooooo..............",
]
# Ash tear flying +X. Round back, flat belly, wound fissure, stepped nose.
ASH_TEAR = [
    "......oooo..............",
    "....oohhhho.............",
    "...ohhhhhhhho...........",
    "..ohhhwwAhhhho..........",
    ".ohhwwwwAhhhhso.........",
    ".ohwwWWwAhhhhso.........",
    "..owwWAhhhsso...........",
    "...oAAhso...............",
    "....oso.................",
]
ASH_TEAR_LONG = [
    ".......ooooo............",
    ".....oohhhhho...........",
    "...oohhhhhhhhho.........",
    "..ohhhhwwAhhhhho........",
    ".ohhwwwwwAhhhhhso.......",
    ".ohwwWWWwAhhhhhsso......",
    "..owwWWAhhhhsso.........",
    "...oAAAhso..............",
    "....ooso................",
]


def _spark(cell: Image.Image, frame: int, hot: bool) -> None:
    """Motes stuck to the nose so a frame flickers without leaving the shard."""
    if not hot:
        return
    px = cell.load()
    w, h = cell.size
    nose = None
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                if nose is None or x > nose[0]:
                    nose = (x, y)
    if nose is None:
        return
    x, y = nose
    col = EMBER_HI if frame % 2 == 0 else EMBER
    put(cell, x + 1, y, col)
    put(cell, x + 2, y + (1 if frame == 1 else -1), EMBER_LO if hot else ASH_HI)
    if hot and frame == 3:
        put(cell, x + 3, y, BONE)


def _crack_flicker(cell: Image.Image, frame: int) -> None:
    if frame % 2 == 0:
        return
    # Brighten a couple of wound pixels already in the core so the crack breathes.
    px = cell.load()
    w, h = cell.size
    n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y] == WOUND and (x + y + frame) % 7 == 0:
                px[x, y] = WOUND_LO if frame == 3 else EMBER_LO
                n += 1
                if n > 6:
                    return


def shot_cell(rows: list[str], cmap: dict, frame: int, hot: bool = False) -> Image.Image:
    cell = new(64, 64)
    # Nudge the nose toward +X so the travel pivot (cell center) sits in the body.
    center_blit(cell, rows, 2, cmap, nudge=(2, 0))
    _spark(cell, frame, hot)
    _crack_flicker(cell, frame)
    return cell


def write_shots() -> None:
    sheet = new(256, 512)
    # row: (glyph, cmap, hot)
    spec = [
        (COAL, COAL_MAP, False),
        (ASH_TEAR, TEAR_MAP, False),
        (BONE_CHIP, BONE_MAP, False),
        (ASH_TEAR_LONG, TEAR_MAP, False),
        (BONE_BOSS, BONE_MAP, False),
        (COAL_HOT, COAL_MAP, True),
        (BONE_CHIP, BONE_MAP, False),
        (COAL_BONE, COAL_MAP, False),
    ]
    for row, (glyph, cmap, hot) in enumerate(spec):
        for col in range(4):
            cell = shot_cell(glyph, cmap, col, hot)
            sheet.paste(cell, (col * 64, row * 64), cell)
    _reject_geometry(sheet)
    assert_palette(sheet, "shots")
    sheet.save(SPR / "shots.png")


def _mask_of(cell: Image.Image) -> np.ndarray:
    a = np.array(cell)
    return a[:, :, 3] > 0


def _iou(a: np.ndarray, b: np.ndarray) -> float:
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return float(inter) / float(union) if union else 1.0


def _diamond_mask(h: int, w: int, xs, ys) -> np.ndarray:
    cx, cy = float(xs.mean()), float(ys.mean())
    rx = max(float(xs.max() - cx), float(cx - xs.min()), 1.0)
    ry = max(float(ys.max() - cy), float(cy - ys.min()), 1.0)
    yy, xx = np.ogrid[:h, :w]
    return (np.abs(xx - cx) / rx + np.abs(yy - cy) / ry) <= 1.0


def _ellipse_mask(h: int, w: int, xs, ys) -> np.ndarray:
    cx, cy = float(xs.mean()), float(ys.mean())
    rx = max(float(xs.max() - cx), float(cx - xs.min()), 1.0)
    ry = max(float(ys.max() - cy), float(cy - ys.min()), 1.0)
    yy, xx = np.ogrid[:h, :w]
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0


def _ring_mask(h: int, w: int, xs, ys) -> np.ndarray:
    cx, cy = float(xs.mean()), float(ys.mean())
    r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    ro = max(float(r.max()), 1.0)
    ri = ro * 0.55
    yy, xx = np.ogrid[:h, :w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return (d <= ro) & (d >= ri)


def _reject_geometry(sheet: Image.Image) -> None:
    """Fail the build if a shot cell collapses back to a diamond, ring, or ellipse."""
    for row in range(8):
        cell = sheet.crop((0, row * 64, 64, row * 64 + 64))
        m = _mask_of(cell)
        ys, xs = np.where(m)
        if xs.size < 40:
            raise SystemExit(f"shot row {row} too empty")
        h, w = m.shape
        if _iou(m, _diamond_mask(h, w, xs, ys)) > 0.86:
            raise SystemExit(f"shot row {row} reads as a diamond")
        if _iou(m, _ellipse_mask(h, w, xs, ys)) > 0.90:
            raise SystemExit(f"shot row {row} reads as an ellipse")
        if _iou(m, _ring_mask(h, w, xs, ys)) > 0.72:
            raise SystemExit(f"shot row {row} reads as a ring")
        # Directional shots must be wider than they are tall.
        if row in (0, 1, 3, 5, 7):
            if (xs.max() - xs.min()) <= (ys.max() - ys.min()):
                raise SystemExit(f"shot row {row} is not a directional shard/tear")


# ---------------------------------------------------------------------------
# Walls / floors — 64px cells, 32px Ash blocks, Void grit.
# ---------------------------------------------------------------------------

def brick_at(x: int, y: int, seed: int = 0) -> tuple:
    """32×32 Ash block. Odd courses shift 16px so the tile repeats without a seam."""
    course = y // 32
    sx = (x + (16 if course % 2 else 0)) % 32
    ly = y % 32
    if sx >= 30 or ly >= 30:
        return ASH_MORT
    lx = sx
    # Stable chip per brick so neighboring tiles share the module.
    bx = (x + (16 if course % 2 else 0)) // 32
    by = course
    chip = (bx * 5 + by * 9 + seed * 3) % 13 == 0
    if chip and lx > 20 and ly > 20:
        return VOID if (lx + ly) % 2 == 0 else ASH_MORT
    if chip and 10 <= lx <= 16 and 12 <= ly <= 20 and (lx + ly) % 2 == 0:
        return WOUND_LO
    if ly < 2 or lx < 2:
        return ASH_HI
    if ly > 26 or lx > 26:
        return ASH_LO
    if (lx + by) % 17 == 0 and ly < 8:
        return ASH_MID
    return ASH


def paint_bricks(img: Image.Image, rect: tuple, seed: int = 0) -> None:
    x0, y0, x1, y1 = rect
    px = img.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = brick_at(x, y, seed)


def floor_cell(variant: int, theme: int) -> Image.Image:
    """Void field. A few Ash/Bone marks, inset so the 64px seam stays invisible."""
    cell = new(TILE, TILE, VOID)
    px = cell.load()
    # Hand marks. Variant changes which cluster; theme only adds one extra nick.
    marks = {
        0: [(18, 42, ASH_LO), (19, 42, ASH_LO), (46, 20, ASH_MID), (47, 21, ASH_LO), (30, 16, ASH_MORT)],
        1: [(22, 28, BONE_SHADE), (23, 28, BONE_DIM), (24, 29, BONE_SHADE), (23, 29, ASH_LO),
            (48, 46, ASH_LO), (49, 46, ASH_MID)],
        2: [(16, 36, ASH_MID), (17, 37, ASH_LO), (18, 37, ASH_MID), (19, 38, ASH_LO),
            (20, 38, ASH_MORT), (50, 18, ASH_LO), (36, 50, ASH_MID)],
        3: [(40, 44, BONE_SHADE), (41, 44, BONE_DIM), (41, 45, ASH_LO),
            (14, 18, ASH_MID), (15, 18, ASH_LO), (28, 24, ASH_MORT)],
    }
    for x, y, c in marks[variant]:
        px[x, y] = c
    if theme == 2 and variant == 2:
        px[34, 22] = WOUND_LO
        px[35, 23] = WOUND_LO
    if theme == 3 and variant == 1:
        px[52, 30] = BONE_SHADE
    return cell


def _circle_pixels(cx: int, cy: int, r: int) -> list[tuple[int, int]]:
    pts = []
    x, y, d = 0, r, 3 - 2 * r
    def plot(px, py):
        pts.append((cx + px, cy + py))
        pts.append((cx - px, cy + py))
        pts.append((cx + px, cy - py))
        pts.append((cx - px, cy - py))
        pts.append((cx + py, cy + px))
        pts.append((cx - py, cy + px))
        pts.append((cx + py, cy - px))
        pts.append((cx - py, cy - px))
    while x <= y:
        plot(x, y)
        if d < 0:
            d += 4 * x + 6
        else:
            d += 4 * (x - y) + 10
            y -= 1
        x += 1
    return pts


def sigil_cell(kind: str) -> Image.Image:
    cell = new(TILE, TILE, CLEAR)
    px = cell.load()
    cx = cy = TILE // 2
    if kind == "npc":
        # Bone inlay square — Concierge floor mark, still Ash stone, no wood.
        for x in range(16, 48):
            px[x, 20] = BONE_DIM
            px[x, 44] = BONE_SHADE
        for y in range(20, 45):
            px[16, y] = BONE_DIM
            px[47, y] = BONE_SHADE
        px[18, 22] = ASH_HI
        px[45, 42] = ASH_LO
        return cell
    radius = {"start": 22, "combat": 24, "boss": 26}[kind]
    col = {"start": BONE_DIM, "combat": ASH, "boss": WOUND}[kind]
    gaps = {0, 1, 14, 15} if kind != "boss" else {4, 5, 20}
    pts = _circle_pixels(cx, cy, radius)
    for i, (x, y) in enumerate(pts):
        if i % 32 in gaps:
            continue
        if 0 <= x < TILE and 0 <= y < TILE:
            px[x, y] = col
            if kind == "start" and i % 32 == 8:
                px[x, y] = BONE
    # Short ticks, not a cathedral rose.
    ticks = ((0, -1), (1, 0), (0, 1), (-1, 0))
    tick_col = EMBER if kind == "boss" else (WOUND if kind == "combat" else ASH_HI)
    for dx, dy in ticks:
        for t in range(3, 6):
            x, y = cx + dx * (radius + t), cy + dy * (radius + t)
            if 0 <= x < TILE and 0 <= y < TILE:
                px[x, y] = tick_col
    if kind == "boss":
        px[cx, cy] = EMBER_LO
        px[cx + 1, cy] = WOUND
    return cell


def write_env() -> None:
    sheet = new(ENV_COLS * TILE, ENV_ROWS * TILE, VOID)
    for row in range(ENV_ROWS):
        theme = row  # 1 start, 2 combat, 3 npc; 0 and 4 are unused Void
        for col in range(4):
            sheet.paste(floor_cell(col, theme), (col * TILE, row * TILE))
        wall = new(TILE, TILE, VOID)
        paint_bricks(wall, (0, 0, TILE, TILE), seed=1)
        sheet.paste(wall, (4 * TILE, row * TILE))
        chipped = new(TILE, TILE, VOID)
        paint_bricks(chipped, (0, 0, TILE, TILE), seed=4)
        sheet.paste(chipped, (5 * TILE, row * TILE))
    # Sigils only on the rows the floor actually stamps.
    for row, kind in ((1, "start"), (2, "combat"), (3, "npc")):
        sheet.paste(sigil_cell(kind), (6 * TILE, row * TILE), sigil_cell(kind))
    boss = sigil_cell("boss")
    sheet.paste(boss, (7 * TILE, 2 * TILE), boss)
    # Other col-7 cells stay Void so a bad index cannot punch a hole.
    _reject_checker(sheet)
    assert_palette(sheet, "env")
    sheet.save(SPR / "env.png")


def _reject_checker(sheet: Image.Image) -> None:
    """Floor variants must stay Void. A light/dark alternation is the old checker FAIL."""
    a = np.array(sheet)
    means = []
    for col in range(4):
        for row in (1, 2, 3):
            cell = a[row * TILE:(row + 1) * TILE, col * TILE:(col + 1) * TILE]
            means.append(cell[:, :, :3].mean())
    if max(means) - min(means) > 8:
        raise SystemExit(f"floor variants diverge like a checker: {means}")
    if max(means) > 28:
        raise SystemExit(f"floor too bright (want Void grit): {max(means)}")
    wall = a[TILE:TILE * 2, 4 * TILE:5 * TILE]
    if wall[:, :, :3].mean() < 50:
        raise SystemExit("wall tile does not read as Ash block")


# ---------------------------------------------------------------------------
# Doors — rectangular flush frame in the wall band. Row 0 open, row 1 locked.
# Texture top is the room-side lip (see Room._door_rotation).
# ---------------------------------------------------------------------------

def _wound_crack(img: Image.Image, x: int, y: int, dx: int, dy: int, n: int) -> None:
    px = img.load()
    wob = (0, 1, 0, -1, 1, 0, -1, 0)
    for i in range(n):
        xx = x + dx * i + wob[i % len(wob)] * (0 if dx == 0 else 0) + (wob[i % len(wob)] if dy != 0 or dx != 0 else 0)
        yy = y + dy * i + (wob[(i + 3) % len(wob)] if dx != 0 else 0)
        if 0 <= xx < img.size[0] and 0 <= yy < img.size[1] and px[xx, yy][3] == 255:
            px[xx, yy] = WOUND if i % 3 else WOUND_LO


def _ember_plate(img: Image.Image, cx: int, cy: int, pw: int, ph: int) -> None:
    """Rectangular Ember plate. The mark is a short Wound fissure, not a diamond."""
    px = img.load()
    x0, y0 = cx - pw // 2, cy - ph // 2
    for y in range(y0, y0 + ph):
        for x in range(x0, x0 + pw):
            edge = x < x0 + 2 or y < y0 + 2 or x >= x0 + pw - 2 or y >= y0 + ph - 2
            if edge:
                px[x, y] = ASH_MORT
            elif y < y0 + 4 or x < x0 + 3:
                px[x, y] = EMBER_HI
            elif y > y0 + ph - 5 or x > x0 + pw - 4:
                px[x, y] = EMBER_LO
            else:
                px[x, y] = EMBER
    # Fissure across the plate.
    mid = cy
    for i, x in enumerate(range(cx - pw // 5, cx + pw // 5)):
        yy = mid + (1 if i % 4 == 0 else 0) - (1 if i % 5 == 0 else 0)
        px[x, yy] = WOUND_LO
        px[x, yy + 1] = WOUND


def door_cell(kind: str, locked: bool) -> Image.Image:
    cell = new(DOOR_W, DOOR_H, CLEAR)
    jamb = {"start": 44, "combat": 34, "npc": 28, "boss": 42}[kind]
    seed = {"start": 2, "combat": 1, "npc": 3, "boss": 5}[kind]
    # Room-side lip (texture top) and outer sill.
    paint_bricks(cell, (0, 0, DOOR_W, 10), seed)
    paint_bricks(cell, (0, DOOR_H - 10, DOOR_W, DOOR_H), seed)
    paint_bricks(cell, (0, 0, jamb, DOOR_H), seed)
    paint_bricks(cell, (DOOR_W - jamb, 0, DOOR_W, DOOR_H), seed)
    px = cell.load()
    # Bone inlay on the inner lip and the jamb reveal.
    for x in range(0, DOOR_W):
        if 8 <= x < DOOR_W - 8:
            px[x, 8] = BONE_DIM
            px[x, DOOR_H - 9] = BONE_SHADE
    for y in range(8, DOOR_H - 8):
        px[jamb - 1, y] = BONE
        px[DOOR_W - jamb, y] = BONE_DIM
    if kind in ("start", "boss"):
        for y in range(12, DOOR_H - 12, 16):
            px[6, y] = BONE_DIM
            px[DOOR_W - 7, y] = BONE_DIM
            px[6, y + 1] = ASH_HI
            px[DOOR_W - 7, y + 1] = ASH_HI
    if locked:
        # Shut slab: same Ash blocks, darker courses, sitting in the opening.
        paint_bricks(cell, (jamb, 10, DOOR_W - jamb, DOOR_H - 10), seed + 7)
        for y in range(12, DOOR_H - 12):
            for x in range(jamb + 2, DOOR_W - jamb - 2):
                if px[x, y] == ASH_HI:
                    px[x, y] = ASH
                elif px[x, y] == ASH:
                    px[x, y] = ASH_MID
        pw, ph = {"start": (64, 34), "combat": (48, 26), "npc": (40, 22), "boss": (58, 32)}[kind]
        _ember_plate(cell, DOOR_W // 2, DOOR_H // 2 + 2, pw, ph)
        if kind == "boss":
            _wound_crack(cell, jamb + 8, 18, 1, 1, 14)
            _wound_crack(cell, DOOR_W - jamb - 10, DOOR_H - 22, -1, -1, 12)
    else:
        # Opening stays clear so the Void floor shows through the frame.
        _wound_crack(cell, jamb - 6, 16, 0, 1, 18)
        _wound_crack(cell, DOOR_W - jamb + 4, DOOR_H - 28, 0, 1, 16)
        if kind != "npc":
            _wound_crack(cell, jamb + 2, DOOR_H // 2, 1, 0, 8)
        if kind == "boss":
            _wound_crack(cell, 8, 14, 1, 1, 20)
    # Keep the outer 1px of the lip from going transparent (flush with the wall).
    assert_palette(cell, f"door {kind} locked={locked}")
    return cell


def write_doors() -> None:
    sheet = new(DOOR_W * 4, DOOR_H * 2, CLEAR)
    kinds = ["start", "combat", "npc", "boss"]
    for col, kind in enumerate(kinds):
        for row, locked in enumerate((False, True)):
            cell = door_cell(kind, locked)
            sheet.paste(cell, (col * DOOR_W, row * DOOR_H), cell)
    assert_palette(sheet, "doors")
    # Open combat cell must have a real hole, locked cell must be shut.
    open_c = sheet.crop((DOOR_W, 0, DOOR_W * 2, DOOR_H))
    locked_c = sheet.crop((DOOR_W, DOOR_H, DOOR_W * 2, DOOR_H * 2))
    oa = np.array(open_c)
    la = np.array(locked_c)
    if (oa[:, :, 3] == 0).sum() < 4000:
        raise SystemExit("open door has no passageway")
    if (la[:, :, 3] == 0).sum() > 200:
        raise SystemExit("locked door is not a shut slab")
    ember = (la[:, :, 0] > 180) & (la[:, :, 1] < 140) & (la[:, :, 3] == 255)
    if ember.sum() < 200:
        raise SystemExit("locked door missing Ember plate")
    sheet.save(SPR / "doors.png")


# ---------------------------------------------------------------------------
# Pit — stepped Ash blocks around an opaque Void mouth. No alpha anywhere.
# ---------------------------------------------------------------------------

def write_pit() -> None:
    n = 1024
    a = np.zeros((n, n, 4), dtype=np.uint8)
    a[:, :] = VOID
    # 16px blocks. At the 0.25 room scale that is a 4px screen step.
    bs = 16
    hole_m, rim_m = 20, 26
    cx = cy = n // 2
    for y in range(n):
        by = (y - cy) // bs
        ly = (y - cy) - by * bs
        if y < cy and ly != 0:
            # floor-div toward -inf already; local offset inside the block
            pass
        ly = y - (cy + by * bs)
        for x in range(n):
            bx = (x - cx) // bs
            lx = x - (cx + bx * bs)
            ax, ay = abs(int(bx)), abs(int(by))
            m = max(ax, ay, (ax + ay + 1) // 2)
            if m > rim_m or m < hole_m:
                continue
            # Outer bone hairline, inner shadow step, body is an Ash block.
            if m == rim_m:
                col = BONE_DIM if (lx < 3 or ly < 3) else BONE_SHADE
            elif m == hole_m:
                col = ASH_LO
            elif lx >= bs - 2 or ly >= bs - 2:
                col = ASH_MORT
            elif lx < 2 or ly < 2:
                col = ASH_HI
            elif (bx * 3 + by * 5) % 17 == 0 and lx > 6 and ly > 6:
                col = ASH_MID
            else:
                col = ASH
            a[y, x] = col
    # Two Wound cracks on the rim, stepped so they follow the blocks.
    def crack(x: int, y: int, dx: int, dy: int, length: int) -> None:
        for i in range(length):
            xx = x + dx * i + (1 if i % 5 == 0 else 0)
            yy = y + dy * i + (1 if i % 7 == 0 else 0)
            for ox, oy in ((0, 0), (1, 0), (0, 1)):
                px, py = xx + ox, yy + oy
                if 0 <= px < n and 0 <= py < n and not (a[py, px, 0] == VOID[0] and a[py, px, 1] == VOID[1]):
                    a[py, px] = WOUND if i % 2 == 0 else WOUND_LO

    crack(cx + 18 * bs, cy - 8 * bs, 2, 3, 28)
    crack(cx - 16 * bs, cy + 10 * bs, 3, -2, 24)
    # Hole and the field outside the rim are exactly Void, fully opaque.
    if int((a[:, :, 3] == 0).sum()) != 0:
        raise SystemExit("pit has transparent pixels")
    void_px = (a[:, :, 0] == VOID[0]) & (a[:, :, 1] == VOID[1]) & (a[:, :, 2] == VOID[2])
    if void_px.sum() < n * n * 0.5:
        raise SystemExit("pit mouth is not a Void field")
    img = Image.fromarray(a, "RGBA")
    assert_palette(img, "pit")
    img.save(ENV / "pit.png")


def write_all() -> None:
    SPR.mkdir(parents=True, exist_ok=True)
    ENV.mkdir(parents=True, exist_ok=True)
    write_shots()
    write_doors()
    write_env()
    write_pit()
    print(
        "isaac basement sheets:",
        "shots", (SPR / "shots.png").stat().st_size,
        "doors", (SPR / "doors.png").stat().st_size,
        "env", (SPR / "env.png").stat().st_size,
        "pit", (ENV / "pit.png").stat().st_size,
    )


if __name__ == "__main__":
    write_all()
