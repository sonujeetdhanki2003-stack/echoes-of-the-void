# ECHOES OF THE VOID v1.0.1 - bugs found

Every item: how it was found, the fix, the test that now guards it. Saves from v1.0.0 load unchanged (save format untouched).

| # | Bug | Found by | Fix | Regression test |
|---|-----|----------|-----|-----------------|
| 1 | Mission pickup `ext_m1` (Exterior) sat inside a rock - unreachable, could block the Exterior objective | new `explore` driver: physical capsule-sweep flood fill (0.5 m grid, step/jump/crouch rules) from the spawn, every pickup/log/console/exit must be reachable | moved to a clear spot (-9.0, 0.1, -72.5) in `area_exterior.gd` | `--driver=explore` (161 checks, all 6 areas; also walks the real player to every checkpoint and exit) |
| 2 | Log pickup #13 (Extraction) was inside the cargo containers - log unobtainable, "all logs" impossible | same `explore` run | moved to (5.0, 0, 2.2) | `--driver=explore` |
| 3 | Player could fall out of the world (below any floor) and fall forever; nothing recovered them | code audit of death/fall paths, then `v101 fall` (teleport below the floor, step physics) | `Player.recover_from_fall()`: last safe floor position sampled every 0.4 s, FALL_LIMIT 40 m, hard floor at y < -300; `place()` also sets the safe position | `--driver=v101` (fall 5/5) |
| 4 | Enemies knocked/pushed out of the world kept falling (never counted, boss/objective gating could wait on them) | same | `enemy_base.gd`: `_home` captured on first physics frame, an enemy more than 40 m below it is put back | `--driver=v101` |
| 5 | Toast race: a new toast's text was hidden early by the previous toast's still-running fade tween | UI loop test (two toasts 0.3 s apart) | `ui.gd`: keep `_toast_tw` and kill it in `toast()` | `--driver=v101` (ui) |
| 6 | Cutscene skip-button state (`_skip_touch/_skip_hold`) carried into the next cinematic - skip started half-filled or stuck | touch/cinematic loop | reset in `_on_cinematic` | `--driver=v101` (ui) |
| 7 | An invalid or newer-version save made Continue look available (and could not load) instead of falling back to the `.bak` | save-validity test (garbage, empty, future version, missing keys) | `Game._usable_save()`; `has_save()`/`save_info()` ignore unusable saves but still fall back to `.bak` | `--driver=v101` (saves 15/15) |
| 8 | Continuing from a MANUAL save (pause > Save) overwrote it with a checkpoint save, losing the saved position | save-position test | `load_area(..., from_manual)` keeps the manual save | `--driver=v101` |
| 9 | Over-the-shoulder camera could end outside the room beside walls (arm origin inside the wall, so the spring arm found no hit) | camera sweep: 756 positions along walls | `player_controller.gd`: `_side_limit()` (sphere cast + overlap step-back); 65 bad samples -> 0 | `--driver=v101` (camera, 756 samples) |
| 10 | HUD overlaps (touch and desktop): interact prompt over the USE button, saving icon over JOURNAL/PAUSE, boss bar over vitals/ammo/lamp, toast over the objective text, subtitle over the ammo box on desktop, Settings panel wider than the screen (unwrapped keys line) | new `ui_layout2` driver: measures every HUD/touch rect against the visible viewport and each other at 20:9, 16:9, 4:3 and 19.5:9, touch on and off | prompt centred and per-mode offset, saving icon moved, boss bar width fitted between vitals and buttons, toast per mode, subtitle raised on desktop, keys line wrapped | `--driver=ui_layout2` (1,460 checks, 0 problems) |
| 11 | Web build looked flat, washed out and edgy vs desktop | side-by-side renders (Compatibility vs Forward+) with luminance/contrast stats | see "Web look" in CHANGELOG: root cause is the grime overlay + `low` defaults, below | screenshots in TEST_REPORT; `--driver=v101` (web profile, migration, guard) |
| 11a | The grime overlay (`blend_mul`) renders almost BLACK in the Compatibility renderer (mean luminance 31 vs 122 with it off), so v1.0.0 skipped it on web and used ambient x1.6 - the "flat" look. On web PHONES the overlay was still on (quality `mobile`), so the scene was far too dark | render A/B with `--nogrime`; strength 0 still dark, so the multiply itself is wrong in that renderer | new `grime_overlay_compat.gdshader` (alpha mix, same look), used only on gl_compatibility; large surfaces only there (draw-call cost); skipped on web phones | v101 web tests + renders |
| 11b | Web had no anti-aliasing at all and rendered at 0.85 scale | project settings audit | desktop browsers: 2x MSAA, scale 1.0, new default quality `web` (was `low`) | v101 |
| 12 | `load_area` could clear the `loading` flag of a NEWER load, or build an area after the player had gone back to the menu | code audit of the quit-to-menu-during-load path, then 5 timed quit-mid-load runs | session checks after every await; stale loads free their own area and never touch `loading` | `--driver=input_flows` (quit 2/30/60/90/120 frames into a load leaves no area behind) |
| 13 | A slow browser stayed on the heavy look forever (web look costs ~1.7x the draw calls of `low`) | perf probe numbers | performance guard: under 28 fps for 6 s in game -> switches to Low once, says so with a toast, remembers | `--driver=v101` |

## Checked and found OK (tests added, no bug)
- Touch: stick, look, FIRE hold, JUMP tap, AIM toggle, USE at a console, multi-touch (stick+look+fire together), pause releases every finger (`input_flows`, 57 checks).
- Android back button / OS back request in play, pause, settings, how-to, journal, death screen, main menu.
- Death -> Retry x3, Quit -> Continue x3: exactly one area afterwards, no looping sounds left after quitting to the menu.
- Camera/collision: collide 37,812 checks, 0 failures (unchanged).

## Audit items re-checked (docs/POST_PRD_AUDIT.md / GAPS.md)
- #4b lambda-capture errors: closed (0 "Lambda capture" lines in autotest, collide and balance logs of this release).
- #19 damaged wall module: closed (`kit_wall_damaged.glb` is generated by the level builder; used by `level_builder.gd`).
- Decals: closed (placed in the v1.0.0 pass).
- Unused kit pieces `kit_railing`, `kit_ramp`, `kit_stairs`: NOT changed. They are in the manifest but no level uses them; placing them would change level layouts (not a bug fix), deleting changes the import set. No gameplay effect.
- `blender_src/` folders: NOT fixed on this box. The .blend sources of the later passes are spread over helper task folders of earlier workers and cannot be matched to ECHOES with certainty; no gameplay effect.
- Needs real hardware/people (cannot be done here): GPU frame rate, memory and load times on a PC and a phone, Windows audio/input on real hardware, Android install and touch on a real phone, first-timer playtest, story comprehension, 30-45 min human playthrough.

## Known and still open
- The Windows exe is unsigned (SmartScreen will warn). No code-signing certificate.
- The heal clip of the astronaut has 2 frames (looks like a snap, not a bug).
- The autotest force-kills 6-10 enemies to keep the run short (7 this run); the combat itself is covered by `balance` and `ai_test`.
- Primitive counts per frame stay high in Research (~660k) and Reactor (~900k) on the phone preset; draw calls are low (65-160). Needs a real phone to know if it matters.
