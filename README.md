# ECHOES OF THE VOID

A cinematic third-person sci-fi action-adventure. You are Specialist Kabir Rao, waking from cryosleep on ORPHEUS
Research Station on the alien world NYX-7. Six areas, four missions, three enemy types, two weapons, three puzzles,
a three-phase boss and one ending; about 30–45 minutes. Fully offline.

A game by Sonujeet Dhanki (Mumbai, India). Engine: Godot 4.7.2. Models and animation: Blender 4.2.

## Run it
- Open `project.godot` in Godot 4.7.2 and press Play (F5). Main scene: `scenes/main.tscn`.
- Jump straight into an area: `godot --path . -- --area=reactor --mission=2`
- Shared test scene (player, terminal, door, pickup, enemy): `godot --path . res://scenes/test_environment.tscn`

## Tests (headless)
```
godot --headless --path . res://tests/check.tscn                         # every script compiles
godot --headless --path . -- --autotest                                  # full playthrough + saves/settings/checkpoints
godot --headless --path . --fixed-fps 60 -- --driver=move_test           # player mechanics through real input
godot --headless --path . --fixed-fps 60 -- --driver=ai_test             # AI behaviours + stuck recovery
godot --headless --path . --fixed-fps 60 -- --driver=collide             # no walking through walls/props/enemies
godot --headless --path . -- --driver=balance --jitter=6                 # combat balance bot
godot --headless --path . -- --driver=explore                           # v1.0.1: every objective/pickup/exit reachable (physical flood fill + real walk)
godot --headless --path . -- --driver=v101                              # v1.0.1 regressions: saves, falls, toast, camera sweep, web quality guard
godot --headless --path . -- --driver=ui_layout2                        # v1.0.1: HUD/touch/panel rects at 5 aspect ratios, touch on/off
godot --headless --path . -- --driver=input_flows                       # v1.0.1: touch input, pause/back, death/retry, quit/continue loops
xvfb-run godot --path . --rendering-method forward_plus -- --driver=perf # draw calls / primitives per area
```
After adding a new `class_name` script or changing any asset, run `godot --headless --path . --import` once.

## Export
Presets in `export_presets.cfg`: Windows Desktop, Linux, Web (Compatibility renderer), Android
(`com.sonujeet.echoesofthevoid`, Mobile renderer, arm64). `godot --headless --path . --export-release "<preset>" <out>`.

## Controls
Keyboard and mouse: WASD move · mouse look · Shift sprint · Space jump · C crouch · RMB aim · LMB fire · R reload ·
1 pistol / 2 rifle (or wheel) · E use · Q medkit · F helmet lamp · V swap shoulder · Tab inventory & logs ·
PgUp/PgDn or Ctrl+wheel camera distance · Esc pause · hold Enter to skip a cutscene. Every key can be rebound in
Settings → Change keys. Gamepad and touch are supported (Settings → How to Play lists them). F3 toggles the AI debug
overlay in debug builds.

## Saves and settings
`user://echoes_save.json` (+ `.bak` backup) and `user://echoes_settings.cfg`. On Windows `user://` is
`%APPDATA%\Godot\app_userdata\ECHOES OF THE VOID`.

## Docs
`docs/ARCHITECTURE.md` (systems), `docs/INTEGRATION.md` (IDs and signals), `docs/FOLDER_MAPPING.md`,
`docs/ASSET_SPEC.md`, `docs/ASSET_REGISTER.md`, `docs/POST_PRD_AUDIT.md`, `docs/ASSUMPTIONS.md`, `CREDITS.md`.
Blender sources: `../blender_src/` (outside the Godot project).

## Known limits
Built and tested on a machine without a GPU: frame rates on real PCs and phones are not measured yet
(Settings → Show FPS displays them). The Mobile preset targets mid-range Android phones.
