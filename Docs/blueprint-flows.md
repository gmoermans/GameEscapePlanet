# Blueprint flows (classes, guns, lobby, decor)

Human-readable walkthrough of the logic added since V0.1. The graphs themselves cannot carry comment boxes through the editor tools, so this file is the reference. Update it when a flow changes.

## 1. Characters and classes

`BP_PE_Character` is the shared base. Children only set data (class defaults): `BP_PE_Soldier`, `BP_PE_Worker`, `BP_PE_Scout`, `BP_PE_Tank`, `BP_PE_Joker`.

| Variable (category Class/Jetpack) | Meaning |
|---|---|
| `LoadoutId` | 1 Soldier, 2 Worker, 3 Scout, 4 Tank, 5 Joker. Drives `SpawnTools`. |
| `SkinMaterial` | Applied to the 5 body parts by `ApplySkin` (first node of BeginPlay, runs on every machine). |
| `MaxHealth`, `MoveSpeed`, `MaxMatter` | Stats (Scout 50 hp / speed 1000 / 200 matter, Tank 250 hp / speed 425, Worker 400 matter). |
| `bUnlimitedJetpack` | Scout: jetpack ignores matter. Consumption is also 0. |
| `bCanJetpack` | False for Tank. ANDed into `JetpackLocal` (key press) and `JetpackServerOn`. |
| `bCanBuildTurrets` | False for Scout: `RegisterTool` sets the constructor `NumBuildables` to 1 (barrier only). |
| `bExtractorUpgradable` | False for Scout and Tank: `BP_Extractor.GetBonusSteps` returns 0 and `GetMaxSources` stays at the base value. |
| `bCanUseTurrets` | False for Worker and Scout: ANDed into `CanUseTurret` (ship turrets and scout ship). |

### Tool spawning (server, BeginPlay)
`SpawnTools` -> for each tool class chosen from `LoadoutId` -> `SpawnActorfromClass` -> `RegisterTool(A)`:
1. cast to `BP_Tool`, `InitTool(owner)`;
2. attach to the tool socket;
3. add to `Tools`;
4. if it is a constructor and `bCanBuildTurrets` is false, `NumBuildables = 1`.

Loadouts: Soldier = rifle, extractor, constructor. Worker = gun, worker extractor, constructor. Scout/Joker = gun, extractor, constructor. Tank = minigun, grenade launcher, extractor (no constructor).

### Scout matter drop
`ExtraTick` -> `DropKeyTick` (local, not in a menu): on the G key press edge, call RPC `SRV_DropMatter` (Run on Server, reliable) -> `DropMatter`:
Scout + extractor active + matter > 0.5 + not dead/turret/panel -> trace down for the ground -> spawn `BP_MatterOrb` 100 cm above it with `Amount` = carried matter and `Dropper` = scout -> carried matter = 0.

`BP_MatterOrb` (server overlap): a `BP_PE_Character` (not the dropper during `LockTime`, alive, with free capacity) gets `AddMatter(Amount)` (clamped to the free space), then the orb is destroyed. The excess is lost.

## 2. Guns

`BP_Gun` (child of `BP_Tool`). Variables: `MaxAmmo`, `Ammo` (replicated), `ReloadTime`, `bReloading` (replicated), `RateOfFire` (per minute), `bAutomatic`, `ProjectileSpeed` (> 0 means grenade), `ExplosionRadius`, `Damage`.

Flow on left click (server, via `StartUse`):
1. `TryFire` once.
2. If `bAutomatic`: start a looping timer calling `TryFire` every `GetFireInterval` (= 60 / `RateOfFire`).
3. `StopUse` clears the timer.

`TryFire`: reloading -> stop. Ammo 0 -> `StartReload`. Cooldown not elapsed -> stop. Else ammo -1, `FireAny`, and auto-reload when ammo hits 0.
`FireAny`: `ProjectileSpeed > 0` -> `FireProjectile` (camera trace for the aim point, spawn `BP_Grenade` at the muzzle, `Launch`), otherwise the original hitscan `Fire`.
`StartReload` sets `bReloading` and a timer; `FinishReload` refills ammo. The HUD (`WBP_HUD.UpdateToolInfo`) shows `GetAmmoText`.

Children (class defaults only): `BP_AutomaticGun` (60/min), `BP_GrenadeLauncher` (25/min, speed 2500, radius 250, damage 10), `BP_SoldierRifle` (120/min, 30 ammo, 2.5 s), `BP_TankMinigun` (750/min, 75 ammo, 4 s). `BP_Grenade` explodes on hit and damages monsters in `Radius`.

## 3. Class choice

Solo/Host setup (`WBP_GameSetup`): row `RowClass` + `ClassCycle`, saved in `BP_PlayerSettingsSave.GsClass`, sent as `?Class=` by `BuildCommand`.

Lobby (one Tank and one Scout max):
- `BP_LobbyPlayerController.AssignedClass` (replicated). RPC `SRV_ClassNext` (Run on Server) -> `DoClassNext`: try the next 3 classes in order, skipping Scout/Tank if `IsTaken`; `CommitClass` stores the result in `AssignedClass` and in save slot `LobbyClass_<PlayerName>` (`BP_ClassSave.ClassIdx`).
- `IsTaken(Idx)` reads the slots of the other connected players.
- Host UI: `WBP_GameSetup` (lobby mode calls the controller). Client UI: `WBP_LobbyWait` (label + "Change class").
- In game: `BP_PE_GameMode.GetDefaultPawnClassForController` -> `ResolveClassIdx` (slot, not in standalone) -> else `?Class=` -> else Soldier. Joker only in standalone.

## 4. Map decor

`BP_EnvironmentElement.ConstructionScript`: picks the mesh from `DecorVariants` with a position hash, then `ApplySize` scales it between `SizeMin` and `SizeMax`. Rotation: mesh name starting with `ROT_` = fully random on all axes, otherwise a tilt of up to `TiltDegrees` plus a random yaw. `BP_MatterSource.InitMatter` applies the same `ROT_` rule to its `MeshRotation`.

`BP_MapGenerator`: `NumTrees`, `NumRocks`, `NumPlants`, `NumMatterSources` (scaled by area up to `MaxCountScale` when `bScaleCountsWithArea`).
