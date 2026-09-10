# Look-pass fix

Aligns the floor to `VISUAL-BRIEF.md`. Gameplay PASS is unchanged: current-room doors only, pit teleport, drops, Concierge, Bebê Chorão deflect, shot bind / stagger / pulse / spin **logic**.

## What was wrong

| Surface | Old read | Locked read |
| --- | --- | --- |
| Doors | Circular portal on a gray rect; brown brick; chrome-edge crests | Gothic Ash arch, Bone inlay, Ember / cracked seal, transparent outside |
| Shots | Soft round Ember dots / tears | Ember diamond + Bone ring only, hard edges |
| HUD | Diamond hearts, Ember frame crests, rect minimap | Bone seals, Ash/Bone frame, circular nodes, Ember diamond glyph |
| Start | Gold chrome, cute Bebé as product face | Penitent (hooded, no face). Ember on one confirm CTA |
| Pit | Gray halo, Ember rim | Void hole, thin Ash/Bone lip, transparent outside |
| Palette | Gold heat `#FFBA08`, brown-black ash | Void / Ash / Bone / Ember / Wound only |

## What changed (files)

- `scripts/palette.gd` — locked five colors. `EMBER_HOT` no longer gold. `WOUND` is the damage red.
- `assets/sprites/doors.png` — gothic arches, First Gate heavier.
- `assets/sprites/shots.png` — diamond + ring rows only.
- `assets/sprites/hearts.png` — circular Bone seals + Ember diamond glyph.
- `assets/sprites/player.png` / `player_f.png` / `baby.png` — Penitent language.
- `assets/env/pit.png` — Void mouth, Ash/Bone lip.
- `assets/sprites/env.png` — Void / Ash, no brown brick band.
- `scripts/room.gd` — Ash wall band, Void floor, gothic fallback, pit fallback without Ember rim.
- `scripts/bullet.gd` — two silhouettes; pulse stays inside the shape.
- `scripts/ui.gd` / `minimap.gd` / `run_pick.gd` / `player.gd` — HUD, start card, Penitent fallbacks.
- `gate/` — full-res stills for doors, shots, HUD, start, pit.

## Not in this pass

Enemy character sheets, boss VFX tiles, Concierge / cantor / wretch placeholders, pickup sheets. Those keep fail-soft sprites; combat HUD and projectiles follow the brief.
