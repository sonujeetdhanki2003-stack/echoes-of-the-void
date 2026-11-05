# Folder structure — roadmap mapping

The Post-PRD roadmap (Phase 1.2) proposes a folder tree. The project was built before that document arrived, and every
script, scene and asset path is referenced from code (`res://...`) and from Godot's import cache. Moving folders now
would break those references for no gameplay gain, so the layout is kept and this table maps the roadmap's folders
to where the same things live. (Roadmap rule: "Do not overwrite working systems without checking dependencies.")

| Roadmap folder | In this project | Notes |
|---|---|---|
| assets/characters | `assets/models/astronaut.glb`, `crew*.glb`, `crystal_figure.glb`, `corpse_*.glb` | each GLB has a `.json` sidecar (size, clips, sockets, materials) |
| assets/enemies | `assets/models/stalker.glb`, `sentinel.glb`, `brute.glb`, `herald.glb` | stats in `data/enemies/*.tres` |
| assets/weapons | `assets/models/pulse_rifle.glb`, `energy_pistol.glb` | stats in `data/weapons/*.tres` |
| assets/environments | `assets/models/env/` (modular kit `kit_*.glb`, props, exterior rocks/plants/crystals, shuttle) | |
| assets/materials | built in code: `scripts/world/themes.gd` (per-area PBR sets), `scripts/world/props.gd` (detail maps) | |
| assets/textures | `assets/textures/` (tiling PBR sets), `assets/textures/decals/` | |
| assets/animations | inside each character GLB (31 player clips, enemy clips) | blended by `scripts/player/player_anim.gd` (AnimationTree) |
| assets/audio, audio/ | `assets/audio/{music,sfx,amb,vo}` | buses + mix in `scripts/core/audio_manager.gd` |
| assets/particles | `scripts/fx/fx.gd` (GPU/CPU particles built in code) | |
| assets/cinematics | `scripts/cinematics/cinematic.gd` + each area's cinematic function | camera paths are AnimationPlayer tracks built at runtime |
| scenes/* | `scenes/main.tscn`; areas, player, enemies and UI are built from scripts | one boot scene, everything else is code-built so it stays diffable |
| scripts/player | `scripts/player/` | movement, camera (SpringArm3D), animation |
| scripts/combat | `scripts/components/combat_component.gd`, `scripts/weapons/` | |
| scripts/enemies | `scripts/ai/` | state-machine AI, perception, boss |
| scripts/interaction | `scripts/interact/`, `scripts/components/interaction_component.gd` | |
| scripts/inventory | `scripts/components/inventory_component.gd` | inventory screen in `scripts/ui/ui.gd` (`_inventory_block`) |
| scripts/quests | `scripts/core/mission_manager.gd` + `data/missions.tres` | 4 missions, objective flags |
| scripts/save_system | `scripts/core/game.gd` (`save_game`, `load_game`, `_valid`) | versioned JSON + .bak fallback |
| scripts/managers | `scripts/core/` | autoloads: Events, Game, Sfx, Missions, GameMode |
| shaders | `shaders/` | sky, grime overlay, crystal, etc. |
| resources | `data/` | `.tres` data resources (enemies, weapons, missions) + JSON (logs, dialogue) |
| ui | `scripts/ui/` | menus, HUD, touch controls, conduit puzzle view |
| tests | `tests/` | autotest, collision, balance, mix capture, perf probe, shots, cinematic recorder |
| documentation | `docs/` | this file, audit, asset spec, credits |

Roadmap manager names → autoloads: GameManager = `Game` + `GameMode`; SceneManager = `GameMode.load_area`;
AudioManager = `Sfx`; SaveManager = `Game` (save/load); InputManager = `Game._setup_input` / `apply_bindings`;
UIManager = `GameMode.ui` (`scripts/ui/ui.gd`); QuestManager = `Missions`; InventoryManager = the player's
`InventoryComponent` (inventory belongs to the player, so it is a component, not a global).

## Doc 03 named scenes (thin wrappers, all tested)
| Doc 03 name | File | What it does |
|---|---|---|
| Main.tscn | `scenes/main.tscn` | boot scene (world root + UI + autoload registration) |
| MainMenu.tscn | `scenes/MainMenu.tscn` | the same boot, which opens on the main menu |
| TestEnvironment.tscn | `scenes/test_environment.tscn` | floor, blocks, crouch bar, camera wall, terminal → door, medkit, dormant Stalker, player |
| Player.tscn | `scenes/player/Player.tscn` | CharacterBody3D with `player.gd` (builds VisualRoot, CameraPivot/SpringArm3D/Camera3D, components in `_ready`) |
| cryo_chamber.tscn (and the other 5 areas) | `scenes/levels/{cryo_chamber,research_wing,security_sector,reactor_core,alien_exterior,extraction_zone}.tscn` | boots the game straight into that area (`level_boot.gd`) |
| pulse_rifle.tscn, energy_pistol.tscn | `scenes/weapons/` | the weapon model + its WeaponData resource |
Evidence: move_test "named scenes instantiate (Player, weapons, levels, MainMenu)"; `godot --headless res://scenes/levels/reactor_core.tscn -- --quit_after=20` prints "LEVEL BOOT loaded area reactor with player true".
