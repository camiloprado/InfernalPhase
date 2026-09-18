# Infernal Phase — Cursor agent lock

Godot 4.7.2, **GL Compatibility**. One floor. Main scene: `scenes/floor.tscn`. Run with `./run.sh` or `godot --path . --rendering-method gl_compatibility`.

This file is the Camilo / Designer contract from the pixel-restore work. Do not regress it.

## Characters (in-world)

| Who | Sheet | Layout |
| --- | --- | --- |
| **Caim** | `assets/sprites/player.png` | Masculine adult on the **Lilith 4×3** grid: idle 4 · walk-side 4 · shoot 4. Bind height **64px** (shorter than Ring Wretch). Bone coat, Ember chest brand, pistol. Broader shoulders, jaw, **short / tied hair** (not Lilith length), same boots. Transparent background. |
| **Lilith** | `assets/sprites/player_f.png` | `player-female-v2`. Do not overwrite. |
| **Bebê Chorão** | `assets/sprites/baby.png` | `bebe_sprite`. Difficulty **mode** (deflect), not a walker pick. Do not overwrite. |

**Forbidden for Caim:** pointed Ash void-face hood / Penitent diamond, copying Lilith as `player.png`, Bebê, look-pass geometry. `bc3b5f5` hooded Caim is FAIL-closed.

`Sprites.is_caim_own_body()` must FAIL void-hood (square 4×4), female md5, baby md5, and diamond (too few unique colors). PASS landscape 4×3 male body.

Start-card Penitent diamond is **UI only**, never the floor actor.

## Floors and pit

Combat rooms (**A BAD ROOM**): Void field `#0B0C10` plus ritual circle, Ash walls. **No** tiled `env.png` Isaac dungeon / striped checker.

Threshold pit **teleports** to Deep. After landing, the player must still be the Caim `player.png` sheet (shorter than the Ring Wretch, ~64px class), not the red sword imp. `fall_from` rebinds the sheet.

## Bind rules

- Disk-first `Sprites.tex` (PNG bytes). Missing sheet = `SPRITE_BIND FAIL`, not a polygon.
- Gameplay `_draw` fallbacks **OFF** for player, bullets, hearts, doors, pickup icons, enemy/NPC **bodies**. Hazard telegraph FX may stay if the FX sheet missed (documented in `hazard.gd`).
- Look cells: doors 4×2 of 384×512, hearts 4×1 of 64, shots 4×8 of 64. Diamonds/rings are shots only.

Palette: Void `#0B0C10` Ash `#5C5A56` Bone `#E6D9C3` Ember `#E25A1A` Wound `#7A1F1A`. See `VISUAL-BRIEF.md`.

## Proof

```bash
./run.sh -- --qa-look --qa-proof
```

Need `QA_ASSERT player_sheet=1 player_body=1 caim_own=1 enemy_art=1 doors=1 hearts=1 src=disk ok=1` and `QA_PIT dest_ok=true`. F5 stills land in `gate/`.
