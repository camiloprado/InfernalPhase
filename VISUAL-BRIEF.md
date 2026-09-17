# Infernal Phase — locked look

Designer art direction. Combat numbers, room graph, pit teleport, drops, Concierge, and Bebê Chorão **deflect** do not change. This file is the look contract.

## Palette (only these on combat surfaces)

| Name | Hex | Role |
| --- | --- | --- |
| **Void** | `#0B0C10` | Floor, hole, overlay, type knockout |
| **Ash** | `#5C5A56` | Wall band, empty seals, card chrome |
| **Bone** | `#E6D9C3` | Type, inlay, filled seals, diamond body |
| **Ember** | `#E25A1A` | Accent only — locked door seal, shot diamond, one confirm CTA, 4–6px brand |
| **Wound** | `#7A1F1A` | Heart cracks, damage, boss node |

No gold, no chrome-edge crests, no `#FFBA08` heat, no brown brick on doors.

## Doors

Gothic arches flush on the Ash wall band. Thin Bone inlay. Center seal **Ember** when locked, **cracked / dark** when open. Transparent outside the arch. No circular portal on a gray rectangle. First Gate (Threshold) uses the same language with heavier ribs and a huge cracked seal.

## Shots

Two silhouettes only:

- **Ember diamond** — player, imp, ember, boss, deflect
- **Bone ring** — wretch, cantor, bone

Hard edges, readable at 16–24px+. Animation stays inside those two shapes. No soft round Ember dots or tears.

## HUD

- Hearts: circular **Bone** seals. Wound cracks when filled. Empty = Ash.
- Shot glyph: Ember diamond.
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
- Env tiles: `assets/sprites/env.png`

## Pit

Void hole, thin Ash / Bone lip, opaque Void `#0B0C10` outside the lip (never viewport-clear / checkerboard). One clear QA frame.
