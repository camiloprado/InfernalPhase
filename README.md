# Infernal Phase

One infernal floor. No campaign. You walk a small graph of hell-rooms, dodge patterned bullets, and either kill **The Infernal Phase** or get filed as ash and start over.

Top-down move-and-shoot in the Binding of Isaac room style, with Undertale-ish bullet patterns and short dark-humor lines. Ember Imps and **The Infernal Phase** use character sheets (`assets/characters/imp/`, `assets/characters/boss/`). Cantors, wretches, cultists, and the Concierge stay as placeholder shapes until those folders get art. Hell palette (ash, ember, bone, void).

## Open in Godot 4

1. Install **Godot 4.x** (built and tested with **4.7.2**; 4.3+ should open it). Standard build, not .NET.
2. In the Project Manager: **Import** → select this folder (`project.godot`) → **Import & Edit**.
3. Press **F5** (or Run Project).

The main scene is `scenes/floor.tscn`.

Command line from this folder:

```bash
godot --path .
```

If the editor is already open, F5 is enough.

## Play

- **WASD** or left stick: move
- **Mouse**: aim · **Left click** / **Space** / **J**: shoot
- **Arrow keys**: shoot that way (with WASD, this is dual-stick on a keyboard; arrows alone move and fire)
- **Right stick**: aim and fire
- **R** or **Enter**: restart the floor (also after death or the win card)

Four hearts. Hit = a short invuln blink, not a vacation. Doors stay shut until the room is clear. Die and the floor rewinds. Beat the boss for a short ending, then restart if you want it again.

## The floor

Nine rooms on a grid:

| Room | What |
| --- | --- |
| **The Threshold** (start) | Open doors, pentagram, no fight |
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
```

Out of scope on purpose: extra floors, items, shops, Steam, mobile, web.

## License

Project code is yours to run and change. Godot Engine is separate (MIT).
