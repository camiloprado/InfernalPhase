# Infernal Phase — locked look

Designer art direction. Combat numbers, room graph, pit teleport, drops, Concierge, and Bebê Chorão **deflect** do not change. This file is the look contract.

## Palette (only these on combat surfaces)

| Name | Hex | Role |
| --- | --- | --- |
| **Void** | `#0B0C10` | Pit depth, boss tray, overlay, type knockout |
| **Ash** | `#5C5A56` | Wall band, stone door, card chrome |
| **Bone** | `#E6D9C3` | Type, boss name, heart ink, bone-chip shots, good-drop rim |
| **Ember** | `#E25A1A` | Door flames and lock, coal shots, floor cracks, slam ring, bolts, plumes, boss fill |
| **Wound** | `#7A1F1A` | Floor rock, heart cracks, door drips, pit well, boss empty |

No gold, no chrome-edge crests, no `#FFBA08` heat, no brown brick on doors.

## Doors

Rectangular flush doorways in the Ash wall band (Isaac basement, not a gothic arch). Grey stone frame — no wood, no brown. **Locked:** Ember flames on the lintel and jambs, thick enough to read at game size (about 6–10px and up), Wound blood drips, Ember lock plate. **Open:** the door face is clear so the floor shows through; lintel flames and jamb drips stay. Texture top is the room-side lip. Cells are 4×2 of 256×96 so the frame sits on the 64px wall.

## Room

Isaac basement / Sheol, not Cathedral. Wall band is ~32px Ash blocks (two courses in the 64px wall), ink contour and hard interior shade bands in the Ash ramp. Floor is four cracked Wound/Ember rock tiles (dark cracks, Ember in the fissures). No checker, no brown, no wood, no pebbles, no star specks, no flat `#7A1F1A` fill, no floor emblem. Columns 6–7 of `env.png` are a blank Void field — no circle, tick, or selection box.

## Shots

Drawn pixel projectiles. Not diamonds, rings, or ellipses.

- **Ember coal** — player, ember, deflect. Asymmetric shard, wound core, points along travel.
- **Ash tear** — imp, cantor. Stepped tear with a Wound fissure, points along travel.
- **Bone chip** — wretch, boss, bone. Irregular flake with a Wound crack; tumbles.

Hard pixels, same outline weight and interior shade steps as Caim / Lilith / Bebê, Infernal ramp only (shades of the five hues, no new colors). Readable around 12×12.

## HUD

- Hearts: Bone / Ember / Wound ink seals. Full, cracked half, hollow empty. Ember pip stays the HUD glyph.
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

Circular Wound well with a stone rim and depth rings. The sheet outside the circle is transparent, so the cracked floor shows around the rim. There is no black square under the sprite. The fall trigger is a circle inside the stone lip. One clear QA frame.

## Boss FX

New sheets. Not the coal / tear / chip silhouettes. Ink contour and two or three shade steps.

- **Ring slam** `fx_slam.png` — Ember impact ring. Wired to SLAM.
- **Lightning** `fx_beam.png` — jagged Ember fork. Wired to CROSS, DIAG, LANES.
- **Fire** `fx_wisp.png` — four distinct Ember plume frames. Wired to RING.
- **Boss plate** — Void tray with an Ash edge, Ember fill, Wound empty, Bone name `THE PHASE` centered.
