# Changelog — ECHOES OF THE VOID

## 1.0.1 - 2026-11-04 (bug-fix update)
Your v1.0.0 saves and settings keep working. No story, level or balance changes.

### Fixed
- A pickup in the Exterior and an audio log in the Extraction Zone were stuck inside rocks/containers where nobody could reach them. Both are in the open now.
- Falling out of the world (player or enemy) no longer ends in an endless fall: you are put back on the last safe floor, enemies back at their post.
- The over-the-shoulder camera could end up outside the room next to walls. It now stays inside.
- Continue from a manual save no longer overwrites that save with a checkpoint save.
- A damaged or newer-version save no longer makes "Continue" appear and fail; the game falls back to the backup save.
- Touch and desktop HUD: the interact prompt no longer covers the USE button, the saving icon no longer sits on JOURNAL/PAUSE, the boss bar no longer covers health/ammo/lamp, toasts no longer cover the objective, subtitles clear the ammo box, and the Settings panel fits on narrow screens.
- A rapid second message no longer disappears early; the cutscene skip button no longer keeps its state between cutscenes.
- Quitting to the menu while a level is still loading can no longer leave a stray level or a stuck loading flag.

### Web build
- It looked flat and washed out. Cause: the dirt/grime layer is drawn wrongly by the browser renderer, so v1.0.0 turned it off and brightened everything instead. Now there is a browser-safe grime layer, 2x anti-aliasing, full render resolution and a new default "Web" quality. If your browser cannot hold 30 fps the game drops itself to Low once and tells you.
- The web build on phones was too dark (same cause); fixed. The browser version is still best on a desktop.

### Phones / Android
- Sun shadows use 2 cascades on the Mobile and Low presets (less GPU work). Version 1.0.1 (versionCode 2); installs over 1.0.0 (same signing key).

### Tests added
explore (161 reachability checks), v101 (31), ui_layout2 (1,460 rect checks), input_flows (57). All suites green: see TEST_REPORT.md.

## 1.0.0 — 2026-11-03 (first release)
First complete release, for Windows, Android and the web browser.

### Game
- Six areas: Cryo Bay, Research Wing, Security Sector, Reactor Core, the alien exterior and the Extraction Zone. Four missions (M01–M04), 15 audio logs and 14 checkpoints.
- Enemies:
  - Stalker: fast, flanks.
  - Sentinel: ranged, uses cover.
  - Brute: armoured front, charges.
  - The Herald: three-phase boss with slams, shard rain, summons and a beam sweep that cover blocks.
- Two weapons: pulse rifle and energy pistol. Medkits, ammo stations, and reactor steam/arc hazards with a warning phase.
- Puzzles: generator power-up, keypad codes, conduit routing.
- Five cinematics: wake, dead signal, reveal, climax, ending. All skippable, with subtitles.

### Look
- Realism pass on the astronaut:
  - new fitted helmet with a wrap-around gold visor;
  - detailed life-support pack with hoses;
  - one 2K PBR suit material with folds, seams, wear, grime and stencils.
- New escape shuttle (OSV-2 PERSEPHONE), with a working ramp and engines for the ending.
- Damaged wall sections: torn, bent-out plates with exposed ribs and cables and violet crystal pushing through, a pulsing crystal glow and a failing, flickering light strip (1–3 per interior area, never beside a door, with collision over the damage).
- Interiors are dressed with cable and pipe runs, vents, access panels, fire cabinets, ceiling cables, corner trim and reactor catwalks. Each area also has 60–100 decals: grime, leaks, stains, scorch, crystal residue, hazard tape, signage and the station logo.
- Per-area PBR themes, a grime overlay, volumetric fog, SDFGI/SSAO on higher presets and a custom sky.

### Controls and accessibility
- Keyboard and mouse, gamepad, and touch (stick, look pad and buttons sized for phones; interface scale auto = 1.35× on touch).
- Key rebinding. Every on-screen key hint follows your bindings.
- Settings: quality preset (Ultra to Mobile), resolution scale, FOV, sensitivity, invert Y, subtitles, interface size, show FPS, and volume per bus.
- How to Play screen with six pages, on the main menu and in pause.

### Technical
- Saves are versioned JSON with a backup copy and validation. Every checkpoint reload rebuilds the world from stable IDs.
- Kit geometry is batched into chunked MultiMeshes (worst views 15–23 M → 4–7 M primitives per frame), small props cast no shadows, and mesh LOD follows the preset.
- Enemy stuck recovery; AI debug overlay (F3 in debug builds).
- Headless test suite: full playthrough autotest, movement, AI, collision (0 pass-through in ~38k checks), balance bot, script compile, a cross-process save/quit/continue test and a damaged-wall probe.

### Fixed during development (highlights)
- The player could pass through props and enemies. Now everything has collision, with a dedicated test.
- The wake-up animation never played. Several imported models were placeholders until re-import. Near-black textures were normalised.
- Music loops dipped at the loop point; they now loop on the beat.
- Key hints ignored rebinding. Weapon 1/2 rebinding labels were swapped.
- The reactor reveal close-up was framed off Dr. Iyer's face; it now frames her face at eye level.
