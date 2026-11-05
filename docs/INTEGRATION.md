# ECHOES OF THE VOID — integration contract (shared IDs and signals)

Story PRD Phase 1 asks for one sheet that every system agrees on: mission, puzzle, enemy, weapon and interactable
IDs, and the signals with their senders and receivers. This is it. The autotest proves the IDs are unique
(`PASS no duplicate stable ids (95 ids)`: no ID repeats inside an area or across areas).

## Missions (data/missions.tres)
| code | id (code + save) | title | completes on flag |
|---|---|---|---|
| M01 | `awakening` | 01 — AWAKENING | `area.research` |
| M02 | `dead_signal` | 02 — LOST RESEARCH | `comms.restored` |
| M03 | `experiment` | 03 — CONTAINMENT FAILURE | `area.exterior` |
| M04 | `last_transmission` | 04 — FINAL EXTRACTION | `game.complete` |

Each mission is a list of objectives `{id, text, flag}`; the current objective is the first whose flag is not set
(`scripts/core/mission_manager.gd`). A save stores flags only, so objectives can never desync from the world.

## Puzzles
| code | where | solution | solved flag | script |
|---|---|---|---|---|
| PZ01 | Cryo Chamber, aux power room | generators B (coolant) → C (regulator) → A (main), from Wren's note | `puzzle.generators` | scripts/interact/generator_puzzle.gd (+ generator.gd) |
| PZ02 | Research → Security gate keypad | code 0417 (Okoye's MMDD format + Iyer's "April 17") | `puzzle.security_code` | scripts/interact/keypad.gd + security_gate.gd (UI: ui.gd keypad overlay) |
| PZ03 | Reactor control room console | rotate 5×4 conduit tiles to route CORE → UPLINK | `puzzle.conduits` | scripts/puzzles/conduit_board.gd + interact/conduit_console.gd |

## Enemies and weapons
| id | class | data |
|---|---|---|
| `stalker` | Stalker (scripts/ai/stalker.gd) | data/enemies/stalker.tres |
| `sentinel` | Sentinel (scripts/ai/sentinel.gd) | data/enemies/sentinel.tres |
| `brute` | Brute (scripts/ai/brute.gd) | data/enemies/brute.tres |
| `herald` | Herald, boss (scripts/ai/herald.gd) | in-script phases |
| `pistol` | Energy Pistol (scripts/weapons) | data/weapons/energy_pistol.tres |
| `rifle` | Pulse Rifle (scripts/weapons) | data/weapons/pulse_rifle.tres |

## Interactable and enemy stable IDs
Every interactable (`Interactable.stable_id`) and every placed enemy (`EnemyBase.stable_id`) has a string ID that the
save uses: `used.<id>` (one-shot consoles), `dead.<id>` (killed enemies), `trig.<id>` (story triggers), `door.<id>`,
`picked.<id>`. Conventions: area prefix + role (`cryo_vent_stalker`, `res_s1`, `sec_t2`, `rea_wave_<n>_<i>`,
`exz_r1`), logs `log.<n>` (1–15, data/logs.json), puzzles `gen_a/b/c`, `conduits`, consoles by purpose
(`bay_panel`, `pad_comms`, `shuttle_ramp`, `lift_out_controls`).

## Signals (scripts/core/events.gd, the global event bus)
| signal | emitted by | connected in |
|---|---|---|
| `noise` | brute.gd player.gd weapon_base.gd | perception.gd |
| `player_damaged` | player.gd | ui.gd |
| `player_died` | player.gd | game_mode.gd |
| `player_healed` | player.gd | — (polled by HUD / used by tests) |
| `enemy_alerted` | enemy_base.gd | — (polled by HUD / used by tests) |
| `enemy_killed` | enemy_base.gd | — (polled by HUD / used by tests) |
| `hit_confirmed` | weapon_base.gd | ui.gd |
| `weapon_changed` | combat_component.gd | — (polled by HUD / used by tests) |
| `ammo_changed` | combat_component.gd | — (polled by HUD / used by tests) |
| `interact_focus` | interaction_component.gd | ui.gd |
| `message` | ammo_station.gd area_cryo.gd area_extraction.gd area_research.gd area_security.gd combat_component.gd console.gd door.gd game_mode.gd generator_puzzle.gd log_pickup.gd pickup.gd player.gd ui.gd | ui.gd |
| `subtitle` | audio_manager.gd | ui.gd |
| `log_found` | game.gd | — (polled by HUD / used by tests) |
| `pickup` | pickup.gd | — (polled by HUD / used by tests) |
| `checkpoint_reached` | checkpoint.gd | game_mode.gd ui.gd |
| `flag_set` | game.gd | area_cryo.gd area_research.gd area_security.gd mission_manager.gd security_gate.gd |
| `objective_changed` | area_reactor.gd mission_manager.gd | ui.gd |
| `mission_changed` | mission_manager.gd | ui.gd |
| `combat_state` | game_mode.gd | — (polled by HUD / used by tests) |
| `boss_health` | herald.gd | ui.gd |
| `cinematic_state` | cinematic.gd | ui.gd |
| `camera_shake` | area_cryo.gd area_extraction.gd area_reactor.gd area_security.gd brute.gd generator_puzzle.gd herald.gd player.gd security_gate.gd | player_controller.gd |
| `area_loaded` | game_mode.gd | — (polled by HUD / used by tests) |

Component signals (local, not on the bus): HealthComponent `damaged/changed/died`, CombatComponent `weapon_changed`,
WeaponBase `reloaded`, Console/Door/TriggerZone `entered/solved/opened`, Herald `phase_changed/defeated`.
