# Look-pass fix

Aligns the floor to `VISUAL-BRIEF.md`. Gameplay PASS is unchanged: current-room doors only, pit teleport, drops, Concierge, Bebê Chorão deflect, shot bind / stagger / pulse / spin **logic**.

## What was wrong

| Surface | Old read | Locked read |
| --- | --- | --- |
| Doors | Hell pixel skull / lava crests; then a landscape brick house-roof on a gray slab | Portrait gothic Ash **frame** (equilateral lancet), Bone inlay, circular Ember / cracked-Ash seal, transparent outside **and** inside the opening |
| Shots | Soft round Ember dots / fireball orbs | Ember diamond + Bone ring only, hard edges |
| HUD | Horned molten hearts; diamond X-hearts | Circular Bone seals. Full = Bone + Ember glyph. Hit = Wound cracks. Empty = hollow Ash ring |
| Pit | Lava crater PNG with gray partial-alpha (checkerboard leftover) outside the rim | Void-deep filled mouth, thin Ash lip, 1px Bone hairline, **opaque Void** outside the lip. Node2D floor + Void underlay covering the **full sprite quad** so no texel punches the viewport |
| Palette | Gold heat `#FFBA08`, brown-black ash | Void / Ash / Bone / Ember / Wound only |

## What changed (files)

- `assets/sprites/doors.png` — 4×2 of **384×512** gothic frames (same atlas layout as before). Locked row = Ember seal. Open row = cracked Ash/Void, no Ember, no demonic face.
- `scripts/room.gd` — uniform scale `opening / cell.x` so the portrait arch sits on the 64px wall and rises into the room (~200×267). Floor fill is a Node2D Void rect (not a Control ColorRect). Pit underlay is an opaque Void rect over the full sprite bounds (not only the mouth disk).
- `assets/env/pit.png` — opaque Void hole, thin Ash/Bone lip, outside-lip pixels opaque Void `#0B0C10` (the hell sheet had gray `216,216,216,105` in the corners; alpha-0 corners punched the F5 checkerboard).
- `assets/sprites/shots.png` — diamond + ring rows only.
- `assets/sprites/hearts.png` — circular Bone seals + Ember diamond glyph.
- `scripts/sprites.gd` — look sheets load from the PNG on disk so a stale `.godot/imported` hell `.ctex` cannot win at F5. Doors 4×2 of 384×512, hearts 4×1 of 64, shots 4×8 of 64; wrong cell sizes are rejected.

## Not in this pass

Enemy character sheets, boss VFX tiles, Concierge / cantor / wretch placeholders, pickup sheets. Those keep fail-soft sprites; combat HUD and projectiles follow the brief.
