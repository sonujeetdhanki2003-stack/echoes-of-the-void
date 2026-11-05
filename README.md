# ECHOES OF THE VOID

A cinematic third-person sci-fi action-adventure. You are Specialist Kabir Rao, waking from cryosleep on ORPHEUS
Research Station on the alien world NYX-7. Six areas, four missions, three enemy types, two weapons, three puzzles,
a three-phase boss and one ending. About 30 to 45 minutes. Fully offline, no accounts, no ads, no in-app purchases.

Made by **Sonujeet Dhanki** (Mumbai, India). Current version: **1.0.1** (see [CHANGELOG.md](CHANGELOG.md)).

## Play it

- **In your browser** (works on phones too, best on a PC or a fast phone): https://echoes-of-the-void.sites.tab.bot/
- **itch.io** (Windows, Android and web builds): https://sonujeet.itch.io/echoes-of-the-void
- **Downloads** (Android APK and Windows zip): https://echoes-downloads.sites.tab.bot/download/

## Platforms

- Windows (64-bit, Forward+ renderer; the zip is unzipped and run from the folder)
- Android (arm64, Android 7.0 or newer, touch controls)
- Web browser (WebGL 2, Compatibility renderer)

## Controls

Keyboard and mouse: WASD move, mouse look, Shift sprint, Space jump, C crouch, RMB aim, LMB fire, R reload,
1 pistol / 2 rifle (or mouse wheel), E use, Q medkit, F helmet lamp, V swap shoulder, Tab inventory and logs,
PgUp/PgDn or Ctrl+wheel camera distance, Esc pause, hold Enter to skip a cutscene. Every key can be rebound in
Settings, then Change keys. Gamepad and touch are supported (Settings, then How to Play, lists them).

## Saves and settings

Saves are in `user://echoes_save.json` (with a `.bak` backup) and settings in `user://echoes_settings.cfg`.
On Windows `user://` is `%APPDATA%\Godot\app_userdata\ECHOES OF THE VOID`.

## Build it yourself

Requirements: **Godot 4.7** (4.7.2 is what this build uses, standard build, GDScript only).

1. Clone this repo, then in the Godot Project Manager choose Import and pick `project.godot`.
2. Import the assets once: `godot --headless --path . --import`
3. Run it: open the project and press F5 (main scene `scenes/main.tscn`), or jump into an area with
   `godot --path . -- --area=reactor --mission=2`.
4. Export: the presets are in `export_presets.cfg` (Windows Desktop, Linux, Web, Android). Output goes to `build/`.
   Export with `godot --headless --path . --export-release "<preset>" build/<file>`.

No signing keys are in this repository. Android release signing reads Godot's `GODOT_ANDROID_KEYSTORE_RELEASE_*`
environment variables; use your own key.

Tests (headless): `godot --headless --path . --import` then `godot --headless --path . -- --autotest`, plus the
drivers listed in [TEST_REPORT.md](TEST_REPORT.md).

## Large assets (not in this repo)

To fit GitHub's upload limits, one file over 3 MB is not in this repo: `assets/models/astronaut.glb` (5.7 MB).
Large assets are in the release downloads and the source zip above. Everything else (all code, scenes, shaders,
data, tests, the other models, textures, sounds, music and fonts) is here.

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [BUGS_FOUND.md](BUGS_FOUND.md): the v1.0.1 bug hunt, one row per bug, with the test that guards each fix
- [TEST_REPORT.md](TEST_REPORT.md): what was tested for v1.0.1 and how, and what was not
- [CREDITS.md](CREDITS.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): every third-party asset and its licence
- `docs/`: architecture, integration notes, asset specs and register, and the post-PRD audit

## AI assisted

AI assisted: code, sounds, text. Design, direction and final decisions are the author's. The sounds and voices
were generated with AI tools and then edited and mastered for the game; the credits list where each set came from.

## Known limits

The build was tested headless on a machine without a real GPU, plus a Windows build run under Wine. Frame rates on
real PCs and phones are not measured yet (Settings can show FPS). Not yet tested on a real Android phone install.

## License

**Source-available, all rights reserved.** You're welcome to read the code; you may not copy, modify, redistribute
or republish it or the game. See [LICENSE](LICENSE). Third-party assets keep their own licences (see CREDITS.md).
