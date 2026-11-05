# ECHOES OF THE VOID — Test report, v1.0.0

Build version **1.0.0** (menu shows v1.0.0; Android versionCode 1). Date 2026-11-03 (UTC). Game code at commit `68b5d68`
(the release tag `v1.0.0` adds only docs on top). Godot 4.7.2. Every result below was produced on the build machine,
which has **no GPU** (CPU rendering only); see "Untested on real hardware". Logs: `/home/user/tab/files/echoes-v1.0.0/test_logs/`.

## Builds

| Build | File | Size | SHA-256 | How it was tested |
|---|---|---|---|---|
| Windows 64-bit | EchoesOfTheVoid-1.0.0-Windows.zip (exe with embedded data, README, CHANGELOG, CREDITS) | 141,796,458 B | `a9aabf1ef5fe3bf9ff6bab586b472c3378bba28b0871e59064b88a61352f1dd2` | Unzipped into an empty folder and run under wine-11.0 headless: full playthrough autotest **100/100** (`wine_autotest.log`), save → quit → relaunch → Continue across two processes **15/15** (`wine_save_write.log`, `wine_save_read.log`; save landed in `%APPDATA%\Godot\app_userdata\ECHOES OF THE VOID`). |
| Android (arm64) | EchoesOfTheVoid-1.0.0-Android.apk | 158,604,494 B | `b527f269dc851b02e3e16a8b88b95e70546d2af639a62cbef86cd29e0dcc187c` | `apksigner verify`: v2 + v3 signatures valid, 1 signer CN=Sonujeet (release keystore), cert SHA-256 `815776e6…0775`. `aapt2`: package `com.sonujeet.echoesofthevoid`, versionCode 1, versionName 1.0.0, minSdk 24, targetSdk 36, `screenOrientation` sensorLandscape, native code arm64-v8a, no permissions, Vulkan required (`apk_verify.log`). **Not installed on a phone** (no device or emulator here). |
| Web (desktop browsers) | https://echoes-of-the-void.sites.tab.bot/ (Compatibility renderer, 192 parts of 880 KiB + loader) | 172,683,362 B in 200 files | per file | curl -L of all 200 live files: sha256 identical to the build (`web_live_verify.log`). Headless Chromium (SwiftShader) on the **live** URL: download done in ~7 s, menu → New Game → Normal → wake cinematic with subtitles; **0 page errors**, 1 engine warning (below) (`web_live_chromium.log`, `web_live_menu.jpg`, `web_live_game.jpg`). |
| Downloads page | https://echoes-downloads.sites.tab.bot/download/ (`/android`, `/windows` short links) | — | — | Both files and both short links downloaded with curl -L: byte-exact (sha256 above), `Content-Length` exact, byte ranges (206) exact for a middle slice and the tail; 357/357 static files identical (`downloads_live_verify.log`). Rendered on a phone-sized viewport with 0 page errors. |
| Source | EchoesOfTheVoid-1.0.0-source.zip (game/ at tag v1.0.0, blender_src/, design notes) + a dated git bundle | — | — | Unzipped into an empty folder: `--import`, then CHECKED 88 scripts 0 failed and MOVETEST 24/24 (`source_zip_test.log`); `git bundle verify` okay. |
| Trailer | EchoesOfTheVoid-1.0.0-trailer.mp4 | 13,369,767 B | — | 63.0 s, 1920×1080 H.264 24 fps + AAC; loudness −15.4 LUFS, true peak −1.2 dBTP, no silent gaps (audio-proof); every frame range looked at as a contact sheet; voice lines transcribed back correctly. |

## Automated tests (headless, this machine)

| Suite | Command | Result |
|---|---|---|
| Script compile | `godot --headless --path . res://tests/check.tscn` | CHECKED 88 scripts, 0 failed |
| Full playthrough | `godot --headless --path . -- --autotest` | **AUTOTEST 100/100** (140.4 s) |
| Same, network disabled | `unshare -rn godot … -- --autotest` | **100/100** (132.6 s) — fully offline |
| Player mechanics (real input) | `--fixed-fps 60 -- --driver=move_test` | MOVETEST 24/24 |
| Enemy AI | `--fixed-fps 60 -- --driver=ai_test` | AITEST 9/9 |
| Collision | `--fixed-fps 60 -- --driver=collide` | COLLIDE 37,812 checks, 0 failures (no walking through walls, props or enemies) |
| Combat balance bot | `-- --driver=balance --jitter=6` | 9/9 scenarios: every enemy mix killed by shooting, with both weapons |
| Damaged walls | `-- --driver=dress_probe` | DMGTEST 28/28 (1–3 per area, none beside a door, damage blocked, rest walkable, crystal pulse, light flicker) |
| Save across processes | `-- --driver=save_xproc --phase=write`, then a new process `--phase=read` | XPROC 15/15 |
| UI layout | `-- --driver=ui_layout` (1600×720, 2400×1080, 1280×720, 1920×1080) | 0 overlaps |
| Figure facing | `-- --driver=fig_probe` | FIGTEST PASS |
| Draw calls | `xvfb-run godot --rendering-method mobile -- --driver=perf --quality=mobile` | phone preset: 65–157 draw calls, 0.36–0.90 M primitives per frame in the four interiors (`perf_mobile.log`); High preset on Forward+: 3,608 (cryo) / 5,580 (reactor) draws; Mobile preset on Forward+: 601 / 1,342 (`perf_fwd.log`) |

## Route covered by the playthrough test
New game → wake cinematic (skippable) → **M01 Awakening** (Cryo Bay: bay door panel, pistol, first stalker, generator
puzzle with a wrong order first, bulkhead) → **M02** (Research Wing: code clue logs, keypad with a wrong code then 0417;
Security Sector: rifle, brute, comms) → **M03** (Reactor Core: hazards deal damage, Dr. Iyer's lab, conduit puzzle,
survival waves) → Alien Exterior → **M04 Last Transmission** (Extraction Zone: transmission, the Herald's three phases
killed with rifle hits on its nodes) → shuttle ramp → ending cinematic → credits. Then: completion saved, Continue,
inventory/log screen, restart checkpoint, death and respawn with full health, corrupt save falls back to the backup,
invalid save rejected, all 15 checkpoints reloaded one by one, 15/15 logs findable, 94 unique stable IDs, settings
(11 values) persist across a restart, rebinding (incl. swap and reset) and key hints, subtitles clear the letterbox and
the touch controls. The bot shoots most enemies itself; a few it cannot reach in time are removed by the test
("forced kills", 6–10 per run) — those fights are covered separately by the balance bot.

## Defects found and fixed in the release pass
1. Trailer was 58 s and 25.9 MB (spec: 60–90 s, under 15 MB) → re-cut to 63 s / 13.4 MB; the brute shot showed its back → re-cut from the front; audio peaked at +0.35 dBTP after encoding → −1.2 dBTP.
2. Damaged walls: research had 4, cryo none, some sat beside doors, and the collision box stopped ~4 cm short of the bent plates → capped at 3 per area, never beside a door, collision matches the damage; crystal pulse and a failing-light flicker added (own material copies, intact walls stay steady).
3. Web: a "Pointer Lock needs a user gesture" page error, an FXAA warning (not in the Compatibility renderer) and an occlusion-culling warning → guard added, FXAA skipped on Compatibility, occlusion culling off for web. A 172 MB download showed no progress → progress bar overlay.
4. CHANGELOG claimed a Linux build and described one fix wrongly → corrected.
Earlier fixes from development are listed in CHANGELOG.md ("Fixed during development").

## Known issues (deferred)
- Web: one engine warning remains in the console ("Occlusion culling is disabled at build-time", printed once at the first area load; harmless). Web uses the Compatibility renderer: no SDFGI, SSAO or volumetric fog, so it looks flatter than Windows. Made for desktop browsers; phone browsers are pointed to the APK. The mouse locks on the first click in the game.
- Android: arm64 only, needs a phone with Vulkan (standard on current Android phones; not yet tried on the realme P3). No themed (monochrome) icon on Android 13+.
- Windows: the exe is not code-signed, so SmartScreen asks once ("More info" → "Run anyway").
- The astronaut's shoulder touches the helmet for two frames of the heal animation (noted by the model helper).
- ui.gd still holds menus, HUD, settings and journal in one 1,200-line script (works; a split is planned after v1.0).
- Frame times on this machine are CPU-rendered and say nothing about real FPS; Forward+ on the exterior and extraction maps crashes this machine's software renderer (LLVM), so those two areas were checked with the Mobile and Compatibility renderers here.

## Untested on real hardware (needs Sonujeet)
- FPS, stutter, memory and load times on a real PC GPU and on the realme P3 (Settings → Show FPS shows FPS, frame time and GPU). The roadmap target is a stable 60 FPS.
- Windows audio output, keyboard/mouse feel and a gamepad on real hardware (Wine ran headless, without sound or input).
- Android: install, touch controls, back button = pause, thermal/battery, and saves on the phone.
- Web in a real desktop browser with a GPU (Chrome/Edge/Firefox) and its audio.
- A full human playthrough: the 30–45 minute length, difficulty feel, whether a first-time player finishes without help, and whether the story reads clearly.
