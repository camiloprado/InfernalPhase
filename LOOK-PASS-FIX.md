# Look-pass fix

Aligns the floor to `VISUAL-BRIEF.md`. Gameplay PASS is unchanged: current-room doors only, pit teleport, drops, Concierge, Bebê Chorão deflect, shot bind / stagger / pulse / spin **logic**.

## What was wrong

| Surface | Old read | Locked read |
| --- | --- | --- |
| Doors | Hell pixel skull / lava crests; then a gothic lancet | Flush rectangular Ash doorway in the wall band. Ember plate locked, Wound-cracked jambs open. No wood, no brown, no arch |
| Shots | Soft round Ember dots, then Ember diamond / Bone ring | Drawn coal shard, Ash tear, Bone chip. Hard pixels, not geometry |
| HUD | Horned molten hearts; diamond X-hearts | Circular Bone seals. Full = Bone + Ember glyph. Hit = Wound cracks. Empty = hollow Ash ring |
| Pit | Lava crater PNG with gray partial-alpha (checkerboard leftover) outside the rim | Circular Wound well, stone rim, clear field outside the circle. No black square under the sprite |
| Floor | Hell bricks / checker / brown dungeon, then flat specks | Cracked Wound/Ember rock, four tiles, Ash-block walls. No checker, no stars, no flat fill |
| Palette | Gold heat `#FFBA08`, brown-black ash | Void / Ash / Bone / Ember / Wound only |

## What changed (files)

- `assets/sprites/doors.png` — 4×2 of **256×96** flush Ash frames. Locked row = Ember plate. Open row = clear passage, Wound cracks on the jambs, no Ember.
- `scripts/room.gd` — uniform scale `opening / cell.x` so the 256×96 frame sits on the 64px wall (~32px lip into the room). Floor fill is a Node2D Wound rect under the tiles. The pit sprite has no Void underlay. Floor stamps cycle four cracked columns; walls are cols 4–5.
- `assets/env/pit.png` — circular Wound well. Pixels outside the stone rim are transparent.
- `assets/sprites/shots.png` — coal / tear / chip rows. Not diamonds or rings.
- `assets/sprites/env.png` — 8×5 of 64. Rows 1–3 are Start / Combat / NPC. Void grit, Ash block walls. Columns 6–7 are a blank Void field (no sigil).

## Craft revision (layouts unchanged)

Designer FAIL on the first Pacote A sheets: `env.png`, `doors.png`, and `shots.png` were flat next to Caim / Lilith / Bebê, and `env.png` still had debug gizmos (circle-and-tick, hollow rectangle) in the sigil cells.

- Same cells: doors 4×2 of 256×96, shots 4×8 of 64, floors 8×5 of 64. Pit geometry unchanged.
- Shots, walls, and doors now use a 2px ink contour and hard interior ramps (Ash / Bone / Ember / Wound steps). Floor grit is shaded chips, not single-pixel specks.
- Sigil cells are blank Void and are not stamped, so a scaled empty quad cannot blot the floor.
- `assets/sprites/hearts.png` — circular Bone seals + Ember glyph. Unchanged this pass.
- `scripts/sprites.gd` — look sheets load from PNG bytes on `res://` (not only an OS absolute path) so a missing `.ctex` cannot blank F5. Doors 4×2 of 256×96, hearts 4×1 of 64, shots 4×8 of 64; wrong cell sizes are rejected after a disk retry. Imps / boss / player / cantor / wretch / concierge go through `Sprites.tex` too. A miss prints `SPRITE_BIND FAIL` and asserts. No gameplay-actor `_draw` geometry.
- `assets/sprites/player.png`, `player_f.png`, `baby.png` — character atlases stay pixel bodies. Caim is a masculine adult 4×3 body following the Lilith idle/walk/attack grid (`player.png`). Lilith is `player-female-v2` (`player_f.png`). Bebê is `bebe_sprite` (`baby.png`). Bind **FAIL** if Caim is diamond, female, Bebê, or a square 4×4 void-hood Penitent. `gen_look_pass.py` must not overwrite them. Doors, floor, pit, hearts, and boss FX are baked by `tools/apply_look_v3.py`. `gen_isaac_basement.py` only refreshes shots.

## Designer rec v3

Layouts that already passed stay: shots (coal / tear / chip), door cell 4×2 of 256×96 and flush position, Ash wall masonry, Caim / Lilith / Bebê.

F5 at `9ae9019` was rejected: the pit sat on a black square, door flames were 2–4px, the floor read as a flat Wound fill, hearts were flat seals, drops had no valence, and the boss FX were too small.

## LOOK v3 fail-fix

Baked from the locked refs by `tools/apply_look_v3.py`. `gen_isaac_basement.py` only refreshes shots.

- **Pit** — circular Wound well, stone rim, depth rings. The sheet background is clear, so the floor shows around the rim. No Void square under the sprite quad. On-screen width is about 300px. The fall trigger is a circle inside the stone lip.
- **Doors** — same flush cell. Locked frame is the readable Isaac door: grey stone, Wound drips, Ember flames on the jambs and lintel (thick enough to read), Ember lock plate. Open clears the door face and keeps the lintel flames.
- **Floor** — four 64px cracked Wound/Ember rock tiles. Dark cracks, no stars, no flat `#7A1F1A` fill. Ash walls and blank columns 6–7 stay. The room underlay is still Wound so a missed texel is not a hole.
- **Hearts** — Bone / Ember / Wound ink seals on the 256×64 sheet (full, half, empty, Ember pip).
- **Drops** — `pickup_aura.png` sits behind the icon. Boons use the Bone/Ember ring. A kind that is not a boon uses the Wound/Void X.
- **Boss** — `fx_slam` Ember impact ring, `fx_beam` jagged fork, `fx_wisp` the four polished plume frames. HUD plate is a Void tray, Ember fill, Wound empty, Bone name `THE PHASE` centered.

## Not in this pass

`fx_tele.png` is still the teleport tell. If a hazard sheet is missing, `hazard.gd` may still paint a telegraph. Start-card Penitent chrome stays UI, not a floor actor.
