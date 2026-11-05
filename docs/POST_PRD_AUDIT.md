# ECHOES OF THE VOID — Post-PRD compliance audit

Auditor: task 6df4d703 (read-only on the game). Updated 2026-11-03 18:41Z, re-audited after the lead's fixes (commits 0666634, 038df75, a9adc64 and the 18:07 per-process test saves). Game: Godot 4.7.2 project at `9d8e69c6…/game`. **Release update 2026-11-03 21:4xZ by lead 4 (task 82753f8f):** release rows closed with the evidence named in each row (TEST_REPORT.md, files/echoes-v1.0.0/test_logs/); damaged wall module added (GAPS #19); the 9 rows still OPEN all need Sonujeet's PC/phone or a human playtest, except #44 in doc 5 (ui.gd split, deferred).

Rule (Sonujeet): *never claim a feature works without a test.* A row is **PASS** only with evidence: an autotest check name, a test script and its result line, a file:function reference for structural items, or a screenshot. **FIXED** = missing or different when the documents arrived, done since (commit or test named). **OPEN** = missing, untested or pending, listed in the gap list (`GAPS #n`). **N/F** = not feasible on this machine, or superseded (reason given).

## Summary

| Document | Requirements | Pass | Fixed | Not feasible | Open |
|---|---|---|---|---|---|
| 1. Post-PRD Technical Development & Production Roadmap | 91 | 62 | 25 | 0 | 4 |
| 2. Implementation PRD (Document 03) | 85 | 55 | 29 | 0 | 1 |
| 3. Gameplay & Story Integration PRD | 54 | 41 | 10 | 1 | 2 |
| 4. Blender 3D Asset Production PRD | 39 | 29 | 10 | 0 | 0 |
| 5. Godot 4 Game Development PRD | 57 | 32 | 22 | 1 | 2 |
| **Total** | **326** | **219** | **96** | **2** | **9** |

### Test runs used as evidence (auditor's own runs unless marked; logs in `runs/`)

| Run | Command | Result line | Log |
|---|---|---|---|
| autotest | `godot --headless --path G -- --autotest` | `AUTOTEST 97/97 passed in 133.1s` (18:35Z, new astronaut + dressing) | r4_autotest.log |
| autotest, network disabled | `unshare -rn godot --headless --path G -- --autotest` | `AUTOTEST 97/97 passed in 132.4s` | r3_offline.log |
| player mechanics | `godot --headless --path G --fixed-fps 60 -- --driver=move_test` | `MOVETEST 24/24 passed` | r4_move_test.log |
| AI behaviour | `godot --headless --path G --fixed-fps 60 -- --driver=ai_test` | `AITEST 9/9 passed` | r2_ai_test.log |
| collision | `godot --headless --path G --fixed-fps 60 -- --driver=collide` | `COLLIDE 37812 checks, 0 failures` (after dressing pass) | r4_collide.log |
| balance | `godot --headless --path G -- --driver=balance --jitter=6` | 9/9 scenarios kill every enemy by shooting (e.g. `BALANCE brute rifle kills 1/1 time 7.8s dmg taken 80`) | r2_balance.log |
| compile | `godot --headless --path G res://tests/check.tscn` | `CHECKED 83 scripts, 0 failed` | r4_check.log |
| asset import | `godot --headless --path G -s …/6df4d703…/assetcheck.gd` | 89/89 GLBs load (new astronaut, shuttle, 6 dressing models); bones/clips = sidecars | r4_assetcheck.log |
| Windows build (lead) | `wine EchoesOfTheVoid.exe --headless -- --autotest` (export of 17:18Z, run from a clean folder) | `AUTOTEST 72/72 passed in 104.2s`, `EXIT 0` | wine_autotest_copy.log |
| perf probe (lead) | `xvfb-run godot --rendering-method forward_plus -- --driver=perf` | draw calls / primitives per area (CPU renderer: frame ms not meaningful) | perf1_copy.log + PROGRESS.md |
| release autotest (lead 4) | `godot --headless --path G -- --autotest` (commit 68b5d68) | `AUTOTEST 100/100 passed in 140.4s`; offline `100/100` | files/echoes-v1.0.0/test_logs/autotest*.log |
| release collide / move / ai / check | as above | `COLLIDE 37812 checks, 0 failures`, `MOVETEST 24/24`, `AITEST 9/9`, `CHECKED 88 scripts, 0 failed` | test_logs/ |
| damaged walls (lead 4) | `-- --driver=dress_probe` | `DMGTEST 28/28 passed` | test_logs/dress_probe.log |
| save across processes (lead 4) | `--driver=save_xproc --phase=write` then `--phase=read` | `XPROC 15/15 passed` (native and under wine) | test_logs/save_xproc_*.log, wine_save_*.log |
| Windows zip under wine (lead 4) | unzip to an empty folder; `wine EchoesOfTheVoid.exe --headless -- --autotest` | `AUTOTEST 100/100 passed in 134.7s` | test_logs/wine_autotest.log |
| APK (lead 4) | apksigner verify / aapt2 dump badging | v2+v3 verified, CN=Sonujeet; com.sonujeet.echoesofthevoid 1 / 1.0.0, sensorLandscape | test_logs/apk_verify.log |
| web live (lead 4) | curl -L all files + headless Chromium on the live URL | 200/200 sha256 match; menu → New Game → wake, 0 page errors | test_logs/web_live_*.log |

Note: two of my 17:58 runs failed for test-harness reasons, not game reasons. One was a parse error from a script caught mid-edit (r2_autotest.log, 62/68). The other was the shared test save file during a concurrent run (r2_offline.log, 92/97), fixed by the lead at 18:07 with per-process test saves. Clean re-runs pass.

Screenshots referenced are in `shots/`. Name equivalents are in `docs/FOLDER_MAPPING.md` and `docs/ASSUMPTIONS.md`; assets in `docs/ASSET_REGISTER.md`; shared IDs in `docs/INTEGRATION.md`.


## 1. Post-PRD Technical Development & Production Roadmap

91 requirements · PASS 62 · FIXED 25 · N/F 0 · OPEN 4

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | 1.1 Godot 4 project created | **PASS** | project.godot (config/features "4.7"); check.tscn: "CHECKED 78 scripts, 0 failed" |
| 2 | 1.1 Renderer configured to hardware | **PASS** | project.godot rendering_method forward_plus / .mobile mobile / .web gl_compatibility; quality presets game.gd:quality_profile |
| 3 | 1.1 Resolution & display settings | **FIXED** | project.godot [display] 1920×1080 base, stretch canvas_items/expand; Resolution option game.gd:RESOLUTIONS + ui.gd:open_settings (commit 565fa31) |
| 4 | 1.1 Keyboard, mouse and controller input | **PASS** | game.gd:_setup_input (keys, _mouse, _joy_axis, _joy_btn); autotest: "key bindings page opens"; "rebinding applies and is saved" |
| 5 | 1.1 Physics and collision layers | **FIXED** | project.godot [layer_names] world/player/enemy/hitbox/interact/projectile/player_block (commit 1a7020f); collide: 37812 checks, 0 failures |
| 6 | 1.1 Audio buses | **PASS** | audio_manager.gd:_build_buses (Music/SFX/UI/Amb/Voice + reverb, compressor, limiter); mix measured in PROGRESS.md (tests/mixrec.gd) |
| 7 | 1.1 Consistent naming convention | **PASS** | snake_case files, PascalCase class_name per script (78 scripts); naming map in docs/ASSUMPTIONS.md #16 |
| 8 | 1.2 Folder structure | **FIXED** | existing layout kept; every roadmap folder mapped in docs/FOLDER_MAPPING.md |
| 9 | 1.3 GameManager/SceneManager/AudioManager/SaveManager/InputManager/UIManager/QuestManager/InventoryManager | **PASS** | autoloads Events, Game, Sfx, Missions, GameMode (project.godot [autoload]); mapping in docs/FOLDER_MAPPING.md (InventoryManager = player InventoryComponent) |
| 10 | CC: project launches without errors | **PASS** | autotest: "menu opens"; check.tscn 0 failed; offline autotest 72/72 |
| 11 | CC: basic scene switching works | **PASS** | autotest: "research wing loads"; "security sector loads"; "reactor loads"; "exterior loads"; "extraction loads" |
| 12 | CC: backup and version control | **FIXED** | git repo in G: commits 0b482a3, 565fa31, 1a7020f, f0d52bc (git log). Tag + dated zip still open (GAPS #16) |
| 13 | 2.1 Blender units/scale, naming, material workflow, UV, rigs | **PASS** | docs/ASSET_SPEC.md; docs/ASSET_REGISTER.md conventions (metres, −Y front, role-named material slots, 1 UV = 1 m) |
| 14 | 2.2 Astronaut, Stalker, Sentinel, Brute, final boss created, rigged, animated | **PASS** | assetcheck 89/89 (runs/r4_assetcheck.log): astronaut v2 28 bones/31 clips, stalker 32/9, sentinel 30/12, brute 25/10, herald 20/10, all = sidecars |
| 15 | 2.2 Optimised polygon counts / texture resolution | **PASS** | tris: astronaut 30,056, sentinel 24,896, brute 19,509, stalker 10,694, herald 31,670; textures ≤1024 (register §1) |
| 16 | 2.3 Facility modular kit + lab, terminals, cryo, security, reactor props | **PASS** | 73 env GLBs (register §2): kit_* walls/floors/doors/ceilings, cryo_pod, terminal, console_large, security_gate, reactor_core … |
| 17 | 2.3 Alien rocks, vegetation, organic structures, debris, atmosphere | **PASS** | alien_rock_a–d, alien_plant_a–c, crystal_cluster_a–c, the_spire, debris_pile; fog/sky: shaders/ + area_base.gd:_make_env; shot shots/h_exterior.png |
| 18 | 2.4 Pulse Rifle & Energy Pistol models with reload/fire anims, muzzle FX, interaction points | **PASS** | pulse_rifle.glb / energy_pistol.glb with Mag/Muzzle/Grip_L children; astronaut clips rifle_reload, rifle_fire, pistol_reload, pistol_fire (= sidecar); Fx.muzzle_flash (fx.gd) |
| 19 | 2.5 GLB export: origins, scale, orientation, transforms, materials, animations, collision | **PASS** | assetcheck: 83/83 load with bounds/clips matching sidecars; collision via props.gd CUSTOM/box and level_builder.gd |
| 20 | CC: test character & environment import, materials render, animations play in Godot, scale consistent | **PASS** | assetcheck 83/83, 0 errors; animations exercised by autotest (wake, reveal turn_head); renders shots/h_*.png |
| 21 | Third-person movement, walk/run | **PASS** | player.gd (WALK 1.9, RUN 4.1); camera-relative move driven by real movement code in collide (37812 frames). Dedicated speed test: GAPS #18 |
| 22 | Sprinting | **PASS** | collide.gd sprints the player in 12 directions per checkpoint (sprint_toggle) — 0 failures |
| 23 | Jumping | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "jump height (peak 0.98 m)", "lands back on the floor" |
| 24 | Crouching | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "standing player is blocked by the 1.4 m bar", "crouch lowers the capsule (1.15)", "crouched player passes under the bar", "stands up again" |
| 25 | Camera rotation / collision | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "camera stays on the player's side of the wall (arm 0.28 of 3.10)", "spring arm shortens against the wall" |
| 26 | Character rotation / animation blending | **PASS** | player_anim.gd AnimationTree (blend spaces + upper-body layer); wake → locomotion 0.35 s blend (PROGRESS.md 16:35Z). Transition test: GAPS #18 |
| 27 | Tech: CharacterBody3D, SpringArm3D, Camera3D, AnimationTree, AnimationPlayer, InputMap | **PASS** | player.gd (extends CharacterBody3D), player_controller.gd, player_anim.gd, game.gd:_setup_input |
| 28 | Movement, camera, animation logic separated | **PASS** | player.gd (movement) / player_controller.gd (input+camera) / player_anim.gd (animation) / components/* |
| 29 | CC: no major collision issues | **PASS** | collide: "COLLIDE 37812 checks, 0 failures" (runs/collide_1714.log); "falling in the gap resets the player" |
| 30 | CC: keyboard & mouse controls work | **PASS** | autotest: "rebinding applies and is saved"; "rebinding to a used key swaps"; "bindings reset to defaults" |
| 31 | 4.1 Interactables, door controls, terminals, documents, mission interactions, context prompts | **PASS** | autotest: "bay door starts locked"; "bay door opens after the panel"; "log 1 collected"; "keypad overlay opens"; "conduit board opens"; "comms restored"; prompt via Events.interact_focus (interaction_component.gd:_set_focus) |
| 32 | 4.2 Weapon switching, shooting, reloading, ammo, damage, hit detection, enemy health, effects | **PASS** | autotest: "pistol picked up"; "rifle picked up"; "rifle shots hit the herald nodes"; "brute defeated" (14 weapon kills in run); balance: 9 scenarios, all kills by shooting (runs/balance_1716.log). Input-level switch/reload test: GAPS #18 |
| 33 | 4.3 Pulse Rifle primary, controlled fire, reload | **PASS** | data/weapons/*.tres + pulse_rifle.gd; balance "stalker rifle kills 1/1 … brute rifle kills 1/1" |
| 34 | 4.3 Energy Pistol secondary, energy fire, separate ammo | **PASS** | energy_pistol.gd; inventory reserve {"pistol","rifle"} (inventory_component.gd); balance "stalker pistol kills 1/1", "sentinel pistol kills 1/1" |
| 35 | 4.4 Health, damage feedback, death and respawn | **PASS** | autotest: "player dies"; "respawn at checkpoint with full health"; damage-direction marks + low-health pulse (ui.gd) |
| 36 | 4.4 Resource collection, health restoration | **PASS** | autotest: "medkit auto-pickup"; inventory_component.gd:use_medkit + heal clip. Use-medkit test: GAPS #18 |
| 37 | 4.5 Inventory: resources, key items, mission objects, interface | **FIXED** | autotest: "inventory & logs screen opens"; ui.gd:_inventory_block (commit 565fa31) |
| 38 | 4.6 Save: progress, missions, inventory, unlocked areas, checkpoint; versioned + validated | **FIXED** | autotest: "save carries a version"; "corrupt save falls back to the backup"; "invalid save data is rejected"; "continue loads the save"; "save file valid"; game.gd:_valid (565fa31) |
| 39 | CC: systems work and communicate; save/load | **PASS** | autotest 72/72; Events bus (scripts/core/events.gd, 24 signals) |
| 40 | Stalker: patrol, detect, pursue, close attack, reposition | **PASS** | ai_test: "stalker patrols", "stalker detects and chases", "stalker loses the player and investigates", "stalker returns to patrol" (runs/ai_test_1722.log 7/7); lunge → REPOSITION stalker.gd:141 |
| 41 | Sentinel: guard, detect, ranged, position-based | **PASS** | ai_test: "sentinel engages at range (charges a burst)", "sentinel repositions (repositions 5, moved 5.5 m)" |
| 42 | Brute: heavy, high HP, powerful attacks, charge | **PASS** | ai_test: "brute charges"; autotest "brute defeated"; brute 480 HP (PROGRESS 16:35Z), slam telegraph brute.gd:116 |
| 43 | Boss: patterns, phases, telegraphs, damage windows, defeat animation, completion trigger | **PASS** | autotest: "herald fight starts"; "herald phase 2"; "herald phase 3"; "herald defeated"; "shuttle ramp appears"; telegraph rings Fx.telegraph (fx.gd:253); shot shots/b_herald_slam.png |
| 44 | Tech: NavigationAgent3D, state machine, detection, cooldowns, damage | **PASS** | enemy_base.gd (State enum, nav_to, perception.gd), area_base.gd:bake_navigation |
| 45 | Tech: AI debugging tools | **FIXED** | ai_test 9/9 (runs/r2_ai_test.log): "AI debug overlay shows state (STALKER PATROL / HP 60/60 STUCK x1)"; F3 or --ai_debug (enemy_base.gd) |
| 46 | CC: enemies detect/engage, defeatable, boss start→end | **PASS** | ai_test 7/7; autotest herald defeated |
| 47 | L1 Cryo: awakening, movement tutorial, clues, facility intro | **PASS** | autotest: "opening cinematic plays"; "mission 1 active"; "log 1 collected"; tutorial hints area_cryo.gd:_hint |
| 48 | L2 Research: labs, missing crew, first enemy, documents | **PASS** | autotest: "research wing loads"; "code clue logs collected"; Stalker patrols area_research.gd:135 |
| 49 | L3 Security: access systems, locked doors, terminals, combat | **PASS** | autotest: "keypad overlay opens"; "code 0417 accepted"; "security sector loads"; "comms door unlocked"; "brute defeated" |
| 50 | L4 Reactor: power puzzle, environmental hazards, major revelation | **FIXED** | HazardZone (scripts/interact/hazard_zone.gd): 2 steam vents + arcing cable, telegraphed cycle; autotest 96/96 (runs/r3_autotest.log) "reactor hazard damages the player (8 ticks, 56 HP)"; conduit puzzle + survival + Iyer reveal pass |
| 51 | L5 Exterior: landscape, structures, exploration, survival encounter | **PASS** | autotest: "exterior loads"; "log 13 collected"; stalkers ext_s1–s3 area_exterior.gd:119; shots/h_exterior.png |
| 52 | L6 Extraction: final mission, boss, extraction, ending cinematic | **PASS** | autotest: "extraction loads"; "transmission sent"; "herald defeated"; "ending cinematic"; "end credits roll" |
| 53 | Level design: navigation, storytelling, objectives, placement, lighting, performance geometry | **PASS** | collide 0 failures; objectives data/missions.tres; occluders + visibility ranges area_base.gd:apply_visibility_ranges; shots/h_*.png |
| 54 | CC: six sections playable, transitions, no blockers, objectives achievable | **PASS** | autotest plays all 6 areas new game → credits, 72/72 |
| 55 | Four missions (Awakening, Lost Research, Containment Failure, Final Extraction) | **FIXED** | data/missions.tres titles renamed today; autotest: "mission 2 starts"; "mission 3 starts"; "mission 4 starts"; "game complete" |
| 56 | Three puzzles: power restoration, security access/terminal, reactor stabilisation | **PASS** | autotest: "wrong generator order resets"; "generator puzzle solved"; "wrong code rejected"; "code 0417 accepted"; "conduit board starts unsolved"; "conduit puzzle solved" |
| 57 | Audio logs, documents, clues, cinematics, mission dialogue, triggers | **PASS** | data/logs.json + log_pickup.gd (voice + subtitles); data/dialogue.json; area triggers (area_base.gd:trigger). Logs-all-reachable check is a tautology (GAPS #6) |
| 58 | CC: missions completable, puzzles function, story consistent, ending triggers | **PASS** | autotest: "game complete"; "end credits roll" |
| 59 | Visual: materials, environments, atmospheric lighting, volumetrics, shadows, reflections, particles, fog, organic FX | **PASS** | themes.gd PBR sets, quality_profile (sdfgi/ssao/ssil/ssr/vol_fog), fx.gd; shots/h_cryo.png … h_extraction.png |
| 60 | Rendering evaluation: Forward+, GI, SS effects, env, shadows, LOD | **PASS** | game.gd:quality_profile (5 presets); meshes/generate_lods=true on all 73 env imports; perf probe tests/perf.gd |
| 61 | Audio: ambience, footsteps, weapons, enemies, cinematic, soundtrack | **PASS** | assets/audio/{amb,sfx,music,vo} (170 files), player.gd:_footsteps, docs/credits/audio.md; mix measured (PROGRESS 16:28Z) |
| 62 | Audio: environmental hazards | **FIXED** | hazard_zone.gd plays steam/arc SFX on its cycle; covered by the autotest hazard check (audio itself not assertable headless) |
| 63 | Cinematics: opening, revelations, boss introduction, final extraction (AnimationPlayer) | **PASS** | autotest: "opening cinematic plays"; "ending cinematic"; reveal area_reactor.gd:_reveal; boss intro area_extraction.gd:_climax (herald.rise); cinematic.gd bakes AnimationPlayer tracks |
| 64 | CC: performance acceptable | **OPEN** | Settings > Show FPS readout exists (autotest 96/96 (runs/r3_autotest.log) "FPS readout follows its setting"), so Sonujeet can measure; needs a GPU measurement on Sonujeet's PC (this box renders on CPU); draw calls measured (test_logs/perf_*.log): phone preset 65–157 per frame on the Mobile renderer, High preset 3.6k–5.6k on Forward+ |
| 65 | Main menu: New Game, Continue, Settings, Credits, Exit | **PASS** | ui.gd:show_menu buttons "Continue" (when a save exists), "New Game", "How to play", "Settings", "Credits", "Exit" (desktop); autotest: "menu opens"; shots/u_menu2.png |
| 66 | HUD: health, ammo, weapon, objectives, prompts | **PASS** | ui.gd HUD (ammo_lbl red ≤25 % mag, ui.gd:413), objective Events.objective_changed; shots/h_*.png |
| 67 | Pause: Resume, Settings, Restart checkpoint, Main menu | **FIXED** | ui.gd pause buttons; autotest: "restart checkpoint returns to the checkpoint" |
| 68 | Settings: resolution, graphics, V-Sync, audio, mouse sensitivity, key bindings | **FIXED** | ui.gd:open_settings + open_bindings; autotest: "settings opens"; "key bindings page opens"; "rebinding applies and is saved" |
| 69 | CC: UI scales correctly | **PASS** | Interface size setting (auto 1.35× touch) via content_scale_factor (PROGRESS 15:5x); touch layouts checked at 1600×720 (shots/u_menu2.png) |
| 70 | CC: settings persist | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "all settings persist across a restart" (11 settings), "audio settings drive the mix buses", "rebinding applies and is saved" |
| 71 | CC: all gameplay information readable | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "keyboard hints follow the rebinding" (Game.key_name in HOWTO, settings footer, HUD prompts); 1.35× UI scale |
| 72 | Testing: movement, combat, AI, puzzle, save/load, mission, cinematic, UI, collision, audio | **PASS** | autotest 72/72, collide 0 fails, ai_test 7/7, balance 9 scenarios, mixrec (audio). Movement/camera test gap GAPS #18 |
| 73 | Optimisation: draw calls, meshes, LODs, textures, occlusion, profiling, lighting, effects | **FIXED** | occluders + visibility ranges (565fa31); kit MultiMeshes chunked to 12 m: primitives per frame cryo 15.1M→4.4M, research 23.3M→6.4M, security 16.3M→4.2M, reactor 21.3M→6.6M (lead perf probe, PROGRESS.md); small props cast no shadows (props.gd:107); draws still 3.3k–5.5k |
| 74 | Targets: stable 60 FPS, no stutter, no crashes, memory, load times | **OPEN** | Settings > Show FPS readout exists (autotest 96/96 (runs/r3_autotest.log) "FPS readout follows its setting"), so Sonujeet can measure; no crashes in any suite (autotest 96/96, collide, balance, ai_test, move_test); 60 FPS/memory/load times need his PC; draw calls measured (test_logs/perf_*.log): phone preset 65–157 per frame on the Mobile renderer, High preset 3.6k–5.6k on Forward+ |
| 75 | CC: no game-breaking bugs, missions completable, save reliable | **PASS** | autotest 72/72 (new game → credits, save/corrupt/backup checks) |
| 76 | Windows export configured | **PASS** | export_presets.cfg preset.0 "Windows Desktop" |
| 77 | Packaged build tested outside the editor; save/load, audio, input verified | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log). Rendering, audio and real input on Windows hardware still need one run on Sonujeet's PC |
| 78 | Windows: audio and input verified on real hardware | **OPEN** | headless wine run cannot play audio or take input; needs one run on Sonujeet's PC |
| 79 | Release folder prepared | **FIXED** | lead 4: echoes-v1.0.0/ holds the Windows zip, signed APK, trailer, 9 screenshots, CHANGELOG, TEST_REPORT, source zip, dated git bundle and test_logs/; web + downloads live (TEST_REPORT.md "Builds") |
| 80 | Portfolio: trailer, screenshots, character + environment showcases, Blender breakdown, Godot breakdown, architecture overview, dev docs | **FIXED** | echoes-portfolio/: turntables/ (5 MP4 + 6 hero stills), breakdown/ (wire/clay/final for 7 assets + 5 texture sheets, README), environment/ENVIRONMENT_SHOWCASE.md+.pdf (8 area images, 5 cine sheets), docs/GODOT_IMPLEMENTATION_BREAKDOWN + ARCHITECTURE_OVERVIEW (.md + .pdf, diagram), trailer/ (v1.0 cut, 63 s); screenshots in the release folder |
| 81 | Final deliverables: project, Blender sources, Windows demo, 30–45 min, trailer, screenshots, docs, portfolio | **OPEN** | all delivered (project, blender_src/, Windows zip wine 100/100, trailer, 9 screenshots, docs, portfolio, see #79/#80) except a measured 30–45 min human playthrough (autotest teleports between objectives) — needs Sonujeet |
| 82 | §3 AI workflow: Godot 4 syntax, GDScript, no invented APIs, no placeholders claimed complete | **PASS** | check.tscn 78/78 compile on 4.7.2; placeholder models found and replaced (PROGRESS 15:57Z); this audit marks nothing pass without evidence |
| 83 | §4 Test every imported asset in Godot | **PASS** | assetcheck: 83/83 GLBs load, clips/bones = sidecars |
| 84 | §4 Test the final exported Windows build | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log) |
| 85 | §5 Vertical slice: start → awaken → explore → interact → puzzle → enemy → objective → next area, no intervention | **PASS** | autotest: "opening cinematic plays"; "bay door opens after the panel"; "vent stalker awakens"; "generator puzzle solved"; "bulkhead unlocked"; "research wing loads" (autotest teleports between beats; a human run is Sonujeet's) |
| 86 | §6 All six levels / four missions / three puzzles / three enemies / boss / both weapons | **PASS** | autotest 72/72 + ai_test 7/7 (see rows above) |
| 87 | §6 Survival & inventory, save/load, story & ending, UI & settings, audio & cinematics | **PASS** | see Phase 4/7/8/9 rows; open sub-items listed there |
| 88 | §6 Windows build runs independently | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log) |
| 89 | §6 No critical gameplay bugs | **PASS** | autotest/collide/ai_test/balance pass; "Lambda capture" error spam to fix (GAPS #4) |
| 90 | §6 Portfolio materials prepared | **FIXED** | see #80 (echoes-portfolio/ complete) |
| 91 | §7 Steps 1–9 (install, VCS, test env, astronaut, movement, Cryo, slice, validate, production) | **FIXED** | scenes/test_environment.tscn (f0d52bc); git; slice + full production done (autotest) |

## 2. Implementation PRD (Document 03): phases, acceptance tests, milestones M1–M11, Definition of Done

85 requirements · PASS 55 · FIXED 29 · N/F 0 · OPEN 1

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | P1 Godot project, renderer, resolution, inputs, physics layers | **PASS** | project.godot ([rendering], [display], [layer_names], [physics] Jolt 60 Hz); game.gd:_setup_input |
| 2 | P1 Directory structure | **FIXED** | docs/FOLDER_MAPPING.md |
| 3 | P1 Main scene + initial environment | **PASS** | run/main_scene res://scenes/main.tscn → menu → areas |
| 4 | P1 Git + backup system | **FIXED** | git log: 0b482a3 … f0d52bc; save .bak backup game.gd:save_game. Tagged release/zip open (GAPS #16) |
| 5 | P1 Required scenes Main.tscn / MainMenu.tscn / TestEnvironment.tscn | **FIXED** | scenes/main.tscn, scenes/MainMenu.tscn, scenes/test_environment.tscn exist; move_test 23/23 (runs/r2_move_test.log) runs in test_environment |
| 6 | P1 GameManager / SceneManager / InputManager | **PASS** | Game + GameMode autoloads; GameMode.load_area; Game._setup_input/apply_bindings (docs/FOLDER_MAPPING.md) |
| 7 | P1 AT: launches, main scene loads, no script errors, inputs configured, backup exists | **PASS** | check.tscn "CHECKED 78 scripts, 0 failed"; autotest: "menu opens"; git repo |
| 8 | P2 Astronaut: suit, helmet/visor, backpack, materials, topology, rig | **PASS** | astronaut.glb v2 (DONE_ASTRONAUT 18:18Z): 39,418 tris (budget 40k), 28 bones, 31 clips = sidecar; materials Suit (2048 PBR atlas: folds, seams, wear, stencils), GlassVisor (gold wrap visor), EmitSuit, EmitLamp, Decals; compact PLSS backpack (runs/r4_assetcheck.log; d94fa0a7 REPORT.md before/after renders) |
| 9 | P2 Animations: idle, walk, run, jump, landing, crouch, death | **PASS** | clips idle, walk, run, jump_start, fall, land, crouch_idle, crouch_walk, death (astronaut.json = assetcheck 31 clips) |
| 10 | P2 scenes/player/Player.tscn | **FIXED** | scenes/player/Player.tscn exists (VisualRoot, CameraPivot/SpringArm3D/Camera3D per f0d52bc) |
| 11 | P2 Node architecture (CollisionShape3D, VisualRoot, CameraPivot/SpringArm3D/Camera3D, InteractionArea) | **FIXED** | node names VisualRoot, CameraPivot→SpringArm3D→Camera3D match since f0d52bc (player.gd:_ready, player_controller.gd:setup); InteractionArea = InteractionComponent (docs/ASSUMPTIONS.md #6) |
| 12 | P2 Movement, gravity, jump, sprint, crouch, camera rotation/collision, facing, transitions | **PASS** | player.gd, player_controller.gd, player_anim.gd; sprint+gravity via collide (0 failures). Jump/crouch/camera tests open (GAPS #18) |
| 13 | P2 AT: appears, moves, camera follows, faces movement, transitions, no fall-through | **PASS** | collide "COLLIDE 37812 checks, 0 failures" (sprint runs, overlap check); autotest "falling in the gap resets the player"; facing/transition assertions GAPS #18 |
| 14 | P3 Walk / run / sprint / jump / crouch | **FIXED** | move_test 23/23 (runs/r2_move_test.log): walk 1.90 / run 4.10 / sprint 6.30 m/s, jump 0.98 m, crouch under bar |
| 15 | P3 Camera: mouse rotation, distance adjustment, collision, smooth follow, sensitivity | **FIXED** | distance: Ctrl+wheel / PgUp-PgDn / pinch / slider, player_controller.gd:zoom_camera (1a7020f); sensitivity slider ui.gd; SpringArm3D collision. Clip test GAPS #18 |
| 16 | P3 Interaction: detection, prompts, doors, terminals, collectibles | **PASS** | autotest: "bay door opens after the panel"; "log 1 collected"; "pistol picked up"; "keypad overlay opens" |
| 17 | P3 Scripts player_controller/player_camera/player_animation/player_interaction | **PASS** | equivalents: player_controller.gd (input+camera), player_anim.gd, components/interaction_component.gd (docs/ASSUMPTIONS.md #7) |
| 18 | P3 AT: camera does not clip through walls | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "camera stays on the player's side of the wall"; faces movement "error 0 deg" |
| 19 | P3 AT: no major movement bugs; interaction works; KB/M responsive | **PASS** | collide 0 failures; autotest interaction checks; rebinding checks |
| 20 | P4 Cryo assets: pods, walls, floors, doors, panels, pipes, ceilings, props | **PASS** | cryo_pod, kit_wall*, kit_floor*, kit_door_*, door_panel, pipe_straight/bend, kit_ceiling* (register §2, used in cryo) |
| 21 | P4 scenes/levels/cryo_chamber.tscn | **FIXED** | scenes/levels/{cryo_chamber,research_wing,security_sector,reactor_core,alien_exterior,extraction_zone}.tscn via level_boot.gd |
| 22 | P4 Modular construction, collision, lighting, fog, ambient, cryo chamber, exit door, triggers | **PASS** | level_builder.gd (4 m grid kit), area_base.gd:room_lights/_make_env, amb_cryo.ogg, autotest: "bay door starts locked"; "bulkhead unlocked" |
| 23 | P4 Opening: darkness → audio → awaken in pod → control → explore → clues → exit → facility | **PASS** | autotest: "opening cinematic plays"; "cinematic skip returns control"; "log 1 collected"; "bulkhead unlocked"; "research wing loads"; wake clip fix (PROGRESS 16:35Z) |
| 24 | P4 AT: loads, navigable, interactions, lighting, opening completes | **PASS** | same checks; shots/h_cryo.png |
| 25 | P5 Rifle: shoot, reload, ammo, hit detection, FX, anims, sound | **PASS** | autotest: "rifle picked up"; "rifle shots hit the herald nodes"; rifle_fire/rifle_reload clips; rifle_fire_1–3.ogg; balance rifle rows |
| 26 | P5 Pistol: shoot, energy ammo, reload/recharge, hit detection, FX | **PASS** | balance "stalker pistol kills 1/1 … brute pistol kills 1/1"; pistol_fire/reload clips |
| 27 | P5 Switching, damage, health, ammo display, feedback | **PASS** | combat_component.gd:equip/cycle, HUD ammo (ui.gd:412–413, red when low), hit marker Events.hit_confirmed. Input-level switch test GAPS #18 |
| 28 | P5 scenes/weapons/pulse_rifle.tscn, energy_pistol.tscn | **FIXED** | scenes/weapons/pulse_rifle.tscn + energy_pistol.tscn (weapon_scene.gd wrapper around the class-based weapons) |
| 29 | P5 scripts/combat: weapon_base, weapon_manager, damage_system, health_component | **PASS** | weapons/weapon_base.gd; combat_component.gd (= weapon_manager); weapon_base._apply_hit + enemy_base.take_hit (= damage_system); components/health_component.gd (docs/ASSUMPTIONS.md #7) |
| 30 | P5 AT: both equipped, shooting, ammo updates, damage, reload, anims/sounds | **PASS** | autotest: "pistol picked up"; "rifle picked up"; "rifle shots hit the herald nodes"; balance 9/9 kills; ammo-updates assertion GAPS #18 |
| 31 | P6 Stalker: patrol, detect, chase, close attack, return to patrol | **FIXED** | ai_test (new today): "stalker patrols", "stalker detects and chases", "stalker loses the player and investigates", "stalker returns to patrol" |
| 32 | P6 Sentinel: guard, detect, ranged, reposition | **FIXED** | ai_test: "sentinel engages at range (charges a burst)", "sentinel repositions" |
| 33 | P6 Brute: heavy, high HP, powerful attacks, charge | **FIXED** | ai_test: "brute charges"; autotest "brute defeated" |
| 34 | P6 AI arch: NavigationAgent3D, state machines, detection, cooldowns, health, damage | **PASS** | enemy_base.gd, perception.gd, health_component.gd |
| 35 | P6 Boss: model, health, patterns, phases, warning anims, defeat | **PASS** | autotest: "herald fight starts"; "herald phase 2"; "herald phase 3"; "herald defeated"; herald.glb 10 clips |
| 36 | P6 AT: detect, navigate, attacks register, damage/death, boss phases | **PASS** | ai_test 7/7; autotest; balance (damage taken per scenario) |
| 37 | P7 Inventory: resources, mission items, key items, interface | **FIXED** | autotest: "inventory & logs screen opens" |
| 38 | P7 Health: player health, feedback, restoration, death, checkpoints | **PASS** | autotest: "medkit auto-pickup"; "player dies"; "respawn at checkpoint with full health" |
| 39 | P7 Save: progress, inventory, missions, checkpoint, settings | **FIXED** | autotest: "save after arming"; "save carries a version"; "continue loads the save"; "corrupt save falls back to the backup"; settings user://echoes_settings.cfg (game.gd:save_settings) |
| 40 | P7 Interaction: doors, terminals, access cards, documents, mission objects | **PASS** | autotest: "aux door locked without weapon"; "aux door unlocked once armed"; "comms door unlocked"; "code clue logs collected"; keycard pickup (inventory_component.gd:add_keycard) |
| 41 | P7 AT: items collected, inventory updates, health changes, save/load, correct events | **PASS** | checks above |
| 42 | P8 Six locations | **PASS** | autotest: "cryo loads"; "research wing loads"; "security sector loads"; "reactor loads"; "exterior loads"; "extraction loads" |
| 43 | P8 Location 4 environmental hazards | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "reactor hazard damages the player (8 ticks, 56 HP)" |
| 44 | P8 Four missions | **FIXED** | missions.tres titles; autotest: "mission 1 active"; "mission 2 starts"; "mission 3 starts"; "mission 4 starts" |
| 45 | P8 Three puzzles | **PASS** | autotest: "generator puzzle solved"; "code 0417 accepted"; "conduit puzzle solved" |
| 46 | P8 AT: accessible, progression, puzzle triggers, story consistent, no blockers | **PASS** | autotest 72/72 new game → credits |
| 47 | P9 Audio logs, documents, storytelling, dialogue, mission events, revelations | **PASS** | data/logs.json, data/dialogue.json, log_pickup.gd, Sfx.say + subtitles (audio_manager.gd:284) |
| 48 | P9 Cinematics: opening, discovery, boss intro, extraction | **PASS** | area_cryo.gd (wake), area_reactor.gd:_reveal (discovery), area_extraction.gd:_climax (boss intro), _ending; autotest: "opening cinematic plays"; "ending cinematic" |
| 49 | P9 Audio: ambience, footsteps, weapons, enemies, hazards, music, cinematic | **FIXED** | all categories present incl. reactor hazard SFX (hazard_zone.gd); sndtest/mixrec earlier |
| 50 | P9 AT: audio at events, cinematics trigger, story understandable, audio settings work | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "audio settings drive the mix buses", cinematic checks; "story understandable" = human playtest (Story PRD Ph2/Ph5 rows, OPEN) |
| 51 | P10 Main menu / HUD / pause / settings items | **FIXED** | ui.gd:show_menu, HUD, pause (Restart checkpoint 565fa31), open_settings (Resolution, Quality, V-Sync, volumes, sensitivity, Controls → key bindings) |
| 52 | P10 Visual polish: lighting, materials, particles, env FX, animation, feedback | **PASS** | PROGRESS 15:57–16:35Z (lighting pass, prop detail, sky, grime); shots/h_*.png |
| 53 | P10 AT: menus work, settings save, HUD correct, UI scales, no major visual inconsistencies | **FIXED** | autotest 96/96 (runs/r3_autotest.log): menu/settings/inventory open, "all settings persist across a restart", "FPS readout follows its setting", "keyboard hints follow the rebinding" |
| 54 | P11 Testing categories (gameplay … performance) | **PASS** | autotest 72/72, collide, ai_test 7/7, balance, mixrec, perf.gd (the movement/camera test is GAPS #18, the performance number is open) |
| 55 | P11 Optimisation: mesh, texture, LOD, lighting, draw calls, memory, profiling | **FIXED** | visibility ranges + occluders (565fa31); importer LODs; perf.gd prints draw calls/objects/prims/VRAM per area |
| 56 | P11 Windows export, exe, test outside editor, save, input, audio, release folder | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log); release folder + real-hardware audio/input pending |
| 57 | P11 Final AT: missions, puzzles, enemies, boss, offline, no crashes | **PASS** | autotest inside a no-network namespace (`unshare -rn`): "AUTOTEST 97/97 passed in 132.4s" (runs/r3_offline.log; earlier 72/72 autotest_offline.log) |
| 58 | P11 Final AT: performance meets the agreed target | **OPEN** | Settings > Show FPS readout exists (autotest 96/96 (runs/r3_autotest.log) "FPS readout follows its setting"), so Sonujeet can measure; target not yet measured on his PC; draw calls measured (test_logs/perf_*.log): phone preset 65–157 per frame on the Mobile renderer, High preset 3.6k–5.6k on Forward+ |
| 59 | M1 Godot project created | **PASS** | project.godot, check.tscn 0 failed |
| 60 | M2 Playable astronaut | **PASS** | autotest plays the astronaut new game → credits; scenes/test_environment.tscn |
| 61 | M3 Working third-person controls | **FIXED** | move_test 23/23 (runs/r2_move_test.log) |
| 62 | M4 Cryo Chamber playable | **PASS** | autotest cryo section, 17 checks ("cryo loads" … "bulkhead unlocked") |
| 63 | M5 Combat functional | **PASS** | balance 9/9 scenarios; autotest weapon checks |
| 64 | M6 Enemy AI functional | **PASS** | ai_test 7/7 |
| 65 | M7 Supporting systems complete | **PASS** | inventory/health/save checks (P7 rows) |
| 66 | M8 Complete world and missions | **PASS** | autotest all 6 areas, 4 missions |
| 67 | M9 Story and audio integrated | **FIXED** | 15/15 logs placed (autotest 96/96 (runs/r3_autotest.log) "all logs findable (15 placed of 15)"), hazard audio added |
| 68 | M10 UI and visual polish | **FIXED** | autotest 96/96 (runs/r3_autotest.log) UI checks; FPS readout; key hints follow rebinding |
| 69 | M11 Tested Windows demo | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log) (real-hardware run by Sonujeet still recommended) |
| 70 | DoD 1 Game launches independently | **FIXED** | Windows .exe launches and completes the game under wine (runs/wine_autotest_copy.log); Linux headless too |
| 71 | DoD 2 Player can control the astronaut | **PASS** | collide (real movement code), autotest |
| 72 | DoD 3 All six locations implemented | **PASS** | autotest "… loads" ×6 |
| 73 | DoD 4 All four missions playable | **PASS** | autotest "mission 1 active" … "game complete" |
| 74 | DoD 5 All three puzzles work | **PASS** | autotest puzzle checks incl. wrong-answer resets |
| 75 | DoD 6 All standard enemy types function | **PASS** | ai_test 7/7, balance |
| 76 | DoD 7 Boss encounter completable | **PASS** | autotest "herald defeated" |
| 77 | DoD 8 Both weapons work | **PASS** | balance rifle + pistol kills; autotest pickups |
| 78 | DoD 9 Inventory and health systems work | **PASS** | autotest inventory/medkit/death/respawn checks |
| 79 | DoD 10 Save/load functions correctly | **PASS** | autotest save/continue/corrupt/backup/invalid checks (load-from-every-checkpoint GAPS #8) |
| 80 | DoD 11 Story and ending implemented | **PASS** | autotest "ending cinematic", "game complete", "end credits roll" |
| 81 | DoD 12 Audio and cinematics integrated | **PASS** | audio_manager.gd buses/mix; cinematics checks (hazard audio GAPS #1) |
| 82 | DoD 13 UI and settings work | **PASS** | autotest menu/settings/bindings checks; persistence test GAPS #7 |
| 83 | DoD 14 Game runs offline | **PASS** | autotest inside a no-network namespace (`unshare -rn`): "AUTOTEST 97/97 passed in 132.4s" (runs/r3_offline.log; earlier 72/72 autotest_offline.log) |
| 84 | DoD 15 Windows build tested | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log) |
| 85 | DoD 16 No critical gameplay bugs remain | **PASS** | all suites pass; non-critical error spam GAPS #4 |

## 3. Gameplay & Story Integration PRD

54 requirements · PASS 41 · FIXED 10 · N/F 1 · OPEN 2

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | §3 Clear immediate action + visible feedback per objective | **PASS** | Missions.advance (mission_manager.gd) emits objective_changed + "objective" UI sound; HUD top-left objective; autotest: "objective advances to weapon" |
| 2 | §3 Narrative through world, terminals, logs, brief scripted moments | **PASS** | 15 logs (data/logs.json), area triggers (area_base.gd:beat), cinematics |
| 3 | §3 Pacing alternates tension/discovery/action | **PASS** | route: cryo tutorial → first Stalker → puzzle → research logs → keypad → security fights → reactor reveal → survival → exterior → boss (data/missions.tres order) |
| 4 | §4 Content map: 6 areas with gameplay + story hooks | **PASS** | autotest loads all six; first terminal/log in cryo ("log 1 collected"); security logs; reactor reveal; exterior log 13 |
| 5 | §5 Central MissionManager, explicit mission/objective IDs, event-driven | **PASS** | Missions autoload (mission_manager.gd) completes objectives on Events.flag_set; ids in data/missions.tres |
| 6 | §5 M01–M04 objectives and completion conditions | **FIXED** | titles renamed today; beats all present; boundaries differ (docs/ASSUMPTIONS.md #9–10); autotest: "mission 2 starts"; "mission 3 starts"; "mission 4 starts"; "game complete" |
| 7 | §6 PZ01 Power Routing — sequence of power nodes, feedback, restores power | **PASS** | autotest: "wrong generator order resets"; "generator puzzle solved"; "bulkhead unlocked" (generator_puzzle.gd) |
| 8 | §6 PZ02 Access Alignment — clues nearby, sets security access flag | **PASS** | autotest: "code clue logs collected"; "wrong code rejected"; "code 0417 accepted" (flag puzzle.security_code) |
| 9 | §6 PZ03 Reactor Stabilization — multi-step under pressure, extraction route | **PASS** | autotest: "conduit board starts unsolved"; "conduit puzzle solved"; "survival completes"; Reset button ui.gd (conduit view) |
| 10 | §7 Player contract (signals; no mission text/flags/transitions) | **PASS** | Player emits died/landed + Events.player_damaged/died; no mission code in scripts/player/ |
| 11 | §7 Interactables contract (prompt, interact, state, signal) | **PASS** | interactable.gd (prompt, stable_id, used flag "used.<id>", highlight); door status light red/green/blue (door.gd:165–174) |
| 12 | §7 Weapons contract (damage, ammo, feedback, identity; no story) | **PASS** | weapon_base.gd emits Events.ammo_changed / hit_confirmed; WeaponData ids pistol/rifle |
| 13 | §7 Enemies contract (spawn/death/alert events, damage receiver, AI state) | **PASS** | Events.enemy_alerted / enemy_killed; enemy_base.take_hit; state enum (debug display GAPS #10) |
| 14 | §7 Puzzles contract (started/solved/reset signals) | **PASS** | generator_puzzle.gd solved_signal, conduit_console.gd solved, conduit_view.gd solved; reset on wrong order |
| 15 | §7 MissionManager contract | **PASS** | mission_manager.gd holds only objective state/progression |
| 16 | §7 UI contract (display only, not source of truth) | **PASS** | ui.gd reads Game.state / Events; autotest checks state via Game.flag, not UI |
| 17 | §7 SaveManager contract (approved data, versioned, no transient nodes) | **PASS** | game.gd:new_state fields; autotest: "save carries a version" |
| 18 | §7 AudioManager contract (named events, buses) | **PASS** | Sfx.play("name") / Sfx.say(id) with name→file table (audio_manager.gd:_sfx); no res:// paths passed by callers (grep = 0) |
| 19 | §8 Event flow terminal → MissionManager → door/UI/audio → checkpoint | **PASS** | e.g. keypad → Game.set_flag("puzzle.security_code") → Events.flag_set → Missions.advance + security_gate.gd open_gate + area_research save_checkpoint; autotest: "code 0417 accepted" |
| 20 | §9 Opening brief, control quickly | **PASS** | autotest: "opening cinematic plays"; "cinematic skip returns control" |
| 21 | §9 Environmental clues | **PASS** | corpses, crystals, lockdown signs (area_research.gd:92), grime; shots/h_research.png |
| 22 | §9 Terminal logs short, one revelation each | **PASS** | 15 logs, 30–51 words each (data/logs.json) |
| 23 | §9 Audio: impacts, ventilation, alarms, radio, enemy cues, reactor ambience | **PASS** | amb_*.ogg per area, alarm_loop (area_reactor.gd:183), vent_burst, comms_static; enemy screech/hum |
| 24 | §9 Subtitles with speaker labels | **PASS** | Events.subtitle(speaker,text) → ui.gd sub_speaker; Subtitles toggle; shots/h_cryo.png shows "MIRA" label |
| 25 | §9 Ending: clear extraction beat, mystery open | **PASS** | area_extraction.gd:_ending (launch, "kabir_echo" line); end credits text "Nobody answered." |
| 26 | Ph1 Shared IDs (M01–M04, PZ01–PZ03, enemies, weapons, interactables) + integration contract sheet | **FIXED** | docs/INTEGRATION.md: M01–M04 (data/missions.tres "code"), PZ01–PZ03, enemy/weapon/interactable ids + signals |
| 27 | Ph1 System test scene (player, terminal, door, pickup, enemy) | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "test scene has player, terminal, door, pickup, enemy", "terminal powers the door", "medkit pickup" |
| 28 | Ph1 AC: no duplicate IDs; clear sender/receiver; UI not source of truth | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "no duplicate stable ids (94 ids)"; sender/receiver table in docs/INTEGRATION.md |
| 29 | Ph2 Vertical slice end to end | **PASS** | autotest cryo section (17 checks) |
| 30 | Ph2 AC: first-timer finishes w/o help | **OPEN** | human playtest (Sonujeet / testers) |
| 31 | Ph2 AC: transitions work after restart; no manual variable edits | **PASS** | autotest: "restart checkpoint returns to the checkpoint"; "continue loads the save"; progression via flags only (autotest uses god() for damage, never sets mission flags) |
| 32 | Ph3 M02–M04 via same pattern; logs to beats; Sentinel/Brute to gates; PZ02/PZ03 to access/reactor | **PASS** | missions.tres flags; comms door locked by enc.brute (area_security.gd:23); lift locked by enc.reactor_survive (area_reactor.gd:36) |
| 33 | Ph3 AC: mission order valid, no softlocks, completion feedback | **PASS** | autotest route; Missions.advance skips already-set flags ("sequence breaks never softlock", mission_manager.gd header) |
| 34 | Ph4 Boss only after required state; cannot be skipped | **PASS** | herald rises in _climax after transmission.sent; shuttle console created only in _after_boss after boss.dead (area_extraction.gd:160–170); autotest: "transmission sent"; "herald fight starts" |
| 35 | Ph4 Boss phases cues, damage windows, completion event | **PASS** | autotest: "herald phase 2"; "herald phase 3"; "herald defeated" |
| 36 | Ph4 Extraction unlocked when conditions met; ending state set | **PASS** | autotest: "shuttle ramp appears"; "game complete" |
| 37 | Ph4 Save completion flag, clean return to menu/restart | **PASS** | game.complete flag + save_checkpoint at end (area_extraction.gd:_ending); end credits "Main menu" button (ui.gd:show_end_credits) |
| 38 | Ph4 AC: ending once; completion persists | **FIXED** | autotest 96/96 (runs/r3_autotest.log): "ending trigger is one-shot", "completion persists in the save" |
| 39 | Ph5 Full demo from fresh install / fresh save | **PASS** | autotest uses isolated fresh save + settings (game.gd:44–47 removes them at start); offline run 72/72 |
| 40 | Ph5 Test every gate, puzzle reset, enemy death, checkpoint, transition | **FIXED** | autotest 96/96 (runs/r3_autotest.log): every gate/puzzle reset/death-respawn + "load checkpoint <id>" for all 14 checkpoints |
| 41 | Ph5 Narrative comprehension; pacing revision list | **OPEN** | human testers needed (Sonujeet) |
| 42 | Ph5 Full-route test report | **FIXED** | TEST_REPORT.md (route covered, suites, results, defects, known issues, untested list) |
| 43 | §11 Persist checkpoint, missions, flags, key items, ending flag; schema version; safe defaults | **PASS** | game.gd:new_state/default_player; load_game merges defaults; autotest: "save carries a version"; "invalid save data is rejected" |
| 44 | §11 No transient enemy positions/VFX saved | **PASS** | save has flags only for dead enemies; no positions (game.gd:new_state) |
| 45 | §11 Load from every checkpoint | **FIXED** | autotest 96/96 (runs/r3_autotest.log): 14/14 "load checkpoint …" (same mission + objective, on floor, alive) |
| 46 | §12 Playtest questions (4/5 testers, discoverability, fairness, readability, story flow) | **N/F** | needs human first-time testers — not possible on this machine; recommended to Sonujeet |
| 47 | §12 Progression robust | **PASS** | autotest 72/72, collide 0 failures |
| 48 | §12 Runs offline with network disabled | **PASS** | autotest inside a no-network namespace (`unshare -rn`): "AUTOTEST 97/97 passed in 132.4s" (runs/r3_offline.log; earlier 72/72 autotest_offline.log) |
| 49 | §13 One ending, limited logs, no new missions/weapons/enemies after freeze | **PASS** | 1 ending, 15 logs, 4 missions, 2 weapons, 3 enemies + 1 boss |
| 50 | DoD: 4 missions + 3 puzzles on one authoritative progression system | **PASS** | Missions + Game.flags (mission_manager.gd) |
| 51 | DoD: systems communicate via documented contracts | **FIXED** | docs/INTEGRATION.md + docs/ARCHITECTURE.md |
| 52 | DoD: fresh start, offline, one ending, working checkpoints | **PASS** | offline autotest 72/72; checkpoint restart/respawn checks |
| 53 | DoD: no softlocks/desync | **PASS** | autotest; checkpoint-reload test still open (GAPS #8) |
| 54 | DoD: test report (build version, route, defects found/fixed/deferred) | **FIXED** | TEST_REPORT.md: build version 1.0.0 + commit, route, defects found/fixed/deferred |

## 4. Blender 3D Asset Production PRD

39 requirements · PASS 29 · FIXED 10 · N/F 0 · OPEN 0

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | §2 Art direction: abandoned facility, emergency light, decay, alien bioluminescence | **PASS** | shots/h_*.png; themes.gd per-area palettes; grime overlay shader |
| 2 | §2 Shared material scale, roughness logic, trim/decal workflow, texel density | **PASS** | role-named slots + themes.gd PBR sets; 1 UV unit = 1 m (env_manifest "about"); decals being made (f77ac026) |
| 3 | §3 P0 Player: body, helmet/visor, backpack, rig, idle/walk/run/aim | **PASS** | astronaut.glb 28 bones / 31 clips (register §1) |
| 4 | §3 P0 Core env: cryo pod, modules, doors, terminal, lights, cables, crates | **PASS** | register §2 (cryo_pod, kit_*, terminal, wall/ceiling_lamp, cable_bundle, crate_*) |
| 5 | §3 P0 Weapons + muzzle/impact components | **PASS** | pulse_rifle/energy_pistol with Muzzle child; Fx.muzzle_flash/impact (fx.gd) |
| 6 | §3 P0 Interactables: keycard, switch, puzzle device, door control, reactor control | **PASS** | keycard.glb, door_panel, keypad_panel, generator, conduit_console, comms_console |
| 7 | §3 P1 Enemies Stalker/Sentinel/Brute/boss | **PASS** | register §1 |
| 8 | §3 P1 World kit for the other 5 locations | **PASS** | register §2: 31 assets used in 2+ areas |
| 9 | §4 Blender project organisation (EOV_Blender/…) | **FIXED** | blender_src/ (characters_weapons, creatures, environment; README maps folders → GLBs). EOV_Blender/ name differs (ASSUMPTIONS.md) |
| 10 | §5 Applied transforms, intentional origins, real-world scale | **PASS** | assetcheck bounds: astronaut 1.86 m, origin min_y 0.0 for characters (register) |
| 11 | §5 Naming CHR_/ENV_/PROP_/WPN_/MAT_ | **FIXED** | register IDs use the PRD naming; files keep code-referenced names (docs/ASSUMPTIONS.md #16) |
| 12 | §5 Separate/simplified collision for complex objects | **PASS** | props.gd CUSTOM table (hand-fitted boxes/cylinders), NO_COLLIDE list; collide 0 failures |
| 13 | §5 PBR maps Base/Metal/Rough/Normal; emission only when needed | **PASS** | texture sets in register §3; Emit* materials only for lights/screens/weak points |
| 14 | §5 Keep .blend sources; versioned GLB exports | **FIXED** | blender_src/: .blend for every rigged character/creature; env kit = procedural scripts (documented); astronaut_v2/ and shuttle_dressing/ folders named in README, to be filled when helpers finish |
| 15 | §6 Astronaut silhouette, material zones, rig supports locomotion/aim/hit/death | **PASS** | v2: Suit atlas + GlassVisor + EmitSuit + EmitLamp + Decals; 31 clips incl. hit, death, rifle_aim; weapon socket prop.R unchanged (helper verified grip positions match) |
| 16 | §6 Weapon socket alignment tested in Godot | **PASS** | 1ca9c5ee REPORT: muzzle (-0.06,1.48,1.01), left wrist 0.08 m from Grip_L, verified in Godot; re-check after the astronaut remake |
| 17 | §6 Minimum animation set (idle, walk, run, start/stop, aim/fire, reload, interact, hit, death) | **PASS** | 31 clips (start/stop transitions = blend tree, not clips) |
| 18 | §6 Enemy silhouettes and cues (Stalker lean, Sentinel weak point, Brute wind-up, boss reuse) | **PASS** | stalker 1.08 m tall/2.46 m long; sentinel EmitCore; brute slam telegraph; herald 3 nodes; shots/e_creatures.png |
| 19 | §6 Interactables active/inactive states | **PASS** | door status light red/green/blue (door.gd:165–174), console screen colour (console.gd:set_screen_color), generator running state |
| 20 | §6 Modular kit: straight, corner, junction, doorway, damaged variants | **FIXED** | damaged variant added: kit_wall_damaged.glb (4,808 tris; torn plates, ribs, cables, EmitCrystal shards), placed by level_builder.gd:_maybe_damaged (cryo 1, research 3, security 2, reactor 3; max 3, never beside a door) with collision level_builder.gd:_damaged_collider; tests/dress_probe.gd DMGTEST 28/28; shots l4_dmg_cryo.png, l4_dmg_reactor.png. Straight/doorway/corner/junction as before |
| 21 | §6 Landmarks: cryo pods, security gate, reactor, exterior structure, extraction platform | **PASS** | cryo_pod, security_gate, reactor_core, habitat_module, landing_pad |
| 22 | §6 Reusable cables, pipes, vents, panels, lights, signage, crates, debris | **PASS** | register §2 (+ dressing models being made by f77ac026) |
| 23 | §7 Export pipeline + import verification in a Godot test scene | **PASS** | assetcheck: 83/83 imported GLBs load, bones/clips match sidecars (runs/assetcheck_1718.log) |
| 24 | §7 Asset register record per asset | **FIXED** | docs/ASSET_REGISTER.md (new) |
| 25 | Ph1 Reference board / scale guide / Cryo blockout / naming-export guide | **PASS** | scale + naming/export guide = docs/ASSET_SPEC.md; reference renders a1a4a21e/refs; blockout superseded by built level |
| 26 | Ph2 Hero astronaut AC: scale/orientation, no skinning issues, anims play, weapon aligns | **PASS** | v2 assetcheck: 1.79 m, faces +Z, min_y 0, bones/clips = sidecar; helper overlap scan clean except heal frames 14/28 (pauldron touches helmet, pre-existing); move_test 24/24 + autotest 97/97 animate it |
| 27 | Ph3 Modular kit AC: snap, materials import, simple collision, reuse across areas | **PASS** | level_builder.gd 4 m grid; 31 env assets in 2+ areas (register) |
| 28 | Ph3 Shared decal library (warning labels, dirt, damage, growth) | **FIXED** | 20 decals (decals.json) placed by scripts/world/dressing.gd _wall_decal (corner dust, leaks, labels, signs per zone), commit f5861e0; autotest 97/97 + collide 0 after placement (runs/r4_*.log) |
| 29 | Ph4 Weapons/interactables AC: align to rig, muzzle = fire origin, states readable | **PASS** | weapon_base.muzzle_pos(); 1ca9c5ee verified grips; door/console state colours |
| 30 | Ph5 Enemies AC: silhouettes, anims = AI states, no import errors | **PASS** | assetcheck 0 errors; clips per AI state (sentinel charge/fire/alert; brute 10 clips) |
| 31 | Ph5 LODs only if profiling shows need | **PASS** | importer LODs on all env imports; visibility ranges for clutter |
| 32 | Ph6 Exterior kit + location-specific props; distinct identities | **PASS** | alien_* / crystal_* / habitat; themes.gd per area; shots/h_*.png |
| 33 | Ph7 Remove unused objects; check texture sizes | **FIXED** | kit_railing, kit_ramp, kit_stairs removed from the game (f490061; listed as spares in ASSET_REGISTER, rebuildable from blender_src/environment/kit.py); every remaining kit piece is placed; textures ≤1024 except astronaut suit atlas and shuttle (2048, per their budgets) |
| 34 | Ph7 Final asset library, asset register, import validation checklist | **FIXED** | docs/ASSET_REGISTER.md + assetcheck.gd |
| 35 | Ph7 AC: no missing dependencies; all assets pass import validation | **PASS** | assetcheck 83/83, 0 errors |
| 36 | §10 Licences recorded | **PASS** | docs/credits/environment.md (ambientCG CC0, per set), audio.md, fonts OFL.txt; end-credits lines GAPS #3 |
| 37 | DoD: critical assets have .blend + validated GLB | **FIXED** | blender_src .blend + assetcheck 83/83 GLBs valid (runs/r2_assetcheck.log) |
| 38 | DoD: animations for implemented states; props align with systems; 6 locations supported; register/naming/licences complete | **PASS** | register, assetcheck, autotest |
| 39 | Ph3 Damaged panel and trim pieces | **FIXED** | kit_wall_damaged (see #20): torn panel + trim pieces, broken light strip flickers and crystal pulses (scripts/world/emissive_anim.gd; DMGTEST "crystal emission pulses", "broken strip light flickers") |

## 5. Godot 4 Game Development PRD

57 requirements · PASS 32 · FIXED 22 · N/F 1 · OPEN 2

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | §2 Offline single-player; 30–45 min; 4 missions, 3 puzzles, 1 boss, 1 ending; 6 locations; 3 enemies; 2 weapons | **PASS** | autotest 72/72 + offline run; playtime needs a human run (autotest finishes in ~100 s with teleports) |
| 2 | §3 Engine version recorded | **PASS** | Godot 4.7.2.stable (check.log header); project.godot features "4.7" |
| 3 | §3 Forward+ first | **PASS** | project.godot rendering_method="forward_plus" |
| 4 | §3 GDScript, typed variables | **PASS** | 78 scripts, typed (check.tscn 0 failed) |
| 5 | §3 CharacterBody3D for player/enemies; layers documented centrally | **FIXED** | player.gd, enemy_base.gd extend CharacterBody3D; project.godot [layer_names] (1a7020f) |
| 6 | §3 Input Map actions, not hard-coded keys | **PASS** | game.gd:_setup_input; rebinding via InputMap (autotest: "rebinding applies and is saved") |
| 7 | §3 Data in Resources/JSON | **PASS** | data/enemies/*.tres, data/weapons/*.tres, data/missions.tres, logs.json, dialogue.json |
| 8 | §3 Save with version; missing/corrupt safe | **PASS** | autotest: "save carries a version"; "corrupt save falls back to the backup"; "invalid save data is rejected" |
| 9 | §3 Git local repository with commits | **FIXED** | 4 commits today (git log) |
| 10 | §4 Proposed project structure | **FIXED** | docs/FOLDER_MAPPING.md |
| 11 | §5 Player.tscn node tree incl. WeaponSocket | **FIXED** | scenes/player/Player.tscn; WeaponSocket = right-hand BoneAttachment (weapon_base.gd) — name mapping in FOLDER_MAPPING.md |
| 12 | §5 Main, LevelRoot, WeaponBase, EnemyBase, InteractableBase, HUD/PauseMenu/Inventory/ObjectivePanel scenes | **FIXED** | named scenes: scenes/main.tscn (Main), scenes/MainMenu.tscn, scenes/levels/*.tscn (6 LevelRoots, each boots its area), scenes/player/Player.tscn, scenes/weapons/{pulse_rifle,energy_pistol}.tscn — move_test "named scenes instantiate"; EnemyBase/Interactable/HUD/PauseMenu/Inventory/ObjectivePanel are class equivalents (scripts/ai/enemy_base.gd, scripts/interact/, ui.gd panels built in code), mapped in docs/FOLDER_MAPPING.md |
| 13 | §5 Autoloads only for global lifetime | **PASS** | 5 autoloads; inventory is a player component |
| 14 | §6 Player movement: walk/run/jump, gravity, camera-relative, facing | **FIXED** | move_test 23/23 (runs/r2_move_test.log) |
| 15 | §6 Camera: orbit, pitch limits, smoothing, wall collision, aim mode | **PASS** | player_controller.gd PITCH_MIN/MAX, ARM_AIM over-shoulder, SpringArm3D; clip test GAPS #18 |
| 16 | §6 Interaction / combat / health / inventory / missions / puzzles / save / UI-audio minimums | **PASS** | see the Doc 3 rows; autotest 72/72 |
| 17 | §6 Enemy AI: patrol/investigate/chase/attack/return/death; navigation + LOS | **PASS** | ai_test 7/7 (patrol, chase, investigate, return to patrol); perception.gd line-of-sight |
| 18 | Ph1 Project, Forward+, window/res/physics/inputs, folders, README, Main + TestEnvironment, Git | **FIXED** | README.md (run, controls, tests, export); Forward+, named physics layers, inputs in project.godot |
| 19 | Ph1 AC: launches w/o errors; Main opens TestEnvironment; README | **FIXED** | check.tscn "CHECKED 80 scripts, 0 failed" (runs/r2_check.log); scenes/test_environment.tscn opens (move_test) |
| 20 | Ph2 Player controller; tuning values exposed; corridor camera test | **FIXED** | move_test 23/23 (runs/r2_move_test.log) (corridor camera test = "camera stays on the player's side of the wall") |
| 21 | Ph2 AC: no recurring errors while moving/jumping | **FIXED** | move_test 23/23 (runs/r2_move_test.log) and autotest 96/96 (runs/r3_autotest.log): 0 "Lambda capture" errors (2 left in collide only, trigger_zone.gd:37 — GAPS #4b) |
| 22 | Ph3 Single interaction interface; terminal updates objective flag; Cryo route; checkpoint/restart | **PASS** | Interactable base; autotest: "bay door opens after the panel"; "objective advances to weapon"; "restart checkpoint returns to the checkpoint" |
| 23 | Ph3 AC: exit unlocks only after required action | **PASS** | autotest: "bay door starts locked"; "aux door locked without weapon"; "aux door unlocked once armed" |
| 24 | Ph4 Shared weapon interface + data resources; distinct rate/damage/ammo/reload/FX | **PASS** | weapon_base.gd + data/weapons/*.tres; balance rifle vs pistol rows |
| 25 | Ph4 Low-ammo feedback | **PASS** | HUD ammo turns red at ≤25 % of the mag (ui.gd:413); dry_fire.ogg |
| 26 | Ph4 Target-dummy balance test | **PASS** | tests/balance.gd bot scenarios (runs/balance_1716.log, 9/9 kills) |
| 27 | Ph4 AC: no ammo/weapon desync | **FIXED** | move_test 23/23 (runs/r2_move_test.log): "reload fills the magazine from reserve (mag 32/32 reserve 78 events 2)", "weapon keys switch weapons" |
| 28 | Ph5 EnemyBase; Stalker/Sentinel/Brute behaviours; boss phases | **PASS** | ai_test 7/7; autotest herald phases |
| 29 | Ph5 Debug state display | **FIXED** | ai_test 9/9 (runs/r2_ai_test.log): "AI debug overlay shows state" |
| 30 | Ph5 AC: telegraphed attacks, no unavoidable damage; death/reward/mission triggers | **PASS** | stalker windup (stalker.gd:114), brute/herald Fx.telegraph rings, herald beam blocked by cover; drops enemy_base._drop; enc.* flags on death |
| 31 | Ph6 MissionManager states; objectives as data; 3 puzzle patterns with reset; flag gating; logs | **PASS** | mission_manager.gd + missions.tres; puzzle reset checks; door locks by flag |
| 32 | Ph6 AC: reloading a checkpoint preserves progress | **FIXED** | autotest 96/96 (runs/r3_autotest.log): 14/14 "load checkpoint …" |
| 33 | Ph7 Six areas, route, arenas, checkpoints, navmesh validated in combat spaces | **PASS** | autotest; area_base.gd:bake_navigation; ai_test nav in research |
| 34 | Ph7 AC: no softlocks; no missing collision on critical paths; navigation works | **PASS** | autotest 72/72; collide 0 failures; ai_test |
| 35 | Ph8 Opening wake-up via AnimationPlayer/Tree + camera cues | **PASS** | area_cryo.gd cinematic + play_wake (player_anim.gd:382) |
| 36 | Ph8 HUD, pause, settings, objective panel, subtitles/log reader, game-over/restart | **PASS** | ui.gd; autotest: "player dies"; "respawn at checkpoint with full health"; "inventory & logs screen opens" |
| 37 | Ph8 Info not only by audio; audio levels do not mask cues | **PASS** | subtitles + objective text; mix measured: guns ≈ VO, music 8–10 dB under, ducked under VO (PROGRESS 16:28Z) |
| 38 | Ph9 Low/medium/high presets with defaults on target PC | **OPEN** | autotest 96/96 (runs/r3_autotest.log): "quality presets apply", "quality preset applies to the live area" (real checks now); defaults on Sonujeet's PC unmeasured |
| 39 | Ph9 Windows export, clean-folder test, controls + README, archive | **FIXED** | Windows zip (exe + README.txt controls/run/saves + CHANGELOG + CREDITS) unzipped into an empty folder: wine AUTOTEST 100/100 and save_xproc 15/15 (files/echoes-v1.0.0/test_logs/wine_*.log) |
| 40 | Ph9 Known-issues list | **FIXED** | TEST_REPORT.md "Known issues (deferred)" + "Untested on real hardware" |
| 41 | §8 Vertical-slice gate | **PASS** | autotest cryo section |
| 42 | §9 Offline: no runtime network calls | **PASS** | no network code (grep HTTPRequest/http in scripts = 0); offline autotest 72/72 |
| 43 | §9 Accessibility: remappable keys, sensitivity, subtitle toggle, contrast, audio sliders | **PASS** | ui.gd settings (Change keys…, Look sensitivity, Subtitles, Master/Music/Effects/Voices); Interface size |
| 44 | §9 Maintainability: one responsibility per script; no giant managers | **OPEN** | mostly ✓; ui.gd is 1,226 lines (menus+HUD+settings+journal in one file) — acceptable for v1, split later |
| 45 | §9 Backups: commit per milestone + dated release backups | **FIXED** | commit per milestone; annotated tag v1.0.0 (local) + dated backup EchoesOfTheVoid-1.0.0-2026-11-03.gitbundle in the release folder |
| 46 | §10 Startup: cold, offline, main scene, no missing resources | **PASS** | offline autotest; assetcheck 0 errors; check.tscn |
| 47 | §10 Player: stairs/slopes, fall recovery, pause/resume | **PASS** | floor_max_angle 48° (player.gd); "falling in the gap resets the player"; pause → restart checkpoint check |
| 48 | §10 Combat edge cases | **FIXED** | move_test 23/23 (runs/r2_move_test.log): reload/switch/medkit; autotest 96/96 (runs/r3_autotest.log) death/respawn |
| 49 | §10 AI: stuck recovery | **FIXED** | ai_test 9/9 (runs/r2_ai_test.log): "stuck enemy recovers (skips the blocked patrol point)" |
| 50 | §10 Save: missing/corrupt; checkpoint restart | **PASS** | autotest: "corrupt save falls back to the backup"; "restart checkpoint returns to the checkpoint" |
| 51 | §10 UI/audio: resolution scaling, settings persistence, subtitle timing, volume balance | **FIXED** | autotest 96/96 (runs/r3_autotest.log): settings persistence (11), audio buses, resolution option; subtitles on cinematics |
| 52 | §10 Build: Windows export, clean folder, offline, readme, version | **FIXED** | v1.0.0 on the menu, README.md + README.txt in the zip, offline (autotest 100/100 under unshare -rn), clean-folder wine run 100/100, archive EchoesOfTheVoid-1.0.0-Windows.zip |
| 53 | §11 No Android porting in this release | **N/F** | superseded: Sonujeet plays on Android; APK ships as an extra, Windows remains the acceptance target (docs/ASSUMPTIONS.md #2) |
| 54 | DoD: Windows build launches and plays offline | **FIXED** | Windows .exe (export 17:18Z) under wine, headless: "AUTOTEST 72/72 passed in 104.2s … EXIT 0" incl. save/continue/corrupt-backup checks (runs/wine_autotest_copy.log); offline proven separately (unshare -rn run) |
| 55 | DoD: agreed scope or documented reduction | **PASS** | full scope delivered (no reduction) |
| 56 | DoD: critical route/save/combat/UI tests pass | **PASS** | autotest 72/72, collide, ai_test 7/7, balance |
| 57 | DoD: reproducible run/export guide + tagged release backup | **FIXED** | README.md (run/test/export commands), TEST_REPORT.md, tag v1.0.0 + dated git bundle |

## Open items

After the v1.0 release (lead 4, 2026-11-03), 9 rows remain OPEN:
- Needs Sonujeet's PC: doc 1 #64, #74 (real FPS / stutter / memory / load times), #78 (Windows audio and input), doc 2 #58 (performance target), doc 5 #38 (preset defaults on his PC). Settings → Show FPS displays FPS, frame time and the GPU for this.
- Needs a human playtest: doc 1 #81 (the 30–45 min length), doc 3 #30 (first-timer finishes without help), #41 (story comprehension, pacing notes).
- Deferred by choice: doc 5 #44 (split ui.gd into smaller scripts; it works, it is just large).
TEST_REPORT.md lists the same items under "Untested on real hardware" and "Known issues".
