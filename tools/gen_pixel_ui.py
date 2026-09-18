#!/usr/bin/env python3
"""Pixel doors/pit using env.png brick + emblem art inside the frames. Hearts/shots stay stamped."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
ENV = ROOT / "assets" / "env"

VOID = (0x0B, 0x0C, 0x10, 255)
VOID_DEEP = (0x04, 0x05, 0x07, 255)
ASH = (0x5C, 0x5A, 0x56, 255)
ASH_DARK = (0x3A, 0x39, 0x36, 255)
BONE = (0xE6, 0xD9, 0xC3, 255)
EMBER = (0xE2, 0x5A, 0x1A, 255)
WOUND = (0x7A, 0x1F, 0x1A, 255)

HEART_FULL = [
    "  ##  ##  ",
    " ######## ",
    "##########",
    "##########",
    " ######## ",
    "  ######  ",
    "   ####   ",
    "    ##    ",
]
HEART_EMPTY = [
    "  ##  ##  ",
    " #      # ",
    "#        #",
    "#        #",
    " #      # ",
    "  #    #  ",
    "   #  #   ",
    "    ##    ",
]
HEART_HIT = [
    "  ##  ##  ",
    " ###  ### ",
    "## #### ##",
    "# ##  ## #",
    " # ## # # ",
    "  #  # #  ",
    "   # #    ",
    "    ##    ",
]
DIAMOND = [
    "    ##    ",
    "   ####   ",
    "  ######  ",
    " ######## ",
    "##########",
    " ######## ",
    "  ######  ",
    "   ####   ",
    "    ##    ",
]
RING = [
    "   ####   ",
    "  #    #  ",
    " #      # ",
    "#        #",
    "#        #",
    " #      # ",
    "  #    #  ",
    "   ####   ",
]


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, w: int, h: int, rgba: bytearray) -> None:
    raw = bytearray()
    row = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * row : (y + 1) * row])
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + _chunk(b"IEND", b"")
    path.write_bytes(png)


def read_png(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    w = h = bit_depth = color_type = interlace = 0
    idat = b""
    pal: bytes | None = None
    trns: bytes | None = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
            bit_depth, color_type = chunk[8], chunk[9]
            interlace = chunk[12]
        elif tag == b"PLTE":
            pal = chunk
        elif tag == b"tRNS":
            trns = chunk
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    if interlace:
        raise SystemExit(f"interlace unsupported: {path}")
    if bit_depth != 8:
        raise SystemExit(f"bit depth {bit_depth} unsupported: {path}")
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    raw = zlib.decompress(idat)
    samples = bytearray(w * h * ch)
    stride = 1 + w * ch
    prev = bytearray(w * ch)
    si = 0
    for y in range(h):
        f = raw[y * stride]
        row = bytearray(raw[y * stride + 1 : (y + 1) * stride])
        if f == 1:
            for x in range(len(row)):
                left = row[x - ch] if x >= ch else 0
                row[x] = (row[x] + left) & 255
        elif f == 2:
            for x in range(len(row)):
                row[x] = (row[x] + prev[x]) & 255
        elif f == 3:
            for x in range(len(row)):
                left = row[x - ch] if x >= ch else 0
                row[x] = (row[x] + ((left + prev[x]) // 2)) & 255
        elif f == 4:
            for x in range(len(row)):
                a = row[x - ch] if x >= ch else 0
                b = prev[x]
                c = prev[x - ch] if x >= ch else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                row[x] = (row[x] + pr) & 255
        elif f != 0:
            raise SystemExit(f"bad png filter {f} in {path}")
        samples[si : si + w * ch] = row
        prev = row
        si += w * ch
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        o = i * 4
        if color_type == 6:
            rgba[o : o + 4] = samples[i * 4 : i * 4 + 4]
        elif color_type == 2:
            rgba[o : o + 3] = samples[i * 3 : i * 3 + 3]
            a = 255
            if trns and samples[i * 3 : i * 3 + 3] == trns[:3]:
                a = 0
            rgba[o + 3] = a
        elif color_type == 0:
            g = samples[i]
            a = 255 if not trns or g != trns[0] else 0
            rgba[o : o + 4] = bytes((g, g, g, a))
        elif color_type == 4:
            g, a = samples[i * 2], samples[i * 2 + 1]
            rgba[o : o + 4] = bytes((g, g, g, a))
        else:
            if pal is None:
                raise SystemExit(f"missing PLTE: {path}")
            idx = samples[i]
            rgba[o : o + 3] = pal[idx * 3 : idx * 3 + 3]
            rgba[o + 3] = trns[idx] if trns and idx < len(trns) else 255
    return w, h, rgba


def put(buf: bytearray, w: int, h: int, x: int, y: int, c: tuple[int, int, int, int]) -> None:
    if 0 <= x < w and 0 <= y < h:
        i = (y * w + x) * 4
        buf[i : i + 4] = bytes(c)


def stamp(buf: bytearray, w: int, h: int, bits: list[str], ox: int, oy: int, scale: int, on) -> None:
    for j, row in enumerate(bits):
        for i, ch in enumerate(row):
            if ch in " .":
                continue
            for yy in range(scale):
                for xx in range(scale):
                    put(buf, w, h, ox + i * scale + xx, oy + j * scale + yy, on)


def _opaque_px(src: bytearray, i: int) -> bytes:
    r, g, b, a = src[i], src[i + 1], src[i + 2], src[i + 3]
    if a < 8 and r + g + b < 12:
        return b"\x00\x00\x00\x00"
    return bytes((r, g, b, 255))


def scale_rgba(src: bytearray, sw: int, sh: int, dw: int, dh: int) -> bytearray:
    out = bytearray(dw * dh * 4)
    for y in range(dh):
        sy = min(y * sh // dh, sh - 1)
        for x in range(dw):
            sx = min(x * sw // dw, sw - 1)
            out[(y * dw + x) * 4 : (y * dw + x) * 4 + 4] = _opaque_px(src, (sy * sw + sx) * 4)
    return out


def content_y_span(env: bytearray, ew: int, eh: int) -> tuple[int, int]:
    miny, maxy = eh, -1
    for y in range(eh):
        base = y * ew * 4
        hit = False
        for x in range(ew):
            i = base + x * 4
            if env[i + 3] > 8 or env[i] + env[i + 1] + env[i + 2] > 24:
                hit = True
                break
        if hit:
            if miny == eh:
                miny = y
            maxy = y
    return miny, maxy


def realign_env(env: bytearray, ew: int, eh: int) -> tuple[bytearray, bool]:
    """Park the 3×3 art on a 3×5 of 64 (rows 1–3) with opaque texels."""
    miny, maxy = content_y_span(env, ew, eh)
    if maxy < 0:
        raise SystemExit("env.png has no opaque art")
    # Already on-grid: first art row occupies y=64..127.
    if miny <= 68 and maxy >= 250:
        return env, False
    height = maxy - miny + 1
    out = bytearray(ew * eh * 4)
    for art_row in range(3):
        y0 = miny + art_row * height // 3
        y1 = miny + (art_row + 1) * height // 3
        th = max(y1 - y0, 1)
        dest_oy = (art_row + 1) * 64
        for col in range(3):
            tile = bytearray(64 * th * 4)
            ox = col * 64
            for y in range(th):
                for x in range(64):
                    si = ((y0 + y) * ew + (ox + x)) * 4
                    tile[(y * 64 + x) * 4 : (y * 64 + x) * 4 + 4] = env[si : si + 4]
            scaled = scale_rgba(tile, 64, th, 64, 64)
            for y in range(64):
                di = ((dest_oy + y) * ew + ox) * 4
                si = y * 64 * 4
                out[di : di + 64 * 4] = scaled[si : si + 64 * 4]
    return out, True


def env_cell(env: bytearray, ew: int, col: int, row: int) -> bytearray:
    cell = bytearray(64 * 64 * 4)
    ox, oy = col * 64, row * 64
    for y in range(64):
        for x in range(64):
            si = ((oy + y) * ew + (ox + x)) * 4
            di = (y * 64 + x) * 4
            cell[di : di + 4] = _opaque_px(env, si)
    return cell


def sample64(cell: bytearray, u: float, v: float) -> bytes:
    u = 0.0 if u < 0.0 else (0.999 if u >= 1.0 else u)
    v = 0.0 if v < 0.0 else (0.999 if v >= 1.0 else v)
    sx = min(int(u * 64), 63)
    sy = min(int(v * 64), 63)
    i = (sy * 64 + sx) * 4
    return bytes(cell[i : i + 4])


def crop_lit(cell: bytearray, sw: int = 64, sh: int = 64, mode: str = "star") -> tuple[bytearray, int, int]:
    def keep(r: int, g: int, b: int, a: int) -> bool:
        if a < 16:
            return False
        if mode == "star":
            return r > 90 and r >= g and r >= b - 10
        if mode == "green":
            return (g > 80 and g >= r - 20) or (r > 100 and r >= g)
        return (r + g + b) > 200 and b >= 80

    minx, miny, maxx, maxy = sw, sh, -1, -1
    for y in range(sh):
        for x in range(sw):
            i = (y * sw + x) * 4
            if not keep(cell[i], cell[i + 1], cell[i + 2], cell[i + 3]):
                continue
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)
    if maxx < 0:
        return cell, sw, sh
    pad = 2
    minx = max(minx - pad, 0)
    miny = max(miny - pad, 0)
    maxx = min(maxx + pad, sw - 1)
    maxy = min(maxy + pad, sh - 1)
    w, h = maxx - minx + 1, maxy - miny + 1
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            si = ((miny + y) * sw + (minx + x)) * 4
            di = (y * w + x) * 4
            out[di : di + 4] = cell[si : si + 4]
    return out, w, h


def blit_in_circle(
    dst: bytearray,
    dw: int,
    dh: int,
    src: bytearray,
    sw: int,
    sh: int,
    cx: int,
    cy: int,
    diam: int,
    skip_dark: bool = False,
) -> None:
    # Uniform scale so a wide env crop is not stretched into a second tile.
    side = max(sw, sh, 1)
    tw = max(int(diam * sw / side), 1)
    th = max(int(diam * sh / side), 1)
    r = diam // 2
    r2 = r * r
    ox = cx - tw // 2
    oy = cy - th // 2
    for y in range(th):
        sy = min(y * sh // th, sh - 1)
        py = oy + y
        for x in range(tw):
            sx = min(x * sw // tw, sw - 1)
            px = ox + x
            if (px - cx) * (px - cx) + (py - cy) * (py - cy) > r2:
                continue
            si = (sy * sw + sx) * 4
            if src[si + 3] < 16:
                continue
            if skip_dark and src[si] + src[si + 1] + src[si + 2] < 28:
                continue
            if 0 <= px < dw and 0 <= py < dh:
                di = (py * dw + px) * 4
                dst[di : di + 4] = src[si : si + 4]


def fill_circle(buf: bytearray, w: int, h: int, cx: int, cy: int, r: int, col) -> None:
    r2 = r * r
    for y in range(max(cy - r, 0), min(cy + r + 1, h)):
        for x in range(max(cx - r, 0), min(cx + r + 1, w)):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
                put(buf, w, h, x, y, col)


def ring_circle(buf: bytearray, w: int, h: int, cx: int, cy: int, ro: int, ri: int, col) -> None:
    ro2, ri2 = ro * ro, ri * ri
    for y in range(max(cy - ro, 0), min(cy + ro + 1, h)):
        for x in range(max(cx - ro, 0), min(cx + ro + 1, w)):
            d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
            if ri2 < d2 <= ro2:
                put(buf, w, h, x, y, col)


def gothic_band(x: int, y: int, cx: int, half: int, y_top: int, y_bot: int, thick: int) -> str:
    spring = y_top + int(half * 1.15)
    r = half * 2
    if y < y_top or y > y_bot:
        return "out"
    if y >= spring:
        dist = abs(x - cx)
        if dist > half:
            return "out"
        if dist > half - thick:
            return "frame"
        return "in"
    d1 = (x - (cx - half)) ** 2 + (y - spring) ** 2
    d2 = (x - (cx + half)) ** 2 + (y - spring) ** 2
    r2 = r * r
    if not (d1 <= r2 and d2 <= r2):
        return "out"
    hi = half - thick
    if hi < 8:
        return "frame"
    d1i = (x - (cx - hi)) ** 2 + (y - spring) ** 2
    d2i = (x - (cx + hi)) ** 2 + (y - spring) ** 2
    ri2 = (hi * 2) ** 2
    if d1i <= ri2 and d2i <= ri2 and y >= y_top + thick:
        return "in"
    return "frame"


def hearts() -> None:
    w, h = 256, 64
    buf = bytearray(w * h * 4)
    cells = [
        (0, HEART_FULL, WOUND),
        (64, HEART_EMPTY, ASH),
        (128, HEART_HIT, BONE),
        (192, DIAMOND, EMBER),
    ]
    for ox, bits, col in cells:
        stamp(buf, w, h, bits, ox + 12, 16 if bits is not DIAMOND else 14, 4, col)
    stamp(buf, w, h, [" ##  ## ", "########", "########", " ###### ", "  ####  ", "   ##   "], 16, 20, 4, EMBER)
    stamp(buf, w, h, ["# #", " # ", "# #"], 152, 28, 4, WOUND)
    write_png(SPR / "hearts.png", w, h, buf)


def shots() -> None:
    w, h = 256, 512
    buf = bytearray(w * h * 4)
    diamond_rows = {0, 1, 4, 5, 7}
    for row in range(8):
        for col in range(4):
            ox, oy = col * 64, row * 64
            if row in diamond_rows:
                stamp(buf, w, h, DIAMOND, ox + 12, oy + 14, 4, EMBER)
            else:
                stamp(buf, w, h, RING, ox + 16, oy + 16, 4, BONE)
    write_png(SPR / "shots.png", w, h, buf)


def doors(env: bytearray, ew: int) -> None:
    cw, ch = 384, 512
    sheet_w, sheet_h = cw * 4, ch * 2
    sheet = bytearray(sheet_w * sheet_h * 4)
    kinds = [
        {"wall": (1, 1), "emblem": (2, 1), "half": 152, "seal": 78},
        {"wall": (1, 2), "emblem": (2, 2), "half": 140, "seal": 62},
        {"wall": (1, 3), "emblem": (2, 1), "half": 140, "seal": 62},
        {"wall": (1, 1), "emblem": (2, 3), "half": 152, "seal": 74},
    ]
    for col, spec in enumerate(kinds):
        wall = env_cell(env, ew, spec["wall"][0], spec["wall"][1])
        floor = env_cell(env, ew, 0, spec["wall"][1])
        emblem = env_cell(env, ew, spec["emblem"][0], spec["emblem"][1])
        for row, locked in enumerate((False, True)):
            cell = bytearray(cw * ch * 4)
            cx, y_top, y_bot = cw // 2, 16, ch - 12
            half, thick, seal_r = spec["half"], 38, spec["seal"]
            inner = max(half - thick, 8)
            seal_y = 328
            for y in range(ch):
                for x in range(cw):
                    band = gothic_band(x, y, cx, half, y_top, y_bot, thick)
                    di = (y * cw + x) * 4
                    if band == "out":
                        continue
                    if band == "frame" or y >= y_bot - 16:
                        wx, wy = x % 64, y % 64
                        si = (wy * 64 + wx) * 4
                        cell[di : di + 4] = wall[si : si + 4]
                        continue
                    cell[di : di + 4] = sample64(floor, (x % 64) / 64.0, (y % 64) / 64.0)
            blit_in_circle(cell, cw, ch, emblem, 64, 64, cx, seal_y, inner * 2 - 8, skip_dark=False)
            for y in range(ch):
                for x in range(cw):
                    if gothic_band(x, y, cx, half, y_top, y_bot, thick) != "frame":
                        continue
                    n_in = 0
                    for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if gothic_band(x + ox, y + oy, cx, half, y_top, y_bot, thick) == "in":
                            n_in += 1
                    if n_in:
                        put(cell, cw, ch, x, y, BONE)
            ring_col = EMBER if locked else BONE
            ring_circle(cell, cw, ch, cx, seal_y, seal_r + 6, seal_r - 4, ring_col)
            ring_circle(cell, cw, ch, cx, seal_y, seal_r - 4, seal_r - 10, ASH_DARK)
            ox, oy = col * cw, row * ch
            for y in range(ch):
                di = ((oy + y) * sheet_w + ox) * 4
                si = y * cw * 4
                sheet[di : di + cw * 4] = cell[si : si + cw * 4]
    write_png(SPR / "doors.png", sheet_w, sheet_h, sheet)


def pit(env: bytearray, ew: int) -> None:
    n = 1024
    buf = bytearray(n * n * 4)
    for i in range(0, n * n * 4, 4):
        buf[i : i + 4] = bytes(VOID)
    wall = env_cell(env, ew, 1, 1)
    emblem = env_cell(env, ew, 2, 1)
    cx = cy = n // 2
    hole, lip_out = 300, 392
    hole2 = hole * hole
    out2 = lip_out * lip_out
    bone2 = (lip_out - 10) * (lip_out - 10)
    for y in range(n):
        for x in range(n):
            d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
            if d2 <= hole2:
                put(buf, n, n, x, y, VOID_DEEP)
            elif d2 <= out2:
                wx, wy = x % 64, y % 64
                si = (wy * 64 + wx) * 4
                di = (y * n + x) * 4
                buf[di : di + 4] = wall[si : si + 4]
                if d2 > bone2:
                    put(buf, n, n, x, y, BONE)
    blit_in_circle(buf, n, n, emblem, 64, 64, cx, cy, hole * 2 - 12, skip_dark=False)
    write_png(ENV / "pit.png", n, n, buf)


def main() -> None:
    hearts()
    shots()
    ew, eh, env = read_png(SPR / "env.png")
    if ew != 192 or eh != 320:
        raise SystemExit(f"env.png want 192x320 got {ew}x{eh}")
    env, shifted = realign_env(env, ew, eh)
    if shifted:
        write_png(SPR / "env.png", ew, eh, env)
    doors(env, ew)
    pit(env, ew)
    print("pixel ui overwritten: env grid=%s door faces + pit mouth from emblem tiles" % ("realigned" if shifted else "ok"))


if __name__ == "__main__":
    main()
