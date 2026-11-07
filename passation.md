# Passation - PlanetEscape (UE 5.8, Blueprint only)

Handoff for a new chat. Updated 2026-10-11 (evening). Branch `turret-targeting`, last pushed commit `f51f702` (V0.1 = `564bd77`).
NOT committed / pushed: everything listed in section 1b, `Docs/class-diagram.md`, this file. Assets are saved to disk in the editor.

## 0. How to start the next chat
1. Open the editor on PlanetEscape1 BEFORE starting the chat (MCP server `unreal-mcp`, http://127.0.0.1:8000/mcp). If a call fails with ECONNREFUSED, reconnect with `/mcp`. Make sure only ONE UnrealEditor process runs (a second one locked `WBP_HUD.uasset` once; the lock cleared by itself).
2. Tell Claude: "Read passation.md, Docs/class-diagram.md and the memory files, then continue."
3. Auto-memory (`~/.claude/projects/.../memory/`) holds the tool quirks (`unreal-mcp-workflow.md`) - read it first.
4. Ask before commit/push. Replies in English, concise. Everything tunable must be a variable. Server-authoritative, Blueprint only.

## 1. What exists
Architecture diagram: `Docs/class-diagram.md` (Mermaid, V0.1 - does not yet show `BP_ScoutMissile`). Code docs: `Docs/code-docs.html` (regenerate with `Docs/generate.ps1`).

### 1a. V0.1 (committed + pushed)
- **Core loop**: map generated from seed (`BP_MapGenerator`, trees/rocks/plants/matter), ship (`BP_Ship`, tank MatterGoal, hull), hordes of monsters (`BP_Spawning`), extraction (`BP_Extractor`, `BP_MatterSource`), gun, constructor (buildables, turrets with XP/upgrade), ship turret + scout (`BP_ShipTurret`, `BP_ScoutShip`), jetpack, death/respawn.
- **Menu**: main menu with map selector -> Solo/Host opens `WBP_GameSetup` (difficulty presets Easy/Middle/Hard/Nightmare/Custom, saved in `BP_PlayerSettingsSave`) -> `open Lvl_X?listen?SetupTime=...?Special=...`. Join = IP only. No real lobby yet.
- **Display**: first run applies exclusive fullscreen at max supported resolution (`BP_MenuPlayerController.InitDisplay`, marker slot `DisplayInit`).
- **Special monsters**: `BP_SuperMonster` (blue, 2x, 200 hp, instant-kills players, 50 dps on ship) and `BP_ScreamingMonster` (red, 50 hp, 25% speed, targets ship only, laser 10 s on / 30 s reload, 50 dps, 50 m range). Alternating, share = `SpecialPercent` (10%) of each horde, min 1.
- **Game over**: hull <= 0 -> `WBP_GameOver` for everyone, monsters destroyed, spawning stopped, button "Main menu"/"Return to lobby".
- **Command panel**: `BP_CommandPanel` beside the ship (`PanelOffset` 0,-650,0). E near it -> top-down camera + cursor, click = missile strike (`BP_MissileStrike`): 100 matter, cooldown 180 s, impact after 10 s, 800 cm radius, 1000 dmg to monsters only.
- **Input contexts**: On foot / Building / Turret-Scout / Panel / Menu separated (guards in ServerInteract, ServerStartUse, tool switching, build preview, jetpack, pause menu). Hold E to deposit.
- **FX/sound**: `BP_ImpactFX`; sound classes `SC_Players`, `SC_Ship` in `/Game/PlanetEscape/Sounds`.
- **Decor**: `BP_EnvironmentElement` (`DecorVariants`, pivot, deterministic rotation); meshes from `/Game/ImportFromBlender/Environment/...`; matter sources use `MeshVariants`.

### 1b. Done 2026-10-11 (saved in editor, NOT committed, NOT play-tested)
- **Aiming system** (`BP_ShipTurret`, `WBP_HUD`): `ComputeAim` = full-precision control rotation + 500 m eye trace (ignores the ship) for the aim point; modes 0/1 (shells, gravity scale 1) solve the ballistic launch with `SuggestProjectileVelocity` (closest solution when out of reach); laser = direct line. `WBP_HUD.UpdateCrosshair` (called from tick) moves `TxtCrosshair` to the real impact point (predicted shell path via `PredictProjectilePathByTraceChannel`, Visibility, 8 s; laser = beam trace of `Mode3_Range`); glyph per mode: "+" burst, "( + )" cannon, "[ + ]" laser, "< + >" missile (screen centre); 45% opacity when nothing is hit.
- **Scout missile**: scout mode 2 (cannon slot) = missile. `BP_ScoutShip` CDO: `bMissileMode=true`, Mode2 BurstCount 1 / Reload 60 s / Cost 50 matter / Damage 250 / Radius 15000. `BP_ShipTurret.FireShell` branches on `bMissileMode` and spawns `BP_ScoutMissile` (rises 2 s at `RiseSpeed`, ignites with `/Game/sounds/rocketFire` (class SC_Ship), flies straight at `TargetPoint` = camera aim point captured at the click, explodes within `Radius` damaging `BP_Monster` only; Niagara scale Radius/1000). Status text shows MISSILE + reload.
- **New meshes**: scout = `/Game/ImportFromBlender/Ship/Scout/scout` as one mesh attached to `Pivot` in `BP_ScoutShip.EnsureVisual` (head/barrels/base hidden, MI_Ship, `VisualScale` 0.2, front assumed +X), follows the operator's view (scout MaxPitch/MinPitch +-89); virtual nozzle = `Muzzle` at `NozzleForward` 100 (missile spawns there). Ship = `/Game/ImportFromBlender/Ship/Ship/ship` on component `Cube_001` of `BP_Ship` (MI_Gun override kept). The user then changed the ship scale to 1 by hand (originally 0.25, z 505).
- **Starting matter**: `GsStartMatter` in `BP_PlayerSettingsSave`; row in `WBP_GameSetup` (Easy 100 / Middle 50 / Hard 0 / Nightmare 0, custom step 10, 0-1000); sent as `?StartMatter=N`; `BP_PE_GameMode` event `K2_OnRestartPlayer` sets the pawn's `CarriedMatter` (clamped to `MaxMatter` = 100; also applies on RestartPlayer respawns). `GsLoad` re-applies the preset so old save slots get the value.
- **Menu bug fixed**: after adding the start-matter row the setup buttons did nothing because `GsCycle` was called with positional args (key dropped). All 20 click handlers now use `:Key`/`:Delta`. Not yet clicked in game.

### 1c. Lobby (2026-10-12, saved in editor, NOT committed, NOT play-tested)
- Main menu **Host** now runs `open Lobby?listen?MaxPlayers=4` (map `/Game/PlanetEscape/Maps/Lobby`, name deliberately without `Lvl_` so the map selector skips it; duplicated from Lvl_MainMenu, GameMode `BP_LobbyGameMode`, no pawn, UI only, `BP_LobbyPlayerController`).
- Lobby host (listen server, `HasAuthority`) gets `WBP_GameSetup` with `bLobby=true`: new map row (`RowMap`, `MapStep`/`MapInit`, vars `MapOptions`/`MapIndex`), live `ValPlayers`, and Start = `servertravel Lvl_X?listen?<options>` (`BuildCommand`). Back = `open Lvl_MainMenu`. Clients get `WBP_LobbyWait` (player count). Solo setup also shows the map row.
- `WBP_GameOver` button (2026-11-07): standalone -> `open Lvl_MainMenu`; listen host (`IsServer`) -> `servertravel /Game/PlanetEscape/Maps/Lobby`; clients -> `open Lvl_MainMenu` (label still says "Return to lobby" for them). Compiles + saved, not play-tested. Note `HasAuthority` does not work in widgets (needs an Actor target), use `Networking|IsServer`.
- Not done: clients cannot see the host's chosen map/difficulty, no ready button, no late-join block, lobby scene is just the old menu scene.

### 1d. Fixes 2026-11-07 (saved, NOT play-tested)
- **Turret XP bar huge after upgrade**: `BP_Turret.LevelUp` set the level (RepNotify -> `UpdateLabel` -> `UpdateBar`) BEFORE `NextLvlXp` was updated, so the bar used base 100 / denominator 0->1. Fix: `UpdateLabel` is now called at the end of `LevelUp`.
- **Small window when launching from the editor**: editor "new process" launch forces a windowed command-line size and `InitDisplay` only ran on the first launch (`DisplayInit` slot). Else-branch now does `LoadSettings(force)` + `ApplyResolutionSettings` every launch (reapplies the saved fullscreen 2560x1440). Untested: if it is still small, set `AdditionalLaunchParameters=-fullscreen` in Editor Preferences > Level Editor > Play.
- **Scout cooldown**: `BP_ScoutShip` vars `CooldownTime` (30 s, ScoutConfig), `CooldownLeft` (replicated), `WasDocked`, `CanLaunch`; fn `CooldownTick(Dt)` (called from Tick after FlightTick, server) starts the cooldown when the scout docks and sets `CanLaunch`; `FlightTick` takeoff condition has an extra AND input `CanLaunch`. No on-screen indicator yet (GetStatusText lives in the parent `BP_ShipTurret`).

- **Resolution dropdown** (`WBP_Options`): new `CmbResolution` (ComboBoxString) in `RowResolution`; old Prev/Next/Val widgets are collapsed (their click events remain, harmless). `PopulateResolutions` (called in EventConstruct after InitGraphicsState) fills it via helpers `CmbClear`/`CmbAdd`/`CmbSelect` (combo nodes made by node surgery, DSL could not target ComboBoxString); Now FIXED presets (the supported-resolution list was empty): 1280x720 HD, 1024x768, 1920x1080 Full HD, 2560x1440 QHD, 3840x2160 4K; `PopulateResolutions` selects the one matching the current X, `OnSelectionChanged` maps the label to `MakeIntPoint` + `SetScreenResolution` + `ApplyDisplay`. Not play-tested.
- **Default display**: `Config/DefaultGameUserSettings.ini` now 1920x1080 exclusive fullscreen; `BP_MenuPlayerController.InitDisplay` first run no longer picks the largest resolution, it applies the ini one. Only a packaged build proves it (editor/PIE launches stay windowed).

- **LvL_1 dusty/windy ambiance** (saved, not play-tested): sun pitch -25 / temperature 4800 / intensity 4 (was -60.8 / 6500 / 3); height fog inscattering + directional inscattering warm brown, `FogMaxOpacity` 0.92 (was black inscattering); PostProcessVolume white temp 7600, saturation 0.88, vignette 0.5, film grain 0.15. New `FX/NS_Dust` (Niagara, from HangingParticulates: 90/s, box 3500x3500x1000, wind module) spawned client-side by `FX/BP_DustAmbient` (placed in LvL_1, follows the local player pawn, skipped on dedicated server). Not done: foliage WPO wind, gust logic, wind sound.
- **Monster death** (`BP_Monster`, children inherit): AnyDamage now calls `Die(Causer)` (server) instead of DestroyActor. Vars `DeathFadeTime` 1.0, `BlastFlyTime` 2.0, `BlastSpeed` 1500, `BlastUpFactor` 0.5 (category Death, set on the 3 CDOs). Normal kill: capsule NoCollision, movement disabled, actor rolled 90 deg + dropped to the ground, `SetLifeSpan(DeathFadeTime)`. Kill by `BP_MissileStrike`/`BP_ScoutMissile` (detected by DamageCauser class): flies along (away from the blast on XY + up) at `BlastSpeed` for `BlastFlyTime` while tumbling (`DeathTick`, called from EventTick), then destroyed. Known: turrets still target a dying monster (FindNearestMonster unchanged); ScreamingMonster beam logic not stopped on death.

- **Auto map size** (`BP_MapGenerator`, saved, not play-tested): decor/matter used the fixed `MapSize` (30000) so bigger maps only got elements at the centre. New `ResolveMapSize` (called once at the start of `GenerateDecor` and `GenerateMatter`, on server and clients) probes the ground with downward traces along +X/-X/+Y/-Y from the generator origin (`ProbeDir`, step `AutoProbeStep` 1000, max `AutoProbeMax` 300000) and sets `MapSize = 2 * smallest distance`; if `bScaleCountsWithArea`, `NumTrees/Rocks/Plants/MatterSources` are multiplied by `(MapSize/ReferenceMapSize)^2` (`ReferenceMapSize` 30000). Toggle with `bAutoMapSize`. Assumes the generator actor sits at the map centre (the game mode spawns it at world origin; LvL_1's landscape is centred there, ~75600 wide, ground ends ~37000 from origin). FIX 2: the probe first stopped at the first missed trace (steep slope rejected by `MinGroundNormalZ`), giving a tiny MapSize; it now stops only after `AutoProbeMissLimit` (5) consecutive misses. Counts scale is capped by `MaxCountScale` (4).

## 2. Open items
- **Character falls below the map** with the ship at scale 1 (user to investigate): likely the ship mesh collision / its position (mesh is 4070 x 8200 x 2626 cm at scale 1, bottom at z -100 local, component z offset was 505) pushing players or the spawn point; check `BP_Ship` collision, PlayerStart, panel/turret/scout offsets, and `Cube_001` collision profile.
- Unverified in play: crosshair + Visibility trace (may not see monster capsules), missile damage/FX scale, scout mesh facing (+X?), ballistic arc, `K2_OnRestartPlayer` matter grant, menu buttons.
- Missile damages monsters only (no friendly fire); ask if players/ship/buildables should take damage.
- Colours per crosshair mode not done (SlateColor setter awkward through the tools).
- Custom starting matter above 100 is clamped by `MaxMatter` (100).
- **Menu buttons not triggering correctly** (older user report, undiagnosed - may have been unrelated to the bug fixed above): ask which menu, offset direction, and whether it started after InitDisplay (delete save slot `DisplayInit` to compare).
- HUD hint text still says "E again to stop" (now hold E). Panel HUD shows "Weapon: MISSILE" placeholder; mouse-wheel weapon selection not implemented.
- Real lobby (map + difficulty chosen in a room, ready/start) not built.
- Panel position, rock/tree/plant fit values and offsets are tuned to the old meshes; new meshes should have the Blender origin at the base centre (or compute offsets from bounds).
- Mesh collision of imported rocks/trees/ship not verified; generate convex collision if players walk through.
- Super/screaming monsters have no sounds; impact FX silent.
- Test in standalone (InitDisplay resizes the editor window in PIE).

## 3. Practical reminders
- Save assets after each batch (`AssetTools.save_assets`); don't edit Blueprints during PIE. If save returns false, check the log (`LogsToolset.GetLogEntries`) - a file lock (Error 32) means another process holds the asset.
- `call_tool` needs `toolset_name` + short `tool_name`; inside `execute_tool_script` use full dotted names; `set_properties` takes `values` as a JSON string; `write_graph_dsl` takes `code`.
- DSL: first positional arg goes to `self` -> ALWAYS use `:Param value` for own-function params and re-read the graph (a dropped arg still compiles); bool getters drop the `b`; variables made by `add_variable` live under `Variables|Default|`; spawn nodes like `SpawnActorBPX` can't be created fresh (use `SpawnActorfromClass` + cast); multi-exec nodes (casts) end the exec flow; rewriting a graph leaves orphan nodes; `get_node_type_pins` creates a node (delete it). Custom RPC flags only via the Slate inspector (see memory file).
- Never rewrite `BP_PE_Character.EventGraph` with DSL; edit by node surgery (create_node + connect_pins).
