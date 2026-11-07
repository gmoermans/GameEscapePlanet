# Planet Escape

Co-op (up to 4 players) third-person survival + tower-defense game made with **Unreal Engine 5.8**, 100% Blueprint,
designed server-authoritative from day one (listen server today, dedicated server ready).

> Your mothership is out of energy. Land on a nearby planet with the exploration ship, extract matter from the
> matter blocks scattered around the map, bring it back to the ship's tank and take off before the monster hordes
> tear everything down.

*Status: early prototype (V0.1 and beyond), low-poly look, placeholder meshes made in Blender, no character animation yet.*

## The game in a nutshell

1. **Explore** a procedurally filled map (trees, rocks, plants, matter sources generated from a shared seed).
2. **Extract** matter with the extractor tool and carry it back to the ship (hold **E** to deposit into the tank).
3. **Defend** the ship against monster hordes that come in waves, using your gun, buildable turrets and the ship's own weapons.
4. **Escape**: fill the tank up to the matter goal and take off. If the ship's hull reaches 0, it's game over for everyone.

### Monsters
- **Normal monsters** chase the ship or the players.
- **Super monster** (blue, big, tough): kills players instantly and hits the ship hard.
- **Screaming monster** (red, slow): ignores players, attacks the ship with a laser beam from a distance.
- Specials are mixed into each horde (share and difficulty depend on the game setup).
- Dead monsters fall and vanish; killed by an explosion, they are thrown away from the blast.

### Defense
- **Constructor**: spend matter to place buildables; **auto turrets** gain XP with every shot and can be upgraded
  (up to level 5, press **E** next to them) for more damage and range.
- **Ship turret**: player-operated, 3 modes (burst, cannon, laser) with a ballistic aim that follows the crosshair.
- **Scout ship**: a small flying turret that circles above the base, spends matter while flying, recharges when docked
  (with a cooldown after each flight) and can fire missiles.
- **Command panel**: top-down view to call a **missile strike** (costs matter, long cooldown, 10 s delay, huge radius).
- **Jetpack**, gun, extractor and deposit tools on foot.

### Maps and setup
- Maps are `Lvl_*` levels in `Content/PlanetEscape/Maps` and are listed automatically in the main menu
  (flat test map, `LvL_1` hilly landscape).
- The **map generator** measures the real ground size at start and spreads decor and matter over all of it, so new maps
  of any size work without tuning (a few editable variables on `BP_MapGenerator`).
- **Lobby**: the host opens a lobby, picks the map and difficulty (Easy / Middle / Hard / Nightmare / Custom: setup time,
  special monsters, starting matter...), then starts the game for everyone.
- Options menu: controls (AZERTY / QWERTY, sensitivity, jetpack key), display (window mode, resolution presets, frame rate,
  VSync) and graphics quality levels. The packaged game starts in fullscreen 1920x1080.

## Getting started

1. Install [Git LFS](https://git-lfs.com) (`git lfs install`) before cloning — all `.uasset`/`.umap` files are stored in LFS.
2. Open `PlanetEscape1.uproject` with Unreal Engine 5.8.
3. Press Play. PIE is configured as **Play As Client**, which starts a hidden dedicated server and connects to it,
   matching the production setup. (Resolution and fullscreen settings only apply to a standalone / packaged game.)

## Controls (AZERTY by default)

| Key | Action |
|---|---|
| Z Q S D | Move |
| Space | Jump / Jetpack (see options) |
| Left mouse | Shoot (gun) / extract (extractor) / fire (turrets, scout, panel) |
| Mouse wheel | Switch tool or weapon mode |
| E | Interact: deposit matter (hold), upgrade a turret, use the ship turret, scout or command panel |
| Esc / P | Pause menu and options |

QWERTY can be selected in the options menu.

## Project layout

All game content lives in `Content/PlanetEscape/`:

- `Core/` — game mode, player controller, map generator, lobby, saved settings
- `Characters/` — `BP_PE_Character`
- `Tools/` — gun, extractor and other hand tools
- `Buildables/` — constructor and turrets
- `World/` — ship, ship turret, scout, missiles, environment elements, matter sources
- `Monsters/` — monsters and the horde spawner
- `FX/` — Niagara effects (explosions, laser, dust)
- `UI/` — HUD, menus, setup and options widgets
- `Maps/`, `Input/`, `Materials/`, `Sounds/`

More documentation: `Docs/class-diagram.md` (architecture, Mermaid), `Docs/code-docs.html` (generated code docs)
and `passation.md` (running handoff notes: what exists, what is untested, known issues).

## Design principles

- Blueprint only; everything tunable is a variable.
- Server-authoritative gameplay, cosmetic effects (decor, dust, sounds) generated locally on each client.
- Co-op first: all features are written for up to 4 players.
