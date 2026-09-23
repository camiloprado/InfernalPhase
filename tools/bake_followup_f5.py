#!/usr/bin/env python3
"""Bake the approved F5 craft into the live sheets.

Drops: Bone/Ember horned heart and Wound/Void skull sit in the item cell.
The halo is the silhouette rim already in the pixels — not a second ring.

Boss FX: four hard silhouette frames each.
  beam  S / Z / wavy brand / trident     4×2 of 96 (warn, hot)
  slam  star / small ring / wide / broken-C   4×2 of 128
  wisp  squash / stretch / flare              4×1 of 64

Shots, Caim, Lilith, and Bebê are not touched.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REF = Path(__file__).resolve().parent / "refs" / "followup-f5"
SPR = ROOT / "assets" / "sprites"
VOID = np.array([11, 12, 16], dtype=np.int16)

# Inclusive pixel boxes on the readable mocks. Caption rows stay outside.
BEAM_FRAMES = (
    (6, 21, 65, 92),
    (75, 21, 137, 90),
    (146, 21, 188, 93),
    (216, 21, 273, 92),
)
SLAM_FRAMES = (
    (13, 41, 59, 87),
    (85, 43, 127, 85),
    (144, 34, 207, 95),
    (216, 34, 273, 94),
)
WISP_FRAMES = (
    (14, 37, 26, 61),
    (49, 49, 71, 61),
    (91, 32, 99, 61),
    (127, 35, 142, 61),
)
DROP_FRAMES = (
    (20, 31, 40, 55),
    (83, 30, 105, 55),
)


def key_void(im: Image.Image) -> np.ndarray:
    a = np.array(im.convert("RGBA"))
    rgb = a[:, :, :3].astype(np.int16)
    dist = np.abs(rgb - VOID).sum(axis=2)
    # Near-void field drops out. Dark ink (8,8,10) stays; its distance is 15.
    a[dist < 12, 3] = 0
    a[dist >= 12, 3] = 255
    return a


def crop(sheet: np.ndarray, box: tuple) -> Image.Image:
    x0, y0, x1, y1 = box
    return Image.fromarray(sheet[y0 : y1 + 1, x0 : x1 + 1].copy(), "RGBA")


def hotten(im: Image.Image) -> Image.Image:
    a = np.array(im)
    fg = a[:, :, 3] > 0
    rgb = a[:, :, :3].astype(np.int16)
    emberish = fg & (rgb[:, :, 0] > rgb[:, :, 1] + 20) & (rgb[:, :, 0] > 80)
    rgb[emberish, 0] = np.minimum(255, rgb[emberish, 0] + 28)
    rgb[emberish, 1] = np.minimum(210, rgb[emberish, 1] + 18)
    a[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    a[~fg, 3] = 0
    return Image.fromarray(a, "RGBA")


def _scaled(im: Image.Image, scale: int) -> Image.Image:
    return im.resize((im.size[0] * scale, im.size[1] * scale), Image.Resampling.NEAREST)


def _paste_row(sheet: Image.Image, frames: list, cell: int, scale: int, row: int) -> None:
    masks = []
    for i, frame in enumerate(frames):
        big = _scaled(frame, scale)
        if big.size[0] > cell or big.size[1] > cell:
            raise SystemExit(f"frame {i} {big.size} does not fit {cell}")
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.paste(big, ((cell - big.size[0]) // 2, (cell - big.size[1]) // 2), big)
        pix = np.array(canvas)
        ink = int((pix[:, :, 3] > 16).sum())
        if ink < 40:
            raise SystemExit(f"frame {i} empty ({ink})")
        masks.append(pix[:, :, 3] > 16)
        sheet.paste(canvas, (i * cell, row * cell), canvas)
    for i in range(len(masks)):
        for j in range(i):
            if np.array_equal(masks[i], masks[j]):
                raise SystemExit(f"row {row} frame {i} silhouette matches frame {j}")


def _load(name: str) -> np.ndarray:
    path = REF / name
    if not path.exists():
        raise SystemExit(f"missing craft ref {path}")
    return key_void(Image.open(path))


def write_aura() -> None:
    src = _load("drops_good_bad_craft_native.png")
    frames = [crop(src, box) for box in DROP_FRAMES]
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    # Native glyphs are ~26px. 2× nearest fills the 64 cell without a free ring.
    _paste_row(sheet, frames, 64, 2, 0)
    sheet.save(SPR / "pickup_aura.png")
    print("aura", sheet.size)


def write_fx() -> None:
    beam_src = _load("fx_beam_readable.png")
    slam_src = _load("fx_slam_readable.png")
    wisp_src = _load("fx_wisp_readable.png")
    beam_frames = [crop(beam_src, box) for box in BEAM_FRAMES]
    slam_frames = [crop(slam_src, box) for box in SLAM_FRAMES]
    wisp_frames = [crop(wisp_src, box) for box in WISP_FRAMES]

    # 1× keeps the ~72px bolts inside the 96 cell. Slam/wisp take a shared 2×
    # so the wide ring and the tall plume fill their cells and the star stays smaller.
    beam = Image.new("RGBA", (384, 192), (0, 0, 0, 0))
    _paste_row(beam, beam_frames, 96, 1, 0)
    _paste_row(beam, [hotten(f) for f in beam_frames], 96, 1, 1)

    slam = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    _paste_row(slam, slam_frames, 128, 2, 0)
    _paste_row(slam, [hotten(f) for f in slam_frames], 128, 2, 1)

    wisp = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    _paste_row(wisp, wisp_frames, 64, 2, 0)

    beam.save(SPR / "fx_beam.png")
    slam.save(SPR / "fx_slam.png")
    wisp.save(SPR / "fx_wisp.png")
    print("fx", beam.size, slam.size, wisp.size)


def write_all() -> None:
    write_aura()
    write_fx()


if __name__ == "__main__":
    write_all()
