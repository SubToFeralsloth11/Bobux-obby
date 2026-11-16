# Bobux Obby

A 30-stage Roblox obby across 5 themed zones, with checkpoints, ladders, moving blocks, temporary power-ups, coins, a trail shop and a full HUD. Works with keyboard and mouse, touch (phones and tablets) and gamepad.

## Play it in Roblox Studio

1. Download **`BobuxObby.rbxlx`** from this repo.
2. Open it in Roblox Studio (double-click it, or File > Open from File).
3. Press **Play**. The map is built by script when the game starts, so the editor view is empty until you press Play.
4. To put it on Roblox: File > Publish to Roblox.

Saving progress needs **Game Settings > Security > Enable Studio Access to API Services** (it is always on in a published game). Without it the game still works; progress just resets.

## What's in it

| Zone | Stages | Highlights |
| --- | --- | --- |
| Sunny Meadows | 1-6 | stepping stones, ladders, sliding blocks, lift, spinners, balance beams |
| Magma Caverns | 7-12 | lava, crumbling tiles, fire jets, a ferry ride, swinging blades |
| Frostbite Peaks | 13-18 | ice, conveyors, bounce pads, crushers, spike balls |
| Neon City | 19-24 | laser grid, boost pads, carousel, laser ladders |
| Starlight Sanctum | 25-30 | star wheel, phase tiles, spinner gauntlet, the final spiral |

Power-ups (all temporary): **Turbo**, **Mega Jump**, **Double Jump**, **Moon Boots**, **Shield**.

Controls: WASD/arrows + Space, Shift for mouse lock, **R** respawn, **M** stages, **T** trails, **P** settings. On touch, use the thumbstick, jump button and the on-screen buttons.

## Changing things

- `src/shared/Config.luau` has every number, colour, stage name and sound id.
- `src/server/WorldBuilder/Zones/` has one file per zone; each stage is a short function.
- After editing, rebuild the place file: `python3 tools/build_place.py` (or use Rojo with `default.project.json`).
- To edit the map by hand: press Run in Studio, copy `Workspace.Obby`, press Stop, paste it into Workspace. The game then uses your copy.

## Tests

`tools/test/run.py` runs the scripts against a strict mock of the Roblox API (needs `pip install lupa` and `globalTypes.d.luau` from the luau-lsp project):

```
python3 tools/test/run.py path/to/globalTypes.d.luau
```
