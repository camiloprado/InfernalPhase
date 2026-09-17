# Infernal Phase

One infernal floor. No campaign. You walk a small graph of hell-rooms, dodge patterned bullets, and either kill **The Infernal Phase** or get filed as ash and start over.

Top-down move-and-shoot in the Binding of Isaac room style, with Undertale-ish bullet patterns and short dark-humor lines. Caim / Lilith, Bebê Chorão, Ember Imps, Ring Wretches, Ash Cantors, the Concierge, and **The Infernal Phase** bind pixel character sheets. Doors, hearts, shots, and the pit keep the locked Bone / Ash / Ember look. Hell palette in `VISUAL-BRIEF.md`: Void `#0B0C10`, Ash `#5C5A56`, Bone `#E6D9C3`, Ember `#E25A1A` (accent), Wound `#7A1F1A`. See `LOOK-PASS-FIX.md` for the look-pass delta.

## Open in Godot 4

1. Install **Godot 4.x** (built and tested with **4.7.2**; 4.3+ should open it). Standard build, not .NET.
2. After a pull on a new machine (or if sprites/audio fail to load), wipe the import cache and rebuild it **before** F5:

```bash
rm -rf .godot
godot --path . --import
```

Stale `.godot/imported/*.ctex` from an older branch will 404 even when the PNGs on disk are fine. **F5 binds pixel sheets from the PNG bytes** (`res://` FileAccess + `load_png_from_buffer`). A missing sheet prints `SPRITE_BIND FAIL` and asserts — it does **not** fall back to vector diamonds, robes, or gothic frames. Look cells stay locked: doors 4×2 of 384×512, hearts 4×1 of 64, shots 4×8 of 64. `--qa-look` / `--qa-proof` print `QA_ASSERT player_sheet= enemy_art= doors= hearts= ok=` so a missing Caim coat or robe cantor is a bind miss (`ok=0`), not a `_draw` mask.
3. The project is **GL Compatibility** (OpenGL), not Forward+. If the editor ever rewrites `project.godot` to Forward+, the window can go blank on Linux — switch Renderer back to Compatibility, or run `godot --path . --rendering-method gl_compatibility`.
4. Press **F5** (or Run Project).

Floors use `assets/sprites/env.png` (pixel tiles) over a Void fill. Doors are `doors.png` (gothic Ash arches, Bone inlay, Ember / cracked seals). **Caim** and **Lilith** are the `player-female-v2` 4×3 body sheet (`player.png` / `player_f.png`) — not the look-pass Penitent diamond. A male Caim sheet is not on disk yet, so Caim temporarily shares the female body. Bebê Chorão is a difficulty **mode**; its sprite is `baby.png` (from `bebe_sprite`). Imps and the boss stay on `assets/characters/`. Cantors, wretches, the Concierge, hearts, pickups, and shots use `assets/sprites/`. If a gameplay sheet is missing, the load errors — no drawn placeholder. A Penitent-geometry player/baby atlas also fails bind (`is_character_body`).

The main scene is `scenes/floor.tscn`.

Command line from this folder:

```bash
godot --path .
```

If the editor is already open, F5 is enough. After a pull, let Godot finish importing (`assets/characters/`, `assets/env/pit.png`, `assets/sprites/baby.png`, the two oggs) before F5.

## Play

- **WASD** or left stick: move
- **Mouse**: aim · **Left click** / **Space** / **J**: shoot
- **Arrow keys**: shoot that way (with WASD, this is dual-stick on a keyboard; arrows alone move and fire)
- **Right stick**: aim and fire
- **R** or **Enter**: restart the floor (also after death or the win card). **Enter does not confirm the start card.**

At the Threshold, pick **Caim** or **Lilith** (same hearts, speed, and fire rate — only the silhouette changes) and a difficulty. The start card face is the **Penitent**. Ember is only on **Swear In**.

| Label | What |
| --- | --- |
| **Bebê Chorão** | Enemy bullets bounce off. Player keeps Penitent language. BGM is a choro-de-criança loop. Melee and pits still hurt. |
| **Normal** | Caim or Lilith silhouette, usual floor pulse. Combat unchanged. |

The last pair stays highlighted on restart. HUD shows `Caim · Normal` or `Lilith · Normal`, or just **Bebê Chorão**.

Four hearts (vessel drops can raise the cap to six). Hit = a short invuln blink, not a vacation. Trash enemies drop about half the time: brimstone hearts, ember (damage-up), rare vessel (max-heart), or a shot mod (pierce / rapid / heavy / burn). Drops pulse so they read on the ash floor. Only the **current room** draws and collides its door arches; a neighbor never stamps a second frame into the shared opening. Arches are portrait gothic frames (384×512 cells) scaled uniformly to the 200px opening and sat on the 64px wall so the crown faces into the room. The Threshold pit is a Void-deep mouth with a thin Ash lip and a 1px Bone hairline — outside the lip is opaque Void, and a Void underlay covers the full sprite quad so the hole never shows checkerboard. Doors stay shut until the room is clear. Die and the floor rewinds. Beat the boss for a short ending, then restart if you want it again.

The Threshold has a **buraco** (Void hole, thin Ash/Bone lip — not a reused floor tile). Step in and you **drop** — teleport to the deep south room. No heart loss on the drop. The boss RING special is a fire-wisp annulus with a safe inner disk and **no pit**.

## The floor

Nine rooms on a grid:

| Room | What |
| --- | --- |
| **The Threshold** (start) | Open doors, pentagram, Caim/Lilith + difficulty pick, one pit that teleports to Deep |
| Combat rooms | Ember Imps, Ring Wretches, Ash Cantors — pixel shots are an Ember diamond or a Bone ring |
| **The Concierge** | NPC room. Walk up. First visit grants a random item from the drop pool (heart, ember, vessel, or shot mod). Later visits are flavor. No shop. |
| **The Phase** | Boss. Patterned shots, telegraphed teleports, and a random room-scale special each time it loses 20% HP (CROSS, DIAG, SLAM, LANES, RING). RING has no pit. |

Reach the boss via the Concierge (east then south) or through the southern combat rooms. The first east room is still an intro cantor plus an imp — slower than later rooms, not a free pass.

## Layout (scenes / scripts)

```
scenes/floor.tscn      Floor graph, camera, spawns
scenes/player.tscn     Heart-HP mover
scenes/bullet.tscn     Linear / sine / spiral shots
scenes/enemy.tscn      3 types + boss
scenes/room.tscn       Walls, doors, decorations
scenes/npc.tscn        Concierge
scenes/ui.tscn         Hearts, flavor lines, minimap, death/win
assets/characters/imp  Walk + attack sheets (vanilla, sword, sword-shield, pitchfork, pitchfork-shield)
assets/characters/boss Idle / move / fire / lightning frame sheets (not raw GIF playback)
assets/env/pit.png     Buraco — distinct pit sprite (not a floor/wall tile)
assets/sprites/         env, doors, player, player_f, baby, hearts, pickups, skills, cantor, wretch, concierge
assets/sprites/shots.png        Projectile atlas (player / imp / wretch / cantor / boss / ember / bone / deflect)
assets/sprites/fx_beam.png      Boss CROSS / DIAG / LANES flame tiles
assets/sprites/fx_slam.png      Boss SLAM nova frames
assets/sprites/fx_ring.png      Ring texture (unused hole — RING stamps fx_wisp)
assets/sprites/fx_wisp.png      RING fire tongues
assets/sprites/fx_tele.png      Boss teleport tell
assets/audio/floor.ogg Usual floor pulse (original)
assets/audio/cry.ogg   Bebê Chorão choro loop (original, not a commercial OST)
```

Out of scope on purpose: extra floors, shops, Steam, mobile, web.

## License

Project code is yours to run and change. Godot Engine is separate (MIT).
