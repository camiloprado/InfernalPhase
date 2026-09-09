# Infernal Phase

One infernal floor. No campaign. You walk a small graph of hell-rooms, dodge patterned bullets, and either kill **The Infernal Phase** or get filed as ash and start over.

Top-down move-and-shoot in the Binding of Isaac room style, with Undertale-ish bullet patterns and short dark-humor lines. Ember Imps and **The Infernal Phase** use character sheets (`assets/characters/imp/`, `assets/characters/boss/`). Cantors, wretches, cultists, and the Concierge stay as placeholder shapes until those folders get art. Hell palette (ash, ember, bone, void).

## Open in Godot 4

1. Install **Godot 4.x** (built and tested with **4.7.2**; 4.3+ should open it). Standard build, not .NET.
2. In the Project Manager: **Import** → select this folder (`project.godot`) → **Import & Edit**.
3. The project is **GL Compatibility** (OpenGL), not Forward+. If the editor ever rewrites `project.godot` to Forward+, the window can go blank on Linux — switch Renderer back to Compatibility, or run `godot --path . --rendering-method gl_compatibility`.
4. Press **F5** (or Run Project).

Character sheets live in `assets/characters/` (imps, boss). The only file in `assets/sprites/` is the Bebê Chorão walker. Walls, doors, and floors are drawn in-room (not a tileset).

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

At the Threshold, pick **Caim** or **Lilith** (same hearts, speed, and fire rate — only the silhouette changes) and a difficulty:

| Label | What |
| --- | --- |
| **Bebê Chorão** | Enemy bullets bounce off. Player is the **bebê** sprite (not Caim/Lilith). BGM is a choro-de-criança loop. Melee and pits still hurt. |
| **Normal** | Caim or Lilith silhouette, usual floor pulse. Combat unchanged. |

The last pair stays highlighted on restart. HUD shows `Caim · Normal` or `Lilith · Normal`, or just **Bebê Chorão**.

Four hearts. Hit = a short invuln blink, not a vacation. Enemies can drop a brimstone heart (~22%) — it pulses so it reads on the ash floor. Doors stay shut until the room is clear. Die and the floor rewinds. Beat the boss for a short ending, then restart if you want it again.

The Threshold has a **buraco** (ember-rim pit sprite, not a reused floor tile). Step in and you lose a heart and catch the rim. The boss RING special uses the same pit art for its safe hole.

## The floor

Nine rooms on a grid:

| Room | What |
| --- | --- |
| **The Threshold** (start) | Open doors, pentagram, Caim/Lilith + difficulty pick, one pit |
| Combat rooms | Ember Imps (walk / attack sheets, random loadout), Ring Wretches (bullet rings), Ash Cantors (sine-wave streams) |
| **The Concierge** | NPC room. Walk up. First visit restores one heart. It talks. No shop. |
| **The Phase** | Boss. Patterned shots, telegraphed teleports, and a random room-scale special each time it loses 20% HP. |

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
assets/sprites/baby.png Bebê Chorão walker (not Caim/Lilith)
assets/audio/floor.ogg Usual floor pulse (original)
assets/audio/cry.ogg   Bebê Chorão choro loop (original, not a commercial OST)
```

Out of scope on purpose: extra floors, shops, Steam, mobile, web.

## License

Project code is yours to run and change. Godot Engine is separate (MIT).
