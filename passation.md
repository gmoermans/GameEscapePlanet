# Passation - PlanetEscape (UE 5.8, Blueprint only)

Handoff for a new chat. Written 2026-10-10. Branch `turret-targeting`, **nothing committed** (user asked to ask before commit/push).

## 1. Blocking issue at handoff
The Unreal editor MCP server (`unreal-mcp`, `http://127.0.0.1:8000/mcp`) was **ECONNREFUSED** for the whole last chat, so no Blueprint work could be done.
Before anything else: editor open on PlanetEscape1, MCP plugin enabled, then (re)connect with `/mcp` or start the chat after the editor is up. Check with a trivial call (`list_toolsets`).
Also read `memory/unreal-mcp-workflow.md` (auto-memory): it lists every tool quirk learned (DSL pitfalls, RPC flags via Slate inspector, save_assets, modal dialog freeze, ...).

## 2. Task to do next: game setup / difficulty menu + super monster

### 2.1 Where the menu appears
- Show a "Game setup" panel after the user clicks **Solo** (standalone) or **Host** in `WBP_MainMenu`; **Join** does not show it (only the host's settings matter).
- There is **no multiplayer lobby** in the project. Flow today: Solo = `open Lvl_<map>`, Host = `open Lvl_<map>?listen`, Join = `open <ip>`.
- A **Start** button opens the map with the chosen values as URL options; **Back** returns to the main menu.

### 2.2 Difficulty presets (user's table)
| Mode | Setup time (s) | First horde size | Time between hordes (s) | Increment per horde | Special monsters |
|---|---|---|---|---|---|
| Easy | 180 | 10 | 120 | 10 | false |
| Middle | 150 | 15 | 100 | 15 | false |
| Hard | 100 | 30 | 90 | 30 | true |
| Nightmare | 0 | 50 | 60 | 50 | true |
| Custom | all editable via the menu (Prev/Next rows like WBP_Options) | | | | |

"Level" = difficulty level only (user confirmed; **no extra maps**).

### 2.3 How values reach the game
- `BP_PE_GameMode.SpawnSpawning` already reads URL options and writes them into the spawned `BP_Spawning`: `SetupTime`, `HordeInterval`, `FirstHorde`, `HordeIncrement`, `NumberOfHordes` (the last line was truncated when read - **verify its exact option name**).
- Menu builds e.g. `open Lvl_Flat?listen?SetupTime=150?HordeInterval=100?FirstHorde=15?HordeIncrement=15?NumberOfHordes=8?Special=0`.
- Add new options to `SpawnSpawning`: `Special` (bool) and, for Custom, `SpecialPercent`.
- Remember the last choice in the `PlayerSettings` save (`BP_PlayerSettingsSave`), like the other options.
- Defaults shown in the menu = current `BP_Spawning` defaults.

### 2.4 BP_Spawning changes
- New variables (instance editable, category e.g. `Special`):
  - `bSpecialMonsters` (bool, default false)
  - `SpecialPercent` (float, default **10.0** = 10% of each horde) - user explicitly wants this as a variable on `BP_Spawning`.
  - `MinSpecialPerHorde` (int, default 1) - at least 1 special per horde when specials are enabled.
  - `SpecialMonsterClass` (class ref -> BP_SuperMonster) if convenient.
- In `SpawnHorde` / `SpawnOneMonster`: if `bSpecialMonsters`, `specialCount = max(MinSpecialPerHorde, round(NextHordeSize * SpecialPercent/100))`; spawn that many `BP_SuperMonster`, the rest `BP_Monster`.
- Existing facts: `SpawnHorde` loops `NextHordeSize` times calling `SpawnOneMonster`, increments `CurrentHorde` (RepNotify -> ship siren), then schedules the next horde. HUD `WBP_HUD.UpdateWaveText` reads CurrentHorde / NextHordeSize / NextHordeTime.

### 2.5 Super monster (child class of BP_Monster, only one special type for now)
Class `BP_SuperMonster` in `/Game/PlanetEscape/Monsters/`:
- **Blue material** instead of green: new MI from the monster parent material (see `MI_Monster`, `MI_MonsterLimb`; parent `M_PE_Flat` has params `Color`, `Emissive`, `Roughness`) e.g. `MI_SuperMonster`, blue Color. The monster body/limbs use the user's Blender meshes in `/Game/ImportFromBlender` (Monsterface etc., body rotated yaw 90).
- **Mesh x2** (actor/mesh scale 2; adjust capsule accordingly).
- **200 health** (`MaxHealth` var on BP_Monster is instance-editable - set in child CDO; remember: child CDOs do not inherit later parent CDO edits).
- **Speed = 75% of a normal monster** (`MoveSpeed` of parent x 0.75; set in child CDO or computed at BeginPlay from parent default).
- **Ship**: 50 damage **per second** on contact (BP_Monster.TryAttack uses `Damage` + `AttackCooldown`; e.g. damage 50 x cooldown, or a dedicated tick while overlapping).
- **Players**: contact = **instant kill** of any player -> call `BP_PE_Character.Die` (server) directly (it exits the turret first, drops matter per `bLoseMatterOnDeath`, schedules respawn). Do not go through TakeHit damage.
- Make the numbers variables on the child class (user always asks for editable variables).
- `BP_Monster.TryAttack(Other)` currently: server only, cooldown, cast to `BP_PE_Character` -> ApplyDamage; CastFailed -> `BP_Ship` ApplyDamage. Override by adding an `Attack` hook or a child event; function overrides via tools are refused ("event-shape") - use `add_event` + helper function, or put the branching in the parent with a virtual-like variable (`bInstantKill`, `ShipDps`).

### 2.6 Menu UI implementation notes
- New widget `WBP_GameSetup` (UMG toolset) or extra panel inside `WBP_MainMenu`; reuse row pattern of `WBP_Options` (HorizontalBox: label, Prev button, value text, Next button; `OnClicked(BtnXPrev/Next)` -> `Cycle(Key, Delta)` -> `RefreshAll`).
- Difficulty row cycles Easy/Middle/Hard/Nightmare/Custom; the numeric rows are editable only when Custom (otherwise they show the preset values, read-only).
- `WBP_MainMenu` already has `RunCommand(Command)` (echoes and executes console command), `GetSelectedLevel()` -> `Lvl_<name>`, map list from `/Game/PlanetEscape/Maps` (all `Lvl_*` except MainMenu / `_BuiltData`).

## 3. State of the project (what exists, all saved to disk, uncommitted)
Features built in earlier chats (details in `Docs/code-docs.html`, regenerate with `Docs/generate.ps1`):
- Turret XP/levels (100/200/400/1000), E to upgrade (price), +15% size/level, 3D XP bar label.
- Scout ship (`BP_ScoutShip`, child of `BP_ShipTurret`): circular flight, matter burn, replicated manual position + client smoothing.
- Ship turret: cannon aims at camera direction, shells/laser from a virtual nozzle (`NozzleForward`), `MinPitch`.
- Extractor upgrades (every 200 extracted: +30% rate/range, +10 max matter; at 1000 two sources at once), HUD info lines.
- Matter blocks have a BlockAll collider (camera ignored).
- Sounds in `/Game/sounds` (run, jetpack, canon, laser, extract, hordeSiren) with spatial attenuation overrides per audio component.
- Jetpack: hold key (default LeftShift, rebindable in Options via InputKeySelector, stored in save game), burns 2 **carried matter**/s, x4 speed, hovers 75 above ground, server RPCs `SRV_JetpackOn/Off`.
- Gradual unloading at ship (E toggles, `DepositRate` 50/s), death + respawn (`RespawnDelayPerDeath` 10s x deaths, `bLoseMatterOnDeath`), game ends only when ship hull is destroyed.
- Defaults: fullscreen 2560x1440, 35% render scale (`Config/DefaultGameUserSettings.ini`); ship `MatterGoal` 2000.
- Docs: `Docs/code-docs.html`, `Docs/descriptions.json` (hand-written comments), `Docs/doc_dump.json` (structure export), `Docs/generate.ps1`.

Git: modified/untracked Blueprints and assets are not committed (`BP_ScoutShip`, `MI_Xp*`, `Content/sounds/`, `Docs/` are untracked). **Ask before committing/pushing.**

## 4. Practical reminders for the next session
- Save assets explicitly after each batch: `AssetTools.save_assets {asset_paths:[...]}` (unsaved edits are lost if the editor crashes; do not edit Blueprints during PIE).
- DSL gotchas: first positional arg goes to `self`; bool literals as first positional go to `self` (use `:bInReplicates true`); nested `(+ str str)` fails -> `Utilities|String|Append`; `Utilities|IsValid` terminates flow (put last); never rewrite `BP_PE_Character.EventGraph` with DSL (hand-wired Enhanced Input nodes); after a rewrite delete orphan nodes (exec input unconnected).
- Custom events are called from functions as `CallFunction|SRVxxx` (underscores removed). New Run-on-Server events need flags set through the Slate inspector (see memory file).
- Test pattern: temporary `BP_TestDriver` actor with timers + PrintString, run PIE, read `LogBlueprintUserMessages`, then delete the actor and asset.
- A modal editor dialog titled "Message" freezes all MCP calls; close it (WM_CLOSE) from PowerShell.
- User preferences: everything tunable must be a variable; keep gameplay server-authoritative; Blueprint-only; user is French-speaking (replies in English so far); concise answers; don't commit without asking.

## 5. Open questions (none blocking)
- Exact count of special monsters is decided (10% of horde, min 1, variable). 
- Whether to show monster stats (health/speed/damage) in the menu: not requested, leave out unless asked.
