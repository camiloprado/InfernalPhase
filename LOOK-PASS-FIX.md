# Look-pass fix

Aligns the floor to `VISUAL-BRIEF.md`. Gameplay PASS is unchanged: current-room doors only, pit teleport, drops, Concierge, Bebê Chorão deflect, shot bind / stagger / pulse / spin **logic**.

## What was wrong

| Surface | Old read | Locked read |
| --- | --- | --- |
| Doors | Hell pixel skull / lava crests; then a landscape brick house-roof on a gray slab | Portrait gothic Ash **frame** (equilateral lancet), Bone inlay, circular Ember / cracked-Ash seal, transparent outside **and** inside the opening |
| Shots | Soft round Ember dots / fireball orbs | Ember diamond + Bone ring only, hard edges |
| HUD | Horned molten hearts; diamond X-hearts | Circular Bone seals. Full = Bone + Ember glyph. Hit = Wound cracks. Empty = hollow Ash ring |
| Pit | Lava crater PNG with gray partial-alpha (checkerboard leftover) outside the rim | Void-deep filled mouth, thin Ash lip, 1px Bone hairline, **alpha 0** outside. Node2D floor + Void underlay so transparency cannot punch to the viewport |
| Palette | Gold heat `#FFBA08`, brown-black ash | Void / Ash / Bone / Ember / Wound only |

## What changed (files)

- `assets/sprites/doors.png` — 4×2 of **384×512** gothic frames (same atlas layout as before). Locked row = Ember seal. Open row = cracked Ash/Void, no Ember, no demonic face.
- `scripts/room.gd` — uniform scale `opening / cell.x` so the portrait arch sits on the 64px wall and rises into the room (~200×267). Floor fill is a Node2D Void rect (not a Control ColorRect). Pit has an opaque Void underlay disk under the sprite.
- `assets/env/pit.png` — opaque Void hole, thin Ash/Bone lip, corners alpha 0 (the hell sheet had gray `216,216,216,105` in the corners).
- `assets/sprites/shots.png` — diamond + ring rows only.
- `assets/sprites/hearts.png` — circular Bone seals + Ember diamond glyph.
- `tools/gen_look_pass.py` — source for the sheets.

## Not in this pass

Enemy character sheets, boss VFX tiles, Concierge / cantor / wretch placeholders, pickup sheets. Those keep fail-soft sprites; combat HUD and projectiles follow the brief.
