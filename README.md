# Planet Escape

Co-op (up to 4 players) third-person + tower-defense game made with Unreal Engine 5.8 (Blueprint only).

Your mothership is out of energy. Land on a nearby planet with the exploration ship, extract matter from
the matter blocks scattered around the map, bring it back to the ship's tank and take off before the
monster hordes overrun you.

## Getting started

1. Install [Git LFS](https://git-lfs.com) (`git lfs install`) before cloning — all `.uasset`/`.umap` files are stored in LFS.
2. Open `PlanetEscape1.uproject` with Unreal Engine 5.8.
3. Press Play. PIE is configured as **Play As Client**, which starts a hidden dedicated server and connects to it,
   matching the production setup.

## Controls (AZERTY by default)

| Key | Action |
|---|---|
| Z Q S D | Move |
| Space | Jump |
| Left mouse | Shoot (gun) / extract (extractor) |
| Mouse wheel | Switch tool |
| E | Unload matter into the ship's tank (within 1 m) |

QWERTY can be selected with `bUseAzerty` / `SetKeyboardLayout` on `BP_PE_PlayerController`.

## Layout

All game content lives in `Content/PlanetEscape/`:

- `Core/` — game mode, player controller, map generator
- `Characters/` — `BP_PE_Character`
- `Tools/` — `BP_Tool`, `BP_Gun`, `BP_Extractor`
- `World/` — ship, environment elements, matter sources, simple decor
- `Monsters/` — monster and spawner (disabled for now)
- `Input/`, `UI/`, `Materials/`, `Maps/`
