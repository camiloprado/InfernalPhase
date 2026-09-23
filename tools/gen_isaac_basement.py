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

# Locked hues. Steps are shades of those hues only — the contour ink is the
# near-black red Caim's outline uses, not a new color. No gold, green, or brown.
def _c(r, g, b):
    return (r, g, b, 255)


INK = _c(0x12, 0x08, 0x08)
INK2 = _c(0x28, 0x10, 0x0C)
VOID = _c(0x0B, 0x0C, 0x10)
VOID_DEEP = _c(0x06, 0x07, 0x0A)
VOID_LIFT = _c(0x14, 0x16, 0x1C)
# Ash, dark to lit.
ASH_R = (
    _c(0x1A, 0x18, 0x16),
    _c(0x2A, 0x28, 0x26),
    _c(0x3A, 0x38, 0x34),
    _c(0x4A, 0x48, 0x44),
    _c(0x5C, 0x5A, 0x56),
    _c(0x72, 0x70, 0x6A),
    _c(0x88, 0x86, 0x80),
    _c(0x9A, 0x98, 0x92),
)
BONE_R = (
    _c(0x5C, 0x52, 0x44),
    _c(0x7A, 0x6E, 0x5C),
    _c(0xA2, 0x94, 0x7E),
    _c(0xC4, 0xB4, 0x9E),
    _c(0xE6, 0xD9, 0xC3),
    _c(0xF3, 0xEB, 0xDC),
)
EMBER_R = (
    _c(0x4A, 0x14, 0x08),
    _c(0x7A, 0x28, 0x0C),
    _c(0xA6, 0x3A, 0x10),
    _c(0xC6, 0x4C, 0x14),
    _c(0xE2, 0x5A, 0x1A),
    _c(0xF0, 0x74, 0x30),
    _c(0xF4, 0x80, 0x3C),
)
WOUND_R = (
    _c(0x2C, 0x08, 0x08),
    _c(0x4A, 0x12, 0x10),
    _c(0x7A, 0x1F, 0x1A),
    _c(0xA2, 0x32, 0x28),
    _c(0xC0, 0x46, 0x38),
)
# Aliases the pit still paints with.
ASH = ASH_R[4]
ASH_HI = ASH_R[6]
ASH_MID = ASH_R[3]
ASH_LO = ASH_R[2]
ASH_MORT = ASH_R[0]
BONE = BONE_R[4]
BONE_DIM = BONE_R[3]
BONE_SHADE = BONE_R[1]
EMBER = EMBER_R[4]
EMBER_HI = EMBER_R[5]
EMBER_LO = EMBER_R[2]
WOUND = WOUND_R[2]
WOUND_LO = WOUND_R[1]
CLEAR = (0, 0, 0, 0)

ALLOWED = {CLEAR, INK, INK2, VOID, VOID_DEEP, VOID_LIFT}
ALLOWED.update(ASH_R)
ALLOWED.update(BONE_R)
ALLOWED.update(EMBER_R)
ALLOWED.update(WOUND_R)

# env.png: 8×5 of 64. Rows 0 and 4 stay a Void field (not stamped).
# Rows 1–3 are Start / Combat / NPC. Cols 0–3 floor grit, 4–5 walls.
# Cols 6–7 are a blank Void field (no sigil, no debug gizmo).
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

# Glyphs are 1px masks. '#' body, 'w' wound core, 'b' bone rim (deflect nose).
# Wider than tall, nose to the right, bitten edge so they are not gems.
# Sized to stay readable once the 64px cell scales to ~24px.
COAL = [
    "                       #########                        ",
    "                  ###################                   ",
    "                 #####################                  ",
    "              # #########################               ",
    "             #############################              ",
    "            #################################           ",
    "           ###################################          ",
    "          #####################################         ",
    "         ############################        ###        ",
    "        # ###########################        ####       ",
    "       ##############################        #####      ",
    "       ############################################     ",
    "      ##############################################    ",
    "      ##############################################    ",
    "     #################wwwwwww########################   ",
    "     # ###############wwwwwww########################   ",
    "    ##################wwwwwww#########################  ",
    "   ###################wwwwwww########################## ",
    "  #####      #########wwwwwww########################## ",
    "  #####      ###########################################",
    " ######      ###########################################",
    " ###################################################### ",
    "######################################################  ",
    "#####################################################   ",
    " ############################      ###############      ",
    "   ##########################      ###########          ",
    "       #################################                ",
    "           #######################                      ",
    "                 ###########                            ",
]

COAL_HOT = [
    "                        #########                       ",
    "                   ###################                  ",
    "                  #####################                 ",
    "               # #########################              ",
    "              #############################             ",
    "           ################################             ",
    "          ############################        #         ",
    "         #############################        ##        ",
    "        ##############################        ###       ",
    "       # #########################################      ",
    "      #############################################     ",
    "     ###############################################    ",
    "    #################################################   ",
    "    ####################wwwwwww######################   ",
    "   #####################wwwwwww#######################  ",
    "   # ###################wwwwwww#######################  ",
    "  ######################wwwwwww######################## ",
    "  ##      ##############wwwwwww######################## ",
    " ###      ##############################################",
    "####      ##############################################",
    "####################################################### ",
    "######################################################  ",
    " ##################################################     ",
    "    ######################      ###############         ",
    "        ##################      #########               ",
    "            #######################                     ",
    "                #############                           ",
    "                    #####                               ",
]

COAL_BONE = [
    "                       #########                        ",
    "                  ###################                   ",
    "                 #####################                  ",
    "              # #########################               ",
    "             #############################              ",
    "            #################################           ",
    "           ###################################          ",
    "          #####################################         ",
    "         ############################        ###        ",
    "        # ###########################        ####       ",
    "       ##############################        #####      ",
    "       ############################################     ",
    "      ##############################################    ",
    "      ##############################################    ",
    "     ###############wwwwwww##########################   ",
    "     # #############wwwwwww##########################   ",
    "    ################wwwwwww##########################b  ",
    "   #################wwwwwww##########################bb ",
    "  #####      #######wwwwwww##########################bb ",
    "  #####      ########################################bbb",
    " ######      ########################################bbb",
    " ####################################################bb ",
    "#####################################################b  ",
    "#####################################################   ",
    " ############################      ###############      ",
    "   ##########################      ###########          ",
    "       #################################                ",
    "           #######################                      ",
    "                 ###########                            ",
]

BONE_CHIP = [
    "          ######################                  ",
    "       ########################                   ",
    "      ##########################                  ",
    "     #######################################      ",
    "    #########################################     ",
    "   # #########################################    ",
    "  #############################################   ",
    "  ##############################################  ",
    " ################################################ ",
    " ################################################ ",
    "##################    wwwwwww#####################",
    " # ###############    wwwwwww#################### ",
    "##################    wwwwwww#####################",
    " #####################wwwwwww#################### ",
    " #####################wwwwwww#################### ",
    "  ##############################################  ",
    "  #############################################   ",
    "   # #########################################    ",
    "            #################################     ",
    "             ###############################      ",
    "            #############################         ",
    "            #########################             ",
    "              #################                   ",
]

BONE_BOSS = [
    "            ######################                   ",
    "         # ######################                    ",
    "        ##########################                   ",
    "     ###########################################     ",
    "    #############################################    ",
    "   ###############################################   ",
    "  #################################################  ",
    "  # ###############################################  ",
    " ################################################### ",
    " ################################################### ",
    "####################      ###########################",
    " ###################      ########################## ",
    "####################      wwwwwww####################",
    " # #####################wwwwwwwww################### ",
    " #######################wwwwwwwww################### ",
    "  ######################wwwwwwwww##################  ",
    "  ######################wwwwwwwww##################  ",
    "   ###############################################   ",
    "    ##        #################################      ",
    "     #         ###############################       ",
    "              #############################          ",
    "              #######################                ",
    "              #################                      ",
]

ASH_TEAR = [
    "#########                                            ",
    " #############                                       ",
    "###############                                      ",
    " ###################                                 ",
    "#####################                                ",
    " # #######################                           ",
    "  #########################                          ",
    "   #############################                     ",
    "  ############      #############                    ",
    "   ###########      ################                 ",
    "    ##########      #################                ",
    "     # #################################             ",
    "      ##################wwwwwww##########            ",
    "       #################wwwwwww#############         ",
    "        ################wwwwwww##############        ",
    "         ###############wwwwwww#################     ",
    "          ##############wwwwwww##################    ",
    "           # #####################################   ",
    "            #######################################  ",
    "             ####################################### ",
    "              ########################      #########",
    "                ######################      #########",
    "                    ###############################  ",
    "                        #######################      ",
    "                            #############            ",
    "                                #####                ",
]

ASH_TEAR_LONG = [
    "#############                                            ",
    " # ###############                                       ",
    "###################                                      ",
    " #######################                                 ",
    "#########################                                ",
    " #############################                           ",
    "  #############################                          ",
    "   # ###############################                     ",
    "    ##############      #############                    ",
    "     #############      ##################               ",
    "      ############      ###################              ",
    "       #######################################           ",
    "        #######################################          ",
    "         # #######################################       ",
    "          ################wwwwwww##################      ",
    "           ###############wwwwwww#####################   ",
    "              ############wwwwwww######################  ",
    "                  ########wwwwwww########################",
    "                      ####wwwwwww###########      #######",
    "                          ##################      ###    ",
    "                              ###################        ",
    "                                  #########              ",
    "                                      ###                ",
]

def _glyph_masks(rows: list[str]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    h = len(rows)
    w = max(len(r) for r in rows)
    body = np.zeros((h, w), dtype=bool)
    wound = np.zeros((h, w), dtype=bool)
    bone = np.zeros((h, w), dtype=bool)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in " .":
                continue
            body[y, x] = True
            if ch == "w":
                wound[y, x] = True
            elif ch == "b":
                bone[y, x] = True
    return body, wound, bone


def _edge_dist(mask: np.ndarray) -> np.ndarray:
    dist = np.zeros(mask.shape, dtype=np.uint8)
    cur = mask.copy()
    for d in range(1, 7):
        er = cur.copy()
        er[1:, :] &= cur[:-1, :]
        er[:-1, :] &= cur[1:, :]
        er[:, 1:] &= cur[:, :-1]
        er[:, :-1] &= cur[:, 1:]
        dist[cur & ~er] = d
        cur = er
        if not cur.any():
            break
    dist[cur] = 7
    return dist


def _shade_index(x: int, y: int, dist: int, bw: int, bh: int, n: int, frame: int) -> int:
    """Upper-left light, lower-right shadow, 1px pores. Frame nudges the facet."""
    lit = 0.62 * (1.0 - x / max(bw, 1)) + 0.38 * (1.0 - y / max(bh, 1))
    lit += 0.06 * ((frame % 3) - 1)
    idx = int(round(lit * (n - 1)))
    if (x * 13 + y * 7 + frame) % 17 == 0:
        idx -= 1
    elif (x * 3 + y * 11) % 19 == 0:
        idx += 1
    if dist >= 5 and idx < n - 2:
        idx += 1
    return max(0, min(n - 1, idx))


def _paint_shot(rows: list[str], ramp: tuple, frame: int, hot: bool) -> Image.Image:
    body, wound, bone = _glyph_masks(rows)
    dist = _edge_dist(body)
    gh, gw = body.shape
    ys, xs = np.where(body)
    # Centroid on the cell center so the travel pivot sits in the mass.
    cx = int(round(xs.mean()))
    cy = int(round(ys.mean()))
    ox = 32 - cx + (1 if frame == 2 else 0)
    oy = 32 - cy
    cell = new(64, 64)
    px = cell.load()
    bh = int(ys.max() - ys.min()) + 1
    bw = int(xs.max() - xs.min()) + 1
    minx, miny = int(xs.min()), int(ys.min())
    for y, x in zip(ys, xs):
        d = int(dist[y, x])
        dx, dy = ox + x, oy + y
        if not (0 <= dx < 64 and 0 <= dy < 64):
            continue
        # Two-pixel ink contour, then a warm inner edge. Matches Caim's outline mass.
        if d <= 2:
            px[dx, dy] = INK
            continue
        if d == 3:
            px[dx, dy] = INK2
            continue
        if bone[y, x]:
            use = BONE_R
        elif wound[y, x]:
            use = WOUND_R
        else:
            use = ramp
        idx = _shade_index(x - minx, y - miny, d, bw, bh, len(use), frame)
        px[dx, dy] = use[idx]
    # Specular chip on the lit shoulder. Moves a pixel per frame.
    lit = []
    for y, x in zip(ys, xs):
        if dist[y, x] < 4 or wound[y, x] or bone[y, x]:
            continue
        if x > minx + bw * 0.45 or y > miny + bh * 0.45:
            continue
        lit.append((x + y, x, y))
    lit.sort()
    for i, (_k, x, y) in enumerate(lit[:5]):
        dx, dy = ox + x + (frame % 2), oy + y + (1 if frame == 3 else 0)
        if 0 <= dx < 64 and 0 <= dy < 64 and px[dx, dy][3] == 255 and px[dx, dy] != INK:
            px[dx, dy] = ramp[-1] if i < 2 else ramp[-2]
    if hot and frame % 2 == 1:
        # A single mote on the nose, still attached to the ink.
        nose = max(zip(xs, ys))
        dx, dy = ox + nose[0] + 1, oy + nose[1]
        if 0 <= dx < 64 and 0 <= dy < 64:
            px[dx, dy] = EMBER_R[-2]
    return cell


def write_shots() -> None:
    sheet = new(256, 512)
    spec = [
        (COAL, EMBER_R, False),
        (ASH_TEAR, ASH_R, False),
        (BONE_CHIP, BONE_R, False),
        (ASH_TEAR_LONG, ASH_R, False),
        (BONE_BOSS, BONE_R, False),
        (COAL_HOT, EMBER_R, True),
        (BONE_CHIP, BONE_R, False),
        (COAL_BONE, EMBER_R, False),
    ]
    for row, (glyph, ramp, hot) in enumerate(spec):
        for col in range(4):
            cell = _paint_shot(glyph, ramp, col, hot)
            sheet.paste(cell, (col * 64, row * 64), cell)
    _reject_geometry(sheet)
    # Interior shading has to be more than a flat fill plus an outline.
    for row in range(8):
        cell = sheet.crop((0, row * 64, 64, row * 64 + 64))
        colors = cell.getcolors(256)
        nunq = len([c for _n, c in colors if c[3] > 0]) if colors else 0
        if nunq < 8:
            raise SystemExit(f"shot row {row} too flat ({nunq} colors)")
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
        if (ys.max() - ys.min()) < 20:
            raise SystemExit(f"shot row {row} is too small to shade")
        if row in (0, 1, 3, 5, 7):
            if (xs.max() - xs.min()) <= (ys.max() - ys.min()):
                raise SystemExit(f"shot row {row} is not a directional shard/tear")


# ---------------------------------------------------------------------------
# Walls / floors — 64px cells, 32px Ash blocks, Void grit.
# ---------------------------------------------------------------------------

def brick_at(x: int, y: int, seed: int = 0) -> tuple:
    """32px Ash block. Odd courses shift 16 so a 64px tile has no seam.

    The joint is a 2px ink contour (Caim's outline weight). The face is hard
    shade bands plus 1px pores, not a flat fill with a highlight strip.
    """
    course = y // 32
    shift = 16 if course % 2 else 0
    sx = (x + shift) % 32
    ly = y % 32
    bx = (x + shift) // 32
    by = course
    h = (bx * 73856093 ^ by * 19349663 ^ seed * 83492791) & 0xFFFFFFFF
    if sx >= 30 or ly >= 30:
        if (sx + ly + (h & 7)) % 6 == 0:
            return INK2
        if (sx * 3 + ly + bx) % 11 == 0:
            return ASH_R[0]
        return INK
    lx = sx
    bias = int(h % 5) - 2
    if ly < 5:
        band = 6
    elif ly < 12:
        band = 5
    elif ly < 20:
        band = 4
    else:
        band = 2
    if lx < 5:
        band += 1
    elif lx > 23:
        band -= 2
    band += bias
    nse = lx * 13 + ly * 7 + (h & 31) + seed
    if nse % 7 == 0:
        band -= 1
    elif nse % 11 == 0:
        band += 1
    if (ly <= 1 or lx <= 1) and (lx + ly + (h % 3)) % 4 != 0:
        band = 7
    if lx >= 27 and ly >= 27:
        return ASH_R[0]
    if (lx >= 28 or ly >= 28) and (lx + ly) % 3 != 0:
        band = 0
    band = max(0, min(len(ASH_R) - 1, band))
    if (h % 4) == 0:
        crack = 7 + (h % 12)
        jag = 1 if ((ly + h) % 6) == 0 else 0
        if lx == crack + jag and 4 < ly < 26:
            return WOUND_R[1 + (ly // 8) % 3]
        if lx == crack + jag + 1 and 4 < ly < 26 and (ly % 2) == 0:
            return ASH_R[0]
    if (h % 9) == 1 and lx > 21 and ly > 21:
        return VOID if (lx + ly) % 2 == 0 else ASH_R[0]
    if nse % 29 == 0 and 6 < lx < 24 and 6 < ly < 24:
        return ASH_R[1]
    return ASH_R[band]


def paint_bricks(img: Image.Image, rect: tuple, seed: int = 0) -> None:
    x0, y0, x1, y1 = rect
    px = img.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = brick_at(x, y, seed)


def _ember_mote(px, ox: int, oy: int, shape: list) -> None:
    """Small ember cluster. Ink edge, two lit steps. Not a single star pixel."""
    n = len(shape)
    for i, (dx, dy) in enumerate(shape):
        x, y = ox + dx, oy + dy
        if not (1 <= x < TILE - 1 and 1 <= y < TILE - 1):
            continue
        if i == n - 1:
            col = INK
        elif i == 0:
            col = EMBER_R[5]
        else:
            col = EMBER_R[3]
        px[x, y] = col


def floor_cell(variant: int, theme: int) -> Image.Image:
    """Dark Wound field. Four variants differ by 1px Ash grit and two ember motes.

    No Void pores. Those read as a star field.
    """
    cell = new(TILE, TILE, WOUND)
    px = cell.load()
    ash = {
        0: [(12, 18), (13, 40), (27, 9), (28, 51), (41, 22), (44, 47), (55, 14), (19, 58), (36, 33), (8, 29)],
        1: [(16, 12), (22, 46), (33, 20), (38, 55), (49, 11), (52, 37), (9, 50), (27, 28), (58, 24), (14, 35)],
        2: [(11, 44), (18, 15), (24, 57), (31, 26), (39, 8), (46, 41), (53, 19), (7, 33), (29, 48), (57, 52)],
        3: [(10, 22), (17, 51), (23, 8), (30, 38), (37, 16), (43, 56), (50, 27), (56, 44), (20, 33), (34, 48)],
    }
    for x, y in ash[variant]:
        px[x, y] = ASH
    # Theme only nudges the second mote so rows are not a copy, still Wound.
    nudge = (theme % 3) - 1
    motes = {
        0: [((20, 24), [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0)]), ((48, 40), [(0, 0), (1, 0), (0, 1), (-1, 0)])],
        1: [((18, 36), [(0, 0), (1, 0), (1, 1), (0, 1)]), ((46, 18), [(0, 0), (1, 0), (2, 1), (1, 1), (0, 1)])],
        2: [((26, 14), [(0, 0), (1, 0), (0, 1), (1, 1)]), ((42, 46), [(0, 0), (-1, 0), (0, 1), (1, 1), (0, 2)])],
        3: [((15, 28), [(0, 0), (1, 0), (2, 0), (1, 1)]), ((50, 34), [(0, 0), (1, 0), (0, 1), (1, 1)])],
    }
    for i, ((ox, oy), shape) in enumerate(motes[variant]):
        _ember_mote(px, ox + (nudge if i else 0), oy, shape)
    return cell


def write_env() -> None:
    sheet = new(ENV_COLS * TILE, ENV_ROWS * TILE, VOID)
    for row in range(ENV_ROWS):
        theme = row
        for col in range(4):
            sheet.paste(floor_cell(col, theme), (col * TILE, row * TILE))
        wall = new(TILE, TILE, VOID)
        paint_bricks(wall, (0, 0, TILE, TILE), seed=1)
        sheet.paste(wall, (4 * TILE, row * TILE))
        chipped = new(TILE, TILE, VOID)
        paint_bricks(chipped, (0, 0, TILE, TILE), seed=4)
        sheet.paste(chipped, (5 * TILE, row * TILE))
    # Cols 6–7 stay the Void field. No circle, tick, or selection box.
    _reject_checker(sheet)
    _reject_gizmos(sheet)
    assert_palette(sheet, "env")
    sheet.save(SPR / "env.png")


def _reject_checker(sheet: Image.Image) -> None:
    """Floor is a Wound field. Variants may not checker, and Void pores are a star field."""
    a = np.array(sheet)
    wound = np.array(WOUND[:3], dtype=np.uint8)
    means = []
    for col in range(4):
        for row in (1, 2, 3):
            cell = a[row * TILE:(row + 1) * TILE, col * TILE:(col + 1) * TILE]
            rgb = cell[:, :, :3]
            means.append(float(rgb.mean()))
            wound_frac = float(np.all(rgb == wound, axis=2).mean())
            if wound_frac < 0.97:
                raise SystemExit(f"floor r{row}c{col} is not a Wound field ({wound_frac:.3f})")
            # Blue-gray specks (Void lift) are the banned galaxy.
            stars = (rgb[:, :, 2] > rgb[:, :, 0] + 4) & (rgb[:, :, 2] > 16)
            if int(stars.sum()) > 0:
                raise SystemExit(f"floor r{row}c{col} has star specks")
            ash_n = int(np.all(rgb == np.array(ASH[:3], dtype=np.uint8), axis=2).sum())
            if not 6 <= ash_n <= 16:
                raise SystemExit(f"floor r{row}c{col} ash grit {ash_n} (want a few 1px marks)")
    if max(means) - min(means) > 8:
        raise SystemExit(f"floor variants diverge like a checker: {means}")
    wall = a[TILE:TILE * 2, 4 * TILE:5 * TILE]
    if wall[:, :, :3].mean() < 50:
        raise SystemExit("wall tile does not read as Ash block")
    wcolors = {tuple(p) for p in wall.reshape(-1, 4)}
    if len(wcolors) < 8:
        raise SystemExit(f"wall tile too flat ({len(wcolors)} colors)")


def _reject_gizmos(sheet: Image.Image) -> None:
    """Cols 6–7 are a blank Void field. No cell may be a ring or a hollow box."""
    a = np.array(sheet)
    void = np.array(VOID, dtype=np.uint8)
    for col in (6, 7):
        block = a[:, col * TILE:(col + 1) * TILE]
        expect = np.broadcast_to(void, block.shape)
        if not np.array_equal(block, expect):
            raise SystemExit(f"env col {col} still has a mark — strip the gizmo")
    for row in range(ENV_ROWS):
        for col in range(ENV_COLS):
            cell = a[row * TILE:(row + 1) * TILE, col * TILE:(col + 1) * TILE]
            _reject_cell_gizmo(cell, row, col)


def _reject_cell_gizmo(cell: np.ndarray, row: int, col: int) -> None:
    rgb = cell[:, :, :3]
    mark = np.any(rgb != np.array(VOID[:3], dtype=np.uint8), axis=2) & (cell[:, :, 3] > 0)
    n = int(mark.sum())
    if n < 24 or n > 700:
        return
    ys, xs = np.where(mark)
    cx, cy = float(xs.mean()), float(ys.mean())
    r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    if float(r.mean()) > 8 and float(r.std()) < 2.2:
        raise SystemExit(f"env r{row}c{col} is a ring gizmo")
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    if x1 - x0 < 12 or y1 - y0 < 12:
        return
    border = mark.copy()
    border[y0 + 2:y1 - 1, x0 + 2:x1 - 1] = False
    if y1 - y0 <= 4 or x1 - x0 <= 4:
        return
    interior = int(mark[y0 + 2:y1 - 1, x0 + 2:x1 - 1].sum())
    if int(border.sum()) / n > 0.82 and interior < n * 0.08:
        raise SystemExit(f"env r{row}c{col} is a box gizmo")


def _wound_crack(img: Image.Image, x: int, y: int, dx: int, dy: int, n: int) -> None:
    px = img.load()
    wob = (0, 1, 0, -1, 1, 0, -1, 0)
    w, h = img.size
    for i in range(n):
        j = wob[i % len(wob)]
        xx = x + dx * i + (j if dy != 0 else 0)
        yy = y + dy * i + (j if dx != 0 and dy == 0 else 0)
        col = WOUND_R[2] if i % 2 == 0 else WOUND_R[3]
        if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] == 255:
            px[xx, yy] = col
        nx = xx + (0 if dx else 1)
        ny = yy + (1 if dx else 0)
        if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255 and px[nx, ny] not in WOUND_R:
            px[nx, ny] = WOUND_R[0]


def _ember_plate(img: Image.Image, cx: int, cy: int, pw: int, ph: int) -> None:
    """Ember plate with an ink edge, a shade ramp, and a wound fissure plus AO."""
    px = img.load()
    x0, y0 = cx - pw // 2, cy - ph // 2
    for y in range(ph):
        for x in range(pw):
            if x < 2 or y < 2 or x >= pw - 2 or y >= ph - 2:
                col = INK if (x + y) % 4 else INK2
            else:
                lit = 0.58 * (1 - (x - 2) / max(pw - 4, 1)) + 0.42 * (1 - (y - 2) / max(ph - 4, 1))
                idx = int(round(lit * (len(EMBER_R) - 1)))
                if (x * 7 + y * 3) % 8 == 0:
                    idx -= 1
                elif (x * 5 + y) % 13 == 0:
                    idx += 1
                idx = max(0, min(len(EMBER_R) - 1, idx))
                col = EMBER_R[idx]
            px[x0 + x, y0 + y] = col
    for i, x in enumerate(range(pw // 5, pw - pw // 5)):
        yy = ph // 2 + (1 if i % 4 == 0 else 0) - (1 if i % 5 == 0 else 0)
        for t, col in ((-1, WOUND_R[0]), (0, WOUND_R[2]), (1, WOUND_R[1])):
            py = y0 + yy + t
            px_x = x0 + x
            if 0 <= px_x < img.size[0] and 0 <= py < img.size[1]:
                px[px_x, py] = col


def _fire_tongues(px, cx: int, cy: int, pw: int, ph: int) -> None:
    """2–4px Ember tongues sitting on the top edge of the plate."""
    x0 = cx - pw // 2
    y_top = cy - ph // 2
    slots = (pw // 5, pw * 2 // 5, pw * 3 // 5, pw * 4 // 5)
    heights = (3, 4, 2, 3)
    for i, sx in enumerate(slots):
        height = heights[i]
        tip = x0 + sx
        for dy in range(height):
            yy = y_top - 1 - dy
            half = 1 if dy < height - 1 else 0
            for dx in range(-half, half + 1):
                xx = tip + dx
                if not (0 <= xx < DOOR_W and 0 <= yy < DOOR_H):
                    continue
                if px[xx, yy][3] == 0:
                    continue
                if abs(dx) == half and half > 0:
                    col = INK
                elif dy == height - 1:
                    col = EMBER_R[6]
                elif dy == 0:
                    col = EMBER_R[4]
                else:
                    col = EMBER_R[5]
                px[xx, yy] = col


def _blood_veins(px, jamb: int) -> None:
    """Wound veins and drips down the inner jambs. Stay on the stone."""
    for inward, x in ((1, jamb - 7), (-1, DOOR_W - jamb + 5)):
        for y in range(14, DOOR_H - 14):
            wob = (0, 0, inward, 0, -inward, 0, inward)[(y // 3) % 7]
            xx = x + wob
            if not (0 <= xx < DOOR_W) or px[xx, y][3] == 0:
                continue
            px[xx, y] = WOUND_R[3] if y % 2 == 0 else WOUND_R[2]
            nx = xx - inward
            if 0 <= nx < DOOR_W and px[nx, y][3] == 255 and px[nx, y] not in WOUND_R:
                px[nx, y] = WOUND_R[0]
            if y % 16 == 8:
                for dy in range(3):
                    for dx in range(-1, 2):
                        bx, by = xx + dx * inward, y + dy
                        if 0 <= bx < DOOR_W and 0 <= by < DOOR_H and px[bx, by][3] == 255:
                            px[bx, by] = WOUND_R[4] if dy == 2 and dx == 0 else WOUND_R[2]


def _bone_inlay(px, x0: int, y0: int, length: int, vertical: bool, gap: int) -> None:
    """3px Bone inlay, broken so it is not a selection rectangle."""
    for i in range(length):
        if (i // 4) % gap == gap - 1:
            continue
        for t in range(3):
            xx = x0 + t if vertical else x0 + i
            yy = y0 + i if vertical else y0 + t
            if not (0 <= xx < DOOR_W and 0 <= yy < DOOR_H):
                continue
            if px[xx, yy][3] == 0:
                continue
            if t == 0:
                col = BONE_R[5] if i % 5 else BONE_R[4]
            elif t == 1:
                col = BONE_R[4] if i % 3 else BONE_R[3]
            else:
                col = BONE_R[1]
            px[xx, yy] = col


def door_cell(kind: str, locked: bool) -> Image.Image:
    cell = new(DOOR_W, DOOR_H, CLEAR)
    jamb = {"start": 44, "combat": 34, "npc": 28, "boss": 42}[kind]
    seed = {"start": 2, "combat": 1, "npc": 3, "boss": 5}[kind]
    paint_bricks(cell, (0, 0, DOOR_W, 10), seed)
    paint_bricks(cell, (0, DOOR_H - 10, DOOR_W, DOOR_H), seed)
    paint_bricks(cell, (0, 0, jamb, DOOR_H), seed)
    paint_bricks(cell, (DOOR_W - jamb, 0, DOOR_W, DOOR_H), seed)
    px = cell.load()
    _bone_inlay(px, 8, 7, DOOR_W - 16, False, 5)
    _bone_inlay(px, 8, DOOR_H - 10, DOOR_W - 16, False, 5)
    _bone_inlay(px, jamb - 3, 8, DOOR_H - 16, True, 4)
    _bone_inlay(px, DOOR_W - jamb, 8, DOOR_H - 16, True, 4)
    _blood_veins(px, jamb)
    if locked:
        paint_bricks(cell, (jamb, 10, DOOR_W - jamb, DOOR_H - 10), seed + 7)
        pw, ph = {"start": (64, 34), "combat": (48, 26), "npc": (40, 22), "boss": (58, 32)}[kind]
        _ember_plate(cell, DOOR_W // 2, DOOR_H // 2 + 2, pw, ph)
        _fire_tongues(px, DOOR_W // 2, DOOR_H // 2 + 2, pw, ph)
        if kind == "boss":
            _wound_crack(cell, jamb + 8, 18, 1, 1, 14)
            _wound_crack(cell, DOOR_W - jamb - 10, DOOR_H - 22, -1, -1, 12)
    else:
        _wound_crack(cell, jamb - 6, 16, 0, 1, 18)
        _wound_crack(cell, DOOR_W - jamb + 4, DOOR_H - 28, 0, 1, 16)
        if kind != "npc":
            _wound_crack(cell, jamb + 2, DOOR_H // 2, 1, 0, 8)
        if kind == "boss":
            _wound_crack(cell, 8, 14, 1, 1, 20)
    colors = cell.getcolors(512)
    nunq = len([c for _n, c in colors if c[3] > 0]) if colors else 0
    if nunq < 10:
        raise SystemExit(f"door {kind} locked={locked} too flat ({nunq} colors)")
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
    open_ember = (oa[:, :, 0] > 180) & (oa[:, :, 1] < 140) & (oa[:, :, 3] == 255)
    if open_ember.sum() > 40:
        raise SystemExit("open door still has an Ember plate")
    wound = (oa[:, :, 0] > 90) & (oa[:, :, 1] < 60) & (oa[:, :, 2] < 50) & (oa[:, :, 3] == 255)
    if wound.sum() < 20:
        raise SystemExit("open door missing Wound on the jambs")
    sheet.save(SPR / "doors.png")




def write_pit() -> None:
    """Round Void mouth, stepped Ash rim, Bone fillet on the inner lip. Fully opaque."""
    VOID = (0x0B, 0x0C, 0x10, 255)
    ASH = (0x5C, 0x5A, 0x56, 255)
    ASH_HI = (0x8A, 0x88, 0x84, 255)
    ASH_MID = (0x45, 0x43, 0x40, 255)
    ASH_LO = (0x32, 0x31, 0x2E, 255)
    ASH_MORT = (0x1A, 0x19, 0x18, 255)
    BONE = (0xE6, 0xD9, 0xC3, 255)
    BONE_DIM = (0xB4, 0xA8, 0x96, 255)
    BONE_SHADE = (0x7A, 0x72, 0x64, 255)
    WOUND = (0x7A, 0x1F, 0x1A, 255)
    WOUND_LO = (0x4A, 0x12, 0x10, 255)
    pit_ok = {
        VOID, ASH, ASH_HI, ASH_MID, ASH_LO, ASH_MORT,
        BONE, BONE_DIM, BONE_SHADE, WOUND, WOUND_LO,
    }
    n = 1024
    a = np.zeros((n, n, 4), dtype=np.uint8)
    a[:, :] = VOID
    cx = cy = n // 2
    # 336px radius → ~84px on screen at scale 0.25, matching the pit trigger.
    hole_r = 336.0
    rim_r = 456.0
    bs = 16
    yy, xx = np.ogrid[:n, :n]
    dx = xx - cx
    dy = yy - cy
    r = np.sqrt(dx.astype(np.float32) ** 2 + dy.astype(np.float32) ** 2)
    bx = np.floor(dx / bs).astype(np.int32)
    by = np.floor(dy / bs).astype(np.int32)
    lx = dx - bx * bs
    ly = dy - by * bs
    bcx = bx * bs + bs // 2
    bcy = by * bs + bs // 2
    br = np.sqrt(bcx.astype(np.float32) ** 2 + bcy.astype(np.float32) ** 2)
    in_block = (br >= hole_r + bs * 0.35) & (br <= rim_r)
    stone = in_block & (r >= hole_r)
    fillet = stone & (r < hole_r + 14.0)
    body = stone & ~fillet
    a[body] = ASH
    mort = body & ((lx >= bs - 2) | (ly >= bs - 2))
    a[mort] = ASH_MORT
    hi = body & ((lx < 2) | (ly < 2)) & ~mort
    a[hi] = ASH_HI
    chip = body & (((bx * 3 + by * 5) % 17) == 0) & (lx > 6) & (ly > 6) & ~mort & ~hi
    a[chip] = ASH_MID
    shade = body & (lx > 10) & (ly > 10) & ~mort & ~hi & ~chip
    a[shade] = ASH_LO
    a[fillet] = BONE_DIM
    a[fillet & ((lx < 4) | (ly < 4))] = BONE
    a[fillet & ((lx >= 10) | (ly >= 10))] = BONE_SHADE
    # Two wound cracks along the rim, following the circle.
    ang = np.arctan2(dy, dx)
    crack_a = (np.abs(((ang - 0.6 + np.pi) % (2 * np.pi)) - np.pi) < 0.18) & stone & (r > hole_r + 20) & (r < hole_r + 70)
    crack_b = (np.abs(((ang + 2.2 + np.pi) % (2 * np.pi)) - np.pi) < 0.14) & stone & (r > hole_r + 24) & (r < hole_r + 80)
    a[crack_a] = WOUND
    a[crack_b] = WOUND_LO
    if int((a[:, :, 3] == 0).sum()) != 0:
        raise SystemExit("pit has transparent pixels")
    void_px = (a[:, :, 0] == VOID[0]) & (a[:, :, 1] == VOID[1]) & (a[:, :, 2] == VOID[2])
    hole = r < hole_r
    if not np.all(void_px[hole]):
        raise SystemExit("pit mouth is not opaque Void")
    if void_px.sum() < n * n * 0.5:
        raise SystemExit("pit field is not a Void field")
    # Round mouth: bbox fill near pi/4. A square mouth fills the box.
    ys, xs = np.where(hole)
    bw = int(xs.max() - xs.min()) + 1
    bh = int(ys.max() - ys.min()) + 1
    fill = float(hole.sum()) / float(bw * bh)
    if abs(bw - bh) > 4 or not (0.74 <= fill <= 0.82):
        raise SystemExit(f"pit mouth is not round (fill={fill:.3f} {bw}x{bh})")
    img = Image.fromarray(a, "RGBA")
    colors = img.getcolors(max(img.size[0] * img.size[1], 1))
    bad = [c for _count, c in colors if c not in pit_ok]
    if bad:
        raise SystemExit(f"pit: off locked palette {bad[:6]}")
    img.save(ENV / "pit.png")


def _ink_stamp(px, x: int, y: int, col, w: int, h: int) -> None:
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = col


def _stroke(px, pts: list, ramp: tuple, thick: int, w: int, h: int) -> None:
    """Hard polyline. Outer pixels are ink, the core walks the ramp."""
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            x = int(round(x0 + (x1 - x0) * s / steps))
            y = int(round(y0 + (y1 - y0) * s / steps))
            for oy in range(-thick, thick + 1):
                for ox in range(-thick, thick + 1):
                    d = max(abs(ox), abs(oy))
                    if d > thick:
                        continue
                    if d == thick:
                        col = INK
                    elif d == thick - 1:
                        col = INK2
                    else:
                        col = ramp[min(len(ramp) - 1, 2 + (thick - d))]
                    _ink_stamp(px, x + ox, y + oy, col, w, h)


def _bolt_cell(frame: int, hot: bool) -> Image.Image:
    """Vertical jagged Ember bolt. Hazard rotates it onto the beam."""
    cell = new(80, 80)
    px = cell.load()
    ramp = EMBER_R[3:] if hot else EMBER_R[1:5]
    x = 40 + (4 if frame % 2 else -3)
    pts = [(x, 6)]
    y = 6
    jags = (0, 11, -13, 8, -9, 12, -6, 7)
    while y < 72:
        y += 8
        jag = jags[((y // 8) + frame) % len(jags)]
        pts.append((40 + jag, min(y, 74)))
    _stroke(px, pts, ramp, 3 if hot else 2, 80, 80)
    # Brand fork near the tail, still a bolt, not a coal blob.
    tail = pts[len(pts) // 2]
    _stroke(px, [tail, (tail[0] + 10, tail[1] + 8), (tail[0] + 6, tail[1] + 16)], ramp, 2, 80, 80)
    return cell


def _ring_cell(frame: int, hot: bool) -> Image.Image:
    """Bone ring, Wound cracks on the outer edge. Center stays clear."""
    cell = new(128, 128)
    px = cell.load()
    cx = cy = 64
    outer = 52
    inner = 38
    for y in range(128):
        for x in range(128):
            d = math.hypot(x - cx, y - cy)
            if d < inner or d > outer:
                continue
            ang = math.atan2(y - cy, x - cx)
            crack = abs(((ang + frame * 0.4) % (math.pi / 3)) - 0.15) < 0.05 and d > outer - 6
            if crack:
                px[x, y] = WOUND_R[3] if hot else WOUND_R[1]
            elif d > outer - 3:
                px[x, y] = INK
            elif d < inner + 2:
                px[x, y] = INK2
            elif d > outer - 7:
                px[x, y] = WOUND_R[2] if ((x + y + frame) % 5 == 0) else BONE_R[2]
            else:
                lit = 1.0 - (d - inner) / (outer - inner)
                idx = 4 if hot else 3
                idx += 1 if lit > 0.65 else 0
                idx -= 1 if lit < 0.3 else 0
                if (x * 3 + y + frame) % 9 == 0:
                    idx -= 1
                px[x, y] = BONE_R[max(1, min(5, idx))]
    return cell


def _plume_cell(frame: int) -> Image.Image:
    """Asymmetric Ember plume. Filled, ink contour, three shade steps."""
    cell = new(64, 64)
    px = cell.load()
    shift = frame % 2
    for y in range(8, 58):
        if y < 20:
            x0 = 34 + shift
            x1 = 50 - (20 - y) // 3
        elif y < 36:
            x0 = 16 + (36 - y) // 5
            x1 = 48 - shift
        else:
            x0 = 12 + shift
            x1 = 40 - (y - 36) // 3
        if x1 - x0 < 4:
            continue
        for x in range(x0, x1):
            edge = x < x0 + 2 or x >= x1 - 2 or y < 10 or y > 55
            if edge:
                col = INK
            elif y < 22:
                col = EMBER_R[6] if (x + frame) % 3 else EMBER_R[5]
            elif y < 40:
                col = EMBER_R[4] if (x + y) % 5 else EMBER_R[3]
            else:
                col = EMBER_R[2]
            if 0 <= x < 64:
                px[x, y] = col
    # Side tongue, attached, leaning up-left so the burst is not a teardrop.
    _stroke(
        px,
        [(22 + shift, 40), (16, 30), (12, 20), (10, 14)],
        EMBER_R[3:],
        2,
        64,
        64,
    )
    return cell


def write_fx() -> None:
    """Boss telegraphs. New silhouettes — not the coal / tear / chip sheet."""
    beam = new(320, 160)
    for row, hot in ((0, False), (1, True)):
        for col in range(4):
            cell = _bolt_cell(col, hot)
            beam.paste(cell, (col * 80, row * 80), cell)
    assert_palette(beam, "fx_beam")
    beam.save(SPR / "fx_beam.png")

    slam = new(512, 256)
    for row, hot in ((0, False), (1, True)):
        for col in range(4):
            cell = _ring_cell(col, hot)
            slam.paste(cell, (col * 128, row * 128), cell)
    assert_palette(slam, "fx_slam")
    # A filled blob would be a shot. The center of the ring stays clear.
    mid = np.array(slam.crop((0, 128, 128, 256)))
    if int((mid[48:80, 48:80, 3] == 0).sum()) < 400:
        raise SystemExit("fx_slam is a filled disk, not a ring")
    bone = (mid[:, :, 0] > 160) & (mid[:, :, 1] > 140) & (mid[:, :, 2] > 110)
    if int(bone.sum()) < 200:
        raise SystemExit("fx_slam missing Bone ring")
    slam.save(SPR / "fx_slam.png")

    wisp = new(256, 64)
    for col in range(4):
        cell = _plume_cell(col)
        wisp.paste(cell, (col * 64, 0), cell)
    assert_palette(wisp, "fx_wisp")
    ember = np.array(wisp.crop((0, 0, 64, 64)))
    hot = (ember[:, :, 0] > 180) & (ember[:, :, 1] < 150) & (ember[:, :, 3] == 255)
    if int(hot.sum()) < 40:
        raise SystemExit("fx_wisp missing Ember plume")
    wisp.save(SPR / "fx_wisp.png")


def write_all() -> None:
    SPR.mkdir(parents=True, exist_ok=True)
    ENV.mkdir(parents=True, exist_ok=True)
    write_shots()
    write_doors()
    write_env()
    write_pit()
    write_fx()
    print(
        "isaac basement sheets:",
        "shots", (SPR / "shots.png").stat().st_size,
        "doors", (SPR / "doors.png").stat().st_size,
        "env", (SPR / "env.png").stat().st_size,
        "pit", (ENV / "pit.png").stat().st_size,
        "fx_beam", (SPR / "fx_beam.png").stat().st_size,
        "fx_slam", (SPR / "fx_slam.png").stat().st_size,
        "fx_wisp", (SPR / "fx_wisp.png").stat().st_size,
    )


if __name__ == "__main__":
    write_all()
