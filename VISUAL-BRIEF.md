# Infernal Phase — locked look

Designer art direction. Combat numbers, room graph, pit teleport, drops, Concierge, and Bebê Chorão **deflect** do not change. This file is the look contract.

## Palette (only these on combat surfaces)

| Name | Hex | Role |
| --- | --- | --- |
| **Void** | `#0B0C10` | Pit mouth, overlay, type knockout |
| **Ash** | `#5C5A56` | Wall band, 1px floor grit, card chrome |
| **Bone** | `#E6D9C3` | Type, inlay, filled seals, bone-chip shots, ring-slam |
| **Ember** | `#E25A1A` | Accent — locked door plate and tongues, coal shots, floor embers, bolts, plumes, one confirm CTA |
| **Wound** | `#7A1F1A` | Floor field, heart cracks, jamb veins, damage, boss node |

No gold, no chrome-edge crests, no `#FFBA08` heat, no brown brick on doors.

## Doors

Rectangular flush doorways in the Ash wall band (Isaac basement, not a gothic arch). Ash stone frame only — no wood, no brown. Bone inlay on the lip and jambs. **Locked:** lit Ember plate with 2–4px Ember fire tongues on the top edge, Wound veins and drips on the jambs. **Open:** clear passage (the floor shows through) and Wound cracks on the jambs, no plate. Texture top is the room-side lip. Cells are 4×2 of 256×96 so the frame sits on the 64px wall.

## Room

Isaac basement / Sheol, not Cathedral. Wall band is ~32px Ash blocks (two courses in the 64px wall), ink contour and hard interior shade bands in the Ash ramp. Floor is a dark Wound field `#7A1F1A` with sparse Ember motes and 1px Ash grit (four tile variants). No checker, no brown, no wood, no pebbles, no star specks, no floor emblem. Columns 6–7 of `env.png` are a blank Void field — no circle, tick, or selection box.

## Shots

Drawn pixel projectiles. Not diamonds, rings, or ellipses.

- **Ember coal** — player, ember, deflect. Asymmetric shard, wound core, points along travel.
- **Ash tear** — imp, cantor. Stepped tear with a Wound fissure, points along travel.
- **Bone chip** — wretch, boss, bone. Irregular flake with a Wound crack; tumbles.

Hard pixels, same outline weight and interior shade steps as Caim / Lilith / Bebê, Infernal ramp only (shades of the five hues, no new colors). Readable around 12×12.

## HUD

- Hearts: circular **Bone** seals. Wound cracks when filled. Empty = Ash.
- Shot glyph on the heart sheet stays the Ember pip. Projectile art is the coal / tear / chip sheet, not that pip.
- Map: circular nodes. Current room = Bone ring. No Ember on the frame.
- Combat HUD has no Shop / Inventory / Score / Armor strip.
- Frame Ash / Bone only.

## Start card

Default face is the **Penitent**: hooded, no face, Bone diamond top-down, 4–6px Ember brand. Void field, Bone type. Ember only on the one confirm CTA. Bebê Chorão stays a difficulty **mode** (deflect). It is not the product face.

## Actors (F5 floor)

Combat actors bind pixel sheets. Do not replace these PNGs with Penitent diamonds or vector `_draw` geometry. A miss is `SPRITE_BIND FAIL`, not a polygon.

- Caim / Lilith: `assets/sprites/player.png`, `player_f.png`
- Bebê Chorão sprite: `assets/sprites/baby.png`
- Imp / boss: `assets/characters/imp/`, `assets/characters/boss/`
- Wretch / cantor / concierge: `assets/sprites/wretch.png`, `cantor.png`, `concierge.png`
- Env tiles: `assets/sprites/env.png` (8×5 of 64; themes on rows 1–3)

## Pit

Round mouth (not a square), stepped Ash-block rim, Bone fillet on the inner lip, opaque Void `#0B0C10` inside the mouth and outside the rim (never viewport-clear / checkerboard). One or two Wound cracks on the rim. One clear QA frame.

## Boss FX

New sheets. Not the coal / tear / chip silhouettes. Ink contour and two or three shade steps.

- **Ring slam** `fx_slam.png` — expanding Bone ring, Wound cracked outer edge. Wired to SLAM.
- **Lightning** `fx_beam.png` — jagged Ember bolt. Wired to CROSS, DIAG, LANES.
- **Fire** `fx_wisp.png` — asymmetric Ember plume. Wired to RING.
