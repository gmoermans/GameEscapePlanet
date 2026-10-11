# Passation - PlanetEscape (UE 5.8, Blueprint only)

Handoff for a new chat. Updated 2026-10-11. Branch `turret-targeting`, last pushed commit `f51f702` (V0.1 = `564bd77`).
Not committed yet: `Docs/class-diagram.md`, this file.

## 0. How to start the next chat
1. Open the editor on PlanetEscape1 BEFORE starting the chat (MCP server `unreal-mcp`, http://127.0.0.1:8000/mcp). If a call fails with ECONNREFUSED, reconnect with `/mcp`.
2. Tell Claude: "Read passation.md, Docs/class-diagram.md and the memory files, then continue."
3. Auto-memory (`~/.claude/projects/.../memory/`) holds the tool quirks (`unreal-mcp-workflow.md`) - read it first.
4. Ask before commit/push. Replies in English, concise. Everything tunable must be a variable. Server-authoritative, Blueprint only.

## 1. What exists (all saved + pushed)
Architecture diagram: `Docs/class-diagram.md` (Mermaid). Code docs: `Docs/code-docs.html` (regenerate with `Docs/generate.ps1`).

- **Core loop**: map generated from seed (`BP_MapGenerator`, trees/rocks/plants/matter), ship (`BP_Ship`, tank MatterGoal, hull), hordes of monsters (`BP_Spawning`), extraction (`BP_Extractor`, `BP_MatterSource`), gun, constructor (buildables, turrets with XP/upgrade), ship turret + scout (`BP_ShipTurret`, `BP_ScoutShip`), jetpack, death/respawn.
- **Menu**: main menu with map selector -> Solo/Host opens `WBP_GameSetup` (difficulty presets Easy/Middle/Hard/Nightmare/Custom, saved in `BP_PlayerSettingsSave`) -> `open Lvl_X?listen?SetupTime=...?Special=...`. Join = IP only. No real lobby yet.
- **Display**: first run applies exclusive fullscreen at max supported resolution (`BP_MenuPlayerController.InitDisplay`, marker slot `DisplayInit`).
- **Special monsters**: `BP_SuperMonster` (blue, 2x, 200 hp, instant-kills players, 50 dps on ship) and `BP_ScreamingMonster` (red, 50 hp, 25% speed, targets ship only, laser 10 s on / 30 s reload, 50 dps, 50 m range). Spawned alternately (`SpecialCounter`), share = `SpecialPercent` (10%) of each horde, min 1.
- **Game over**: hull <= 0 -> `WBP_GameOver` for everyone, monsters destroyed, spawning stopped, button "Main menu"/"Return to lobby" (`open Lvl_MainMenu`).
- **Command panel**: `BP_CommandPanel` spawned beside the ship (`PanelOffset` 0,-650,0). E within 75 cm of its surface and aiming -> top-down camera + crosshair cursor, left click = missile (`BP_MissileStrike`): costs 100 matter from the tank, cooldown 180 s, marker, sound at 5 s, impact at 10 s (800 cm radius, 1000 dmg to monsters only). Target is sent as the cursor ray in control rotation (RPCs have no params through the tools).
- **Input contexts**: On foot / Building / Turret-Scout / Panel / Menu are separated (guards in ServerInteract, ServerStartUse, tool/buildable switching, build preview, jetpack, pause menu). Hold E to deposit, release stops; MBL while depositing deposits everything at once.
- **FX/sound**: `BP_ImpactFX` explosion on gun hits and laser hits (server spawned, replicated). Sound classes `SC_Players`, `SC_Ship` in `/Game/PlanetEscape/Sounds`.
- **Decor**: `BP_EnvironmentElement` has `DecorVariants`, pivot, deterministic random rotation (hash of location). Meshes from `/Game/ImportFromBlender/Environment/{Plants,Rocks,Threes}` and `/MatterSource`. Matter sources use `MeshVariants`, full random rotation, `VisualFit`.

## 2. Open items / ideas (none blocking)
- **Aiming accuracy** (user report): turret/scout shells and laser fly parallel to the view from the muzzle, not toward the crosshair point; server aim is compressed. Fix = trace from camera, aim pivot at hit point, send full-precision aim (like the panel). Also the HUD "+" glyph may be off-centre; monsters are hit through the capsule, not the mesh.
- **Menu buttons not triggering correctly** (user report, undiagnosed): ask which menu, offset direction, and whether it started after InitDisplay (delete save slot `DisplayInit` to compare).
- HUD hint text still says "E again to stop" (now hold E). Panel HUD shows "Weapon: MISSILE" placeholder; mouse-wheel weapon selection not implemented.
- Real lobby (map + difficulty chosen in a room, ready/start) not built.
- Panel position, rock/tree/plant fit values and offsets are tuned to the current 3 meshes; new meshes should have the Blender origin at the base centre (or compute offsets from bounds).
- Mesh collision of imported rocks/trees not verified; generate convex collision if players walk through.
- Super/screaming monsters have no sounds; impact FX silent.
- Nothing from the last sessions has been play-tested in PIE (InitDisplay would resize the editor window; test in standalone).

## 3. Practical reminders
- Save assets after each batch (`AssetTools.save_assets`); don't edit Blueprints during PIE.
- `call_tool` needs `toolset_name` + short `tool_name`; inside `execute_tool_script` use full dotted names; `set_properties` takes `values` as a JSON string.
- DSL: first positional arg goes to `self` (use `:Param`), bool getters drop the `b`, spawn nodes like `SpawnActorBPX` can't be created fresh (use `SpawnActorfromClass` + cast), `CallFunction|X` is ambiguous with same-named functions in other BPs, rewriting a graph leaves orphan nodes. Custom RPC flags only via the Slate inspector (see memory file).
- Never rewrite `BP_PE_Character.EventGraph` with DSL; edit by node surgery (create_node + connect_pins).
