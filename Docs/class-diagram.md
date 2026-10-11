# PlanetEscape - class diagram (V0.1)

Blueprint-only project. Renders on GitHub and in any Mermaid viewer.
Inheritance = hollow arrow, association = plain arrow. Parents marked `?` were not re-verified.

## 1. Inheritance + core relations

```mermaid
classDiagram
direction LR

%% ---------- Engine bases ----------
class Actor
class Character
class GameModeBase
class PlayerController
class SaveGame
class UserWidget

%% ---------- Core ----------
class BP_PE_GameMode {
  SpawnSpawning()  URL options
}
class BP_PE_PlayerController {
  bMenuOpen
  TogglePauseMenu()
  ReloadPlayerSettings()
}
class BP_MenuPlayerController {
  InitDisplay()
}
class BP_PlayerSettingsSave {
  MouseSensitivity, JetpackKey
  GsDifficulty, GsSetupTime...
}
class BP_MapGenerator {
  MapSize, Seed
  GenerateDecor() GenerateMatter()
  ProjectToGround()
}
GameModeBase <|-- BP_PE_GameMode
PlayerController <|-- BP_PE_PlayerController
PlayerController <|-- BP_MenuPlayerController
SaveGame <|-- BP_PlayerSettingsSave
Actor <|-- BP_MapGenerator

%% ---------- Player ----------
class BP_ThirdPersonCharacter
class BP_PE_Character {
  Health, CarriedMatter
  bInTurret, bUsingPanel, bDead
  ServerInteract() Die() Respawn()
  StartPanel() PanelTick()
}
Character <|-- BP_ThirdPersonCharacter
BP_ThirdPersonCharacter <|-- BP_PE_Character

%% ---------- Tools ----------
class BP_Tool { StartUse() StopUse() }
class BP_Gun { Fire() }
class BP_Extractor
class BP_Constructor { Build() NextBuildable() }
Actor <|-- BP_Tool
BP_Tool <|-- BP_Gun
BP_Tool <|-- BP_Extractor
BP_Tool <|-- BP_Constructor
BP_PE_Character "1" o-- "*" BP_Tool : Tools

%% ---------- Ship + turrets ----------
class BP_Ship {
  MatterStored, Hull, bGameLost
  DepositMatter() SpendMatter()
  SpawnPanel()
}
class BP_ShipTurret {
  Mode1 burst / Mode2 cannon / Mode3 laser
  StartFire() LaserTick()
}
class BP_ScoutShip { FlightTick() Init() }
class BP_TurretShell { Launch() }
Actor <|-- BP_Ship
Actor <|-- BP_ShipTurret
BP_ShipTurret <|-- BP_ScoutShip
Actor <|-- BP_TurretShell
BP_Ship --> BP_ShipTurret : Turret
BP_Ship --> BP_ScoutShip : Scout
BP_ShipTurret ..> BP_TurretShell : spawns
BP_PE_Character ..> BP_ShipTurret : enter / fire

%% ---------- Buildables ----------
class BP_Buildable
class BP_Turret { TryUpgrade() CanUpgrade() XP }
Actor <|-- BP_Buildable
BP_Buildable <|-- BP_Turret
BP_Constructor ..> BP_Buildable : places

%% ---------- Command panel ----------
class BP_CommandPanel {
  MissileCost, Cooldown
  IsFree() Fire()
}
class BP_MissileStrike {
  Delay, Radius, Damage
  Explode()
}
class BP_ImpactFX
Actor <|-- BP_CommandPanel
Actor <|-- BP_MissileStrike
Actor <|-- BP_ImpactFX
BP_Ship ..> BP_CommandPanel : spawns
BP_PE_Character --> BP_CommandPanel : CurrentPanel
BP_CommandPanel ..> BP_MissileStrike : spawns
BP_CommandPanel ..> BP_Ship : spends matter
BP_Gun ..> BP_ImpactFX : spawns
BP_ShipTurret ..> BP_ImpactFX : spawns

%% ---------- Monsters ----------
class BP_Monster {
  MaxHealth, Damage, MoveSpeed
  bKillsPlayers, bTargetShipOnly
  ChaseTick() TryAttack()
}
class BP_SuperMonster
class BP_ScreamingMonster { laser vs ship }
class BP_Spawning {
  hordes, bSpecialMonsters
  SpawnHorde() SpawnOneMonster()
}
Character <|-- BP_Monster
BP_Monster <|-- BP_SuperMonster
BP_Monster <|-- BP_ScreamingMonster
Actor <|-- BP_Spawning
BP_PE_GameMode ..> BP_Spawning : spawns + options
BP_Spawning ..> BP_Monster : spawns
BP_Monster --> BP_Ship : attacks
BP_Monster --> BP_PE_Character : attacks

%% ---------- World elements ----------
class BP_EnvironmentElement {
  DecorVariants, Pivot
  random rotation
}
class BP_SimpleElement
class BP_Tree
class BP_Rock
class BP_Plant
class BP_MatterSource {
  RemainingMatter
  MeshVariants
  RemoveMatter()
}
Actor <|-- BP_EnvironmentElement
BP_EnvironmentElement <|-- BP_SimpleElement
BP_SimpleElement <|-- BP_Tree
BP_SimpleElement <|-- BP_Rock
BP_SimpleElement <|-- BP_Plant
BP_EnvironmentElement <|-- BP_MatterSource
BP_MapGenerator ..> BP_EnvironmentElement : spawns
BP_MapGenerator ..> BP_MatterSource : spawns
BP_MapGenerator ..> BP_Ship : spawns
BP_Extractor ..> BP_MatterSource : extracts
```

## 2. UI

```mermaid
classDiagram
direction LR
class UserWidget
class WBP_MainMenu { Solo / Host / Join / map selector }
class WBP_GameSetup { difficulty presets, Start }
class WBP_Options { graphics, controls, jetpack key }
class WBP_PauseMenu
class WBP_HUD { matter, health, wave, tool info }
class WBP_GameOver { return to lobby / main menu }
class WBP_CommandView { map click, reload status }
class WBP_Crosshair
UserWidget <|-- WBP_MainMenu
UserWidget <|-- WBP_GameSetup
UserWidget <|-- WBP_Options
UserWidget <|-- WBP_PauseMenu
UserWidget <|-- WBP_HUD
UserWidget <|-- WBP_GameOver
UserWidget <|-- WBP_CommandView
UserWidget <|-- WBP_Crosshair

BP_MenuPlayerController ..> WBP_MainMenu : creates
WBP_MainMenu ..> WBP_GameSetup : Solo / Host
WBP_MainMenu ..> WBP_Options
WBP_PauseMenu ..> WBP_Options
BP_PE_PlayerController ..> WBP_HUD
BP_PE_PlayerController ..> WBP_PauseMenu
BP_Ship ..> WBP_GameOver : bGameLost
BP_PE_Character ..> WBP_CommandView : panel mode
BP_PE_Character ..> WBP_Crosshair : cursor
WBP_GameSetup ..> BP_PlayerSettingsSave : persists choices
```

## 3. Control contexts (who can do what)

```mermaid
stateDiagram-v2
  [*] --> OnFoot
  OnFoot --> Building : hold Build (not in menu/turret/panel)
  Building --> OnFoot : release Build / open menu
  OnFoot --> Turret : E near turret or scout (not building)
  Turret --> OnFoot : E
  OnFoot --> Panel : E at panel (not building)
  Panel --> OnFoot : E / death
  OnFoot --> Menu : Esc
  Menu --> OnFoot : Esc
```
