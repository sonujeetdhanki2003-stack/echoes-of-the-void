# ECHOES OF THE VOID — architecture

Godot 4.7.2 · GDScript · ~11,500 lines in 60+ gameplay scripts · 3 shaders · one boot scene (`scenes/main.tscn`).
Everything else (areas, player, enemies, UI, cinematics) is built from scripts, so the whole game is plain text and
diffs cleanly in git. The Master PRD was written for Unreal Engine 5 Blueprints; this build keeps its modular
architecture and maps each UE5 concept to its Godot equivalent.

## 1. UE5 → Godot mapping (Master PRD §4)
| PRD (UE5) | This game (Godot 4.7) | Where |
|---|---|---|
| GameMode / GameInstance | autoload singletons `Game` (settings, state, save), `GameMode` (area loading, player, combat state, checkpoints) | scripts/core/game.gd, game_mode.gd |
| Event Dispatchers | a global signal bus `Events` (24 signals) + local component signals | scripts/core/events.gd, docs/INTEGRATION.md |
| Actor Components | child component nodes: HealthComponent, CombatComponent, InteractionComponent, InventoryComponent | scripts/components/ |
| BPI_Interactable | `Interactable` base class (group `interactable`): `can_interact / interact / prompt / focus_point` | scripts/interact/interactable.gd |
| Behaviour Trees + Blackboard | `EnemyBase` state machine (IDLE, PATROL, INVESTIGATE, ALERT, CHASE, ATTACK, REPOSITION, STAGGER, DEAD, DORMANT) + per-type `think()`; `Perception` (sight cone + line of sight, hearing, alert sharing) | scripts/ai/ |
| AI MoveTo / NavMesh | `NavigationAgent3D` on a navmesh baked per area at load (static colliders in group `nav_source`) + stuck recovery | enemy_base.gd:nav_to |
| Data Tables | `Resource` files: EnemyData, WeaponData, MissionList; JSON for logs and dialogue | data/ |
| SaveGame | versioned JSON with stable IDs + `.bak` fallback + validation | game.gd:save_game/load_game/_valid |
| Sequencer | `Cinematic`: camera shots baked into an `AnimationPlayer` at runtime, timed events, skippable, letterbox | scripts/cinematics/cinematic.gd |
| Level streaming | one area scene at a time, loaded behind a fade with an autosave checkpoint | game_mode.gd:load_area |
| Materials / post process | per-area PBR theme sets, detail maps, grime overlay shader, ACES/AgX tonemap, glow, fog, SSAO/SDFGI on Forward+ | scripts/world/themes.gd, props.gd, shaders/ |

## 2. Runtime structure
```
main.tscn (Main)
├── WorldRoot
│   └── Area_<id>  (extends Area: build() makes geometry, props, lights, enemies, triggers, checkpoints)
│       ├── Geo (kit + dressing MultiMeshes, chunked 12 m) · Dressing (decals) · Nav (NavigationRegion3D) · WorldEnvironment · Sun / lights
│       ├── Props, Interactables (Door, Console, Pickup, LogPickup, Generator, Keypad, ConduitConsole, HazardZone…)
│       ├── Enemies (Stalker / Sentinel / Brute / Herald)
│       └── Player (CharacterBody3D)
│           ├── VisualRoot (astronaut GLB, AnimationTree from player_anim.gd, weapons on bone prop.R)
│           ├── CameraPivot/SpringArm3D/Camera3D (player_controller.gd)
│           └── Health / Combat / Interaction / Inventory components
└── UI (CanvasLayer: HUD, menus, settings, journal/inventory, touch controls, overlays, subtitles, credits)
Autoloads: Events · Game · Sfx (audio buses, music states, VO + subtitles) · Missions · GameMode
```

## 3. Flow of one frame of play
1. `PlayerController` reads input (keyboard/mouse, gamepad, or the touch layer) → `Player.move_input`, aim, fire.
2. `Player._physics_process` moves the capsule (accel/decel, sprint stamina, jump buffer + coyote time, crouch).
3. `CombatComponent` fires the current `WeaponBase` (hitscan ray → `take_hit` on enemies / Herald nodes, tracers,
   impacts, noise event for AI hearing).
4. Enemies: `Perception.update` → `think()` picks a state → `nav_to` steers → `move_and_slide`.
5. Systems talk through `Events`: e.g. a kill → `enemy_killed` → stats; a flag → `flag_set` → `Missions` recomputes
   the objective → `objective_changed` → HUD.

## 4. Missions, flags and saves
- The world state is a set of **flags** keyed by stable IDs (`door.cryo_bay`, `puzzle.generators`, `dead.res_s1`,
  `used.log.5`, `trig.cryo_vent`…). Areas read flags while building, so reloading any checkpoint rebuilds the
  world exactly as the player left it.
- An objective is complete when its flag is set; the current objective is computed, never stored, so it cannot
  desync (autotest: every checkpoint of a full run is reloaded and checked for the same mission and objective).
- Saves: `user://echoes_save.json` (+ `.bak`), version field, validated on load, corrupt → backup.

## 5. Rendering and quality presets
| preset | renderer features |
|---|---|
| Ultra | Forward+: SDFGI, SSAO, SSIL, SSR, volumetric fog, 4K shadows |
| High (desktop default) | SDFGI, SSAO, volumetric fog, 4K shadows |
| Medium | SSAO, volumetric fog, 2K shadows |
| Low | no screen-space effects, 1K sun shadow, no omni shadows, coarser mesh LOD |
| Mobile (Android default) | Mobile renderer, as Low plus fewer particles and shorter view distance |
Kit pieces are MultiMesh batches split into 12 m chunks (culling + shadow culling), props under 0.9 m cast no
shadows, occluders and visibility ranges are set per area, lights fade their shadows first with distance.

## 6. Tests (all headless)
| command | what it proves |
|---|---|
| `godot --headless -- --autotest` | full playthrough new game → credits through the real systems, plus settings, saves, every checkpoint reload |
| `--fixed-fps 60 -- --driver=move_test` | player mechanics through the real input path (speeds, jump, crouch, camera collision, weapons, reload, medkit) |
| `--fixed-fps 60 -- --driver=ai_test` | patrol → chase → investigate → patrol, sentinel repositioning, brute charge, stuck recovery |
| `--fixed-fps 60 -- --driver=collide` | the player never passes through walls, props or enemies (~38k checks) |
| `-- --driver=balance --jitter=6` | a bot with phone-like aim error fights each encounter (time to kill, damage taken) |
| `res://tests/check.tscn` | every script compiles |
