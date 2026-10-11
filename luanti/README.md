# Diablocks (Luanti edition)

The `../index.html` three.js Diablo-in-Minecraft toy, rebuilt as a real Luanti game with a
(Shattered) Pixel Dungeon skin.

    ./luanti/play.sh          # or symlink games/diablocks into ~/.minetest/games/

A fresh dungeon is carved every launch: five concentric zones (Sewers, Prison, Caves, Dwarven City,
Demon Halls) of rooms and corridors, one wall node high. Monsters spawn around you and get
stronger with your level and with the zone.

## Controls
| Input | Action |
|---|---|
| WASD | move (relative to the camera) |
| Mouse X / Y | orbit camera / aim nearer-farther (the orange ring is your aim point) |
| 1 / 2 / 3 / wheel | sword, pickaxe, barricades |
| LMB | sword swing (digs slowly if nothing to hit) / pickaxe dig / barricade dig |
| RMB | firebolt (sword) / place barricade (barricades) |
| Space | Psionic Blast (nova) |
| E | Firebolt auto-aimed at the nearest monster in front |
| Shift | Scroll of Upgrade: 5 gold for +20% weapon damage |

Gold comes from gold veins in the walls, salvaged gear and kills. Bomb Rats (the Creeper) blow holes
in the walls.

## How it maps from the web version
- Camera/aim: copied in spirit from Extra Ordinance — the player is an invisible camera attached to an
  entity hovering over the hero; the screen-centre ray hits the floor = aim point.
- Zombies/Creepers -> Pixel Dungeon rats, crabs, gnolls, skeletons, wraiths... and Bomb Rats.
- Ore -> gold veins, Forge -> Scroll of Upgrade, loot rarity + affixes unchanged.

## Credits / licences
- Textures (`textures/voxeldungeon_*`): Pixel Dungeon by Watabou, adapted for Luanti by Noodlemire
  (VoxelDungeon, GPL-3.0-only) — see `games/diablocks/LICENSE-voxeldungeon-GPL3.txt`.
  That makes this game GPL-3.0 as a combined work.
- Top-down camera idea: Extra Ordinance by Sumianvoice (MIT code, CC-BY-4.0 media). No EO code or
  media is copied.
- Everything else (Lua, hero sprite, cursor): this repo.
