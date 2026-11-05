# ECHOES OF THE VOID: audio credits and provenance

All 170 audio files in `game/assets/audio/` were made for ECHOES OF THE VOID on Nov 3 2026. They are Ogg Vorbis at 44.1 kHz. VO and SFX are mono (except `sfx/rifle_tail`, which is stereo). Ambience and music are stereo. Total size: 21.9 MB.

Every file can be regenerated from the scripts and job lists in task dir `287bd93f-b022-4fc3-a6a8-f2915f5d8e28/aw/`:
- the generation client; the job lists are `jobs_*.json`, and prompts and settings are recorded in `sfx_defs.json`, `sfx_layers.json`, `amb_defs.json`, `music_defs.json` and `voices.json`.
- `vo_process.py`, `sfx_process.py`, `amb_process.py`, `music_process.py`: the processing scripts.
- `proc.py`: the shared DSP helpers.
- The raw generations are kept in `aw/raw/`.

## Services used and licence position
- **Voice-over, sound effects, ambience and music** were generated with ElevenLabs models (Multilingual v2 and v3 text-to-speech, Sound Effects v2, and Music) on a paid plan. ElevenLabs' terms allow commercial use of output from paid plans. The voices come from the ElevenLabs Voice Library, whose voices are licensed for use in generated content on paid plans. Voice Library voices may not be used to impersonate the voice owner; here they only play fictional characters.
- **Synthesised content** (numpy DSP written for this game: UI tones, keypad sounds, chimes, heartbeat, klaxon, radio static, and the processing layers such as the rifle cracks, sub thumps and zaps, room tone and hiss, beds under the ambience, reverbs and the Echo choir effect) is original work and fully owned.
- No third-party sample libraries and no CC-licensed recordings were used.

## Voices (ElevenLabs Voice Library)
- **kabir**: Aaditya K - Deep Suspense Narrator (Indian English, ElevenLabs Voice Library) (voice id `0QDPl8K58QPS8hcIGchN`)
- **iyer**: AB - Warm, Precious Indian Narrator (Indian English, ElevenLabs Voice Library) (voice id `JSZ6mrlwqYAjKBo9OVaS`)
- **mira**: Clarice - Natural & Calm British Voice (ElevenLabs Voice Library) (voice id `MWUpoNpAY0rOQGP294mF`)
- **hale**: Joseph Ortman - Deep & Raspy (American, ElevenLabs Voice Library) (voice id `TTyZrDYo6LQowrH8mixJ`)
- **wren**: Mat - Nowhere to call home (Polish-accented English, ElevenLabs Voice Library) (voice id `I9PE7IST4MwUVorP7D20`)
- **okoye**: Hayjuju (Nigerian English, ElevenLabs Voice Library) (voice id `jEV3ve9f1syo5ox7LWaA`)
- **ortega**: Paul Urbina - Latino Male, gravelly (ElevenLabs Voice Library) (voice id `r2goToszgNLUzvFARGqy`)
- **The Echo** (log12, echo_came, echo_signal): Dr. Iyer's voice (AB), processed.

## How each group was made
### Voice-over (vo/, 54 files)
- **Script.** The text is exactly as in DESIGN.md §8–§10. For pronunciation only, "ORPHEUS" was sent as "Orpheus" and "NYX-7" as "Nyx-Seven". mira_code_hint was sent as "Month... then day." (same words, clearer pause).
- **Takes.** Most lines use Multilingual v2. kabir_wake ("[gasps] [coughs] ...Where... is everyone?") and kabir_echo ("[whispers]") use v3 audio tags. Second takes were made where the first misread a word: log01, mira_code_hint, mira_phase3 and kabir_transmission.
- **Research logs (log01–15):** band-limited 200–5000 Hz, soft saturation, light compression (2.5:1), faint flutter hiss, low room tone and 50 Hz hum, sparse crackles, a soft click at the start and end, and 0.25 s of room tone either side. -16 LUFS.
- **log12 and echo_came (the Echo):** Iyer's voice slowed 8% (rubberband), layered 3x (original, +0.35 semitone, one octave down), 6–6.5 s dark reverb, and a reversed reverb swell into the first word. log12 then also gets the recorder chain.
- **echo_signal:** the layered Iyer phrase looped for 9 s through a radio chain: 300–4000 Hz, overdrive, compression, carrier wobble and dropouts, static, squelch bursts, a heterodyne whine and a short metallic reverb.
- **kabir_transmission:** a tired, steady read through a radio channel (300–3400 Hz, drive, compression, hiss and squelch).
- **kabir_echo:** a v3 whisper layered 3x (one an octave down), saturated, with chorus and a 4.5 s reverb over faint static.
- **kabir_wake:** a v3 gasp and cough, then the line. Lightly roomed.
- **MIRA:** clean and close, with a 120 Hz high-pass, a subtle two-voice chorus (12% mix), a gentle 3.5 kHz presence lift, light compression and a tiny room. No bitcrush. -16 LUFS.
- **Check:** every file was transcribed with faster-whisper (small.en) and compared with the script; results are in `aw/transcripts.json`. Everything matches. The only differences are whisper mishearing names and accents (e.g. 'Rao' heard as 'Aral'; 'comms relay is' heard as 'relayers').

### Sound effects (sfx/, 101 files)
- **Generated** with ElevenLabs Sound Effects v2 from per-sound prompts (`sfx_defs.json`), then cleaned: high-pass, onset trim, tail cut at -50 dB (-62 dB for long cinematic sounds), fades, and peak normalisation to -1 dBFS (footsteps -1.5). Some sounds were normalised lower so their true peak stays below -0.3 dBTP.
- **Layered** (generated + synthesised): rifle_fire_1..3, pistol_fire_1..2, sentinel_bolt, sentinel_alert, herald_roar, herald_hurt, herald_rise, herald_death, herald_slam, brute_slam, signal_tone, rifle_tail.
  - Each rifle shot is two generated shots aligned at the transient, plus a synthesised noise crack, a short zap and a 52–64 Hz sub thump, compressed, transient-shaped (a tighter tail for auto-fire) and trimmed to about 0.3 s. Pistol shots are built the same way, with more crack and less sub.
  - The Herald sounds add generated choir layers (many human voices, pitched down 4–7 semitones), debris and big reverbs.
  - sentinel_alert adds a pitched-down human moan.
- **Synthesised** in numpy: heartbeat, keypad_beep, keypad_ok, keypad_err, door_locked, checkpoint, objective, ui_hover, ui_click, ui_back, comms_static, alarm_loop.
- **Seamless loops:** breath_exhausted, sentinel_hum, brute_breath, herald_beam, generator_loop, lift_loop, alarm_loop, heartbeat and comms_static.
  - The generated loops are cut where the tail best matches the head (cross-correlation search), then crossfaded with an equal-power curve.
  - The synthesised loops are built circularly (the klaxon is three exact 1.25 s cycles; static and heartbeat are wrapped).
  - Every join was checked: the step at the loop point is below the file's 99th-percentile sample step.

### Ambience (amb/, 6 files)
- Each area is built from four 22 s ElevenLabs Sound Effects v2 generations (prompts in `amb_defs.json`).
- **Cleanup:** 13 kHz low-pass, an automatic notch for narrow high whines (generated fluorescent-buzz whines at 11–15 kHz were removed or re-generated), and gain matching within ±6 dB.
- **Assembly:** the four clips are chained with 3 s crossfades, gently widened (M/S), and given a subtle synthesised bed with every frequency and LFO snapped to the loop length (e.g. hums, wind, reactor throb).
- **Loop:** tail into head with a 3 s equal-power crossfade, giving a 76.0 s seamless loop. -22 LUFS, Vorbis q4.

### Music (music/, 9 files)
- Generated with ElevenLabs Music in instrumental mode (prompts in `music_defs.json`). The tracks are original compositions, not covers. A whisper pass with VAD found no sung words.
- **Loop points** were found automatically, searching on log-band spectra plus onset strength. combat and boss were also constrained to whole 8-beat bars and kept clear of the track's outro.
- **Crossfades:** 5 s menu, 4 s explore, 1.5 s tension, 0.5 s combat and boss.
- **Mastering:** -16 LUFS, peak -1.5 dBFS, Vorbis q5.
- **Boss:** the second of two renders (`music_boss_b`, prompted to flow back into its own start) was used because its loop matched better. **Ending and stings:** music_ending is a through-composed piece that resolves and fades. The stings are trimmed from 10 s renders.

## File list
### vo
| file | length | ch | LUFS | true peak dBTP |
|---|---|---|---|---|
| vo/echo_came.ogg | 10.61 s | mono | -17.2 | -0.8 |
| vo/echo_signal.ogg | 9.00 s | mono | -16.2 | -0.7 |
| vo/kabir_echo.ogg | 5.73 s | mono | -17.1 | -1.6 |
| vo/kabir_transmission.ogg | 19.33 s | mono | -15.9 | -1.0 |
| vo/kabir_wake.ogg | 6.25 s | mono | -16.7 | -0.4 |
| vo/log01.ogg | 16.24 s | mono | -16.2 | -1.5 |
| vo/log02.ogg | 20.11 s | mono | -16.2 | -1.5 |
| vo/log03.ogg | 14.73 s | mono | -16.4 | -1.2 |
| vo/log04.ogg | 20.62 s | mono | -15.8 | -1.7 |
| vo/log05.ogg | 23.50 s | mono | -16.0 | -1.4 |
| vo/log06.ogg | 19.43 s | mono | -15.9 | -1.5 |
| vo/log07.ogg | 14.34 s | mono | -15.9 | -1.6 |
| vo/log08.ogg | 10.78 s | mono | -16.1 | -1.2 |
| vo/log09.ogg | 16.96 s | mono | -16.4 | -1.0 |
| vo/log10.ogg | 20.58 s | mono | -16.1 | -1.6 |
| vo/log11.ogg | 19.34 s | mono | -16.0 | -1.1 |
| vo/log12.ogg | 23.53 s | mono | -16.0 | -2.2 |
| vo/log13.ogg | 14.77 s | mono | -16.0 | -1.0 |
| vo/log14.ogg | 16.18 s | mono | -16.3 | -1.6 |
| vo/log15.ogg | 16.54 s | mono | -16.1 | -1.5 |
| vo/mira_armory.ogg | 3.71 s | mono | -17.1 | -1.5 |
| vo/mira_brute.ogg | 3.63 s | mono | -17.5 | -1.6 |
| vo/mira_checkpoint.ogg | 1.27 s | mono | -16.2 | -1.7 |
| vo/mira_code_hint.ogg | 6.59 s | mono | -16.1 | -1.6 |
| vo/mira_code_ok.ogg | 2.96 s | mono | -16.2 | -1.6 |
| vo/mira_comms.ogg | 2.45 s | mono | -16.8 | -0.7 |
| vo/mira_conduit.ogg | 6.72 s | mono | -16.6 | -1.5 |
| vo/mira_contact.ogg | 2.56 s | mono | -16.3 | -1.6 |
| vo/mira_crouch.ogg | 3.86 s | mono | -16.9 | -1.6 |
| vo/mira_door.ogg | 2.17 s | mono | -16.1 | -2.1 |
| vo/mira_gen_ok.ogg | 4.81 s | mono | -16.4 | -1.4 |
| vo/mira_gen_wrong.ogg | 4.46 s | mono | -16.5 | -1.3 |
| vo/mira_goodbye.ogg | 4.74 s | mono | -16.4 | -1.1 |
| vo/mira_herald.ogg | 3.36 s | mono | -16.2 | -1.6 |
| vo/mira_jump.ogg | 2.58 s | mono | -16.2 | -1.5 |
| vo/mira_lift.ogg | 2.36 s | mono | -16.1 | -1.5 |
| vo/mira_log.ogg | 2.98 s | mono | -16.2 | -1.3 |
| vo/mira_medkit.ogg | 2.31 s | mono | -16.6 | -1.2 |
| vo/mira_move.ogg | 4.06 s | mono | -16.5 | -1.6 |
| vo/mira_nodes.ogg | 3.13 s | mono | -16.4 | -1.1 |
| vo/mira_pad.ogg | 3.60 s | mono | -17.2 | -1.2 |
| vo/mira_phase3.ogg | 2.89 s | mono | -16.2 | -1.6 |
| vo/mira_power.ogg | 6.13 s | mono | -16.7 | -1.6 |
| vo/mira_reactor.ogg | 8.13 s | mono | -16.7 | -1.5 |
| vo/mira_reload.ogg | 1.94 s | mono | -16.1 | -1.5 |
| vo/mira_rerouted.ogg | 5.61 s | mono | -16.7 | -1.4 |
| vo/mira_research.ogg | 5.30 s | mono | -17.1 | -1.4 |
| vo/mira_sentinel.ogg | 3.73 s | mono | -16.6 | -1.6 |
| vo/mira_signal.ogg | 12.34 s | mono | -16.6 | -1.6 |
| vo/mira_surface.ogg | 5.14 s | mono | -16.7 | -1.5 |
| vo/mira_survive.ogg | 3.68 s | mono | -16.6 | -1.6 |
| vo/mira_victory.ogg | 2.54 s | mono | -16.5 | -1.5 |
| vo/mira_wake.ogg | 11.93 s | mono | -16.1 | -1.4 |
| vo/mira_weapon.ogg | 5.00 s | mono | -16.2 | -1.5 |

### sfx
| file | length | ch | LUFS | true peak dBTP |
|---|---|---|---|---|
| sfx/alarm_loop.ogg | 3.75 s | mono | -10.9 | -0.9 |
| sfx/ammo_pickup.ogg | 0.38 s | mono | n/a (too short) | -0.9 |
| sfx/bolt_impact.ogg | 0.80 s | mono | -20.3 | -0.4 |
| sfx/breaker_trip.ogg | 2.00 s | mono | -11.7 | -1.1 |
| sfx/breath_exhausted.ogg | 4.06 s | mono | -21.1 | -1.2 |
| sfx/brute_breath.ogg | 3.24 s | mono | -15.8 | -1.0 |
| sfx/brute_death.ogg | 3.00 s | mono | -8.9 | -0.8 |
| sfx/brute_hurt.ogg | 0.80 s | mono | -10.3 | -0.8 |
| sfx/brute_roar.ogg | 2.48 s | mono | -9.6 | -0.9 |
| sfx/brute_slam.ogg | 1.80 s | mono | -19.2 | -1.1 |
| sfx/brute_step.ogg | 0.80 s | mono | -22.1 | -0.9 |
| sfx/brute_swipe.ogg | 0.43 s | mono | -21.9 | -1.3 |
| sfx/checkpoint.ogg | 2.00 s | mono | -17.3 | -2.8 |
| sfx/comms_static.ogg | 4.00 s | mono | -19.2 | -3.2 |
| sfx/conduit_connect.ogg | 1.20 s | mono | -16.9 | -0.6 |
| sfx/conduit_rotate.ogg | 0.50 s | mono | -21.6 | -1.0 |
| sfx/cryo_hiss.ogg | 2.48 s | mono | -12.3 | -0.4 |
| sfx/door_close.ogg | 1.28 s | mono | -13.3 | -0.9 |
| sfx/door_locked.ogg | 0.67 s | mono | -15.5 | -1.2 |
| sfx/door_open.ogg | 1.28 s | mono | -16.0 | -1.0 |
| sfx/dry_fire.ogg | 0.35 s | mono | n/a (too short) | -1.4 |
| sfx/footstep_grate_1.ogg | 0.50 s | mono | -19.4 | -1.5 |
| sfx/footstep_grate_2.ogg | 0.50 s | mono | -19.9 | -1.3 |
| sfx/footstep_metal_1.ogg | 0.45 s | mono | -19.4 | -1.6 |
| sfx/footstep_metal_2.ogg | 0.37 s | mono | n/a (too short) | -1.4 |
| sfx/footstep_metal_3.ogg | 0.45 s | mono | -18.6 | -1.4 |
| sfx/footstep_metal_4.ogg | 0.45 s | mono | -20.2 | -1.5 |
| sfx/footstep_rock_1.ogg | 0.41 s | mono | -22.4 | -1.6 |
| sfx/footstep_rock_2.ogg | 0.45 s | mono | -24.9 | -1.9 |
| sfx/footstep_rock_3.ogg | 0.45 s | mono | -26.6 | -1.6 |
| sfx/gate_open.ogg | 3.20 s | mono | -19.0 | -1.8 |
| sfx/generator_loop.ogg | 3.04 s | mono | -14.1 | -1.3 |
| sfx/generator_start.ogg | 3.20 s | mono | -14.5 | -1.1 |
| sfx/glass_break.ogg | 1.48 s | mono | -17.9 | -1.2 |
| sfx/heal.ogg | 1.28 s | mono | -10.9 | -0.8 |
| sfx/heartbeat.ogg | 5.16 s | mono | -19.2 | -0.9 |
| sfx/herald_beam.ogg | 2.48 s | mono | -14.6 | -1.3 |
| sfx/herald_death.ogg | 6.07 s | mono | -17.0 | -1.2 |
| sfx/herald_hurt.ogg | 1.48 s | mono | -9.7 | -0.9 |
| sfx/herald_node_break.ogg | 1.60 s | mono | -14.7 | -0.8 |
| sfx/herald_rise.ogg | 6.06 s | mono | -20.2 | -0.9 |
| sfx/herald_roar.ogg | 3.20 s | mono | -14.7 | -0.8 |
| sfx/herald_shard.ogg | 1.20 s | mono | -15.3 | -1.0 |
| sfx/herald_slam.ogg | 1.98 s | mono | -20.4 | -1.0 |
| sfx/impact_crystal_1.ogg | 0.68 s | mono | -17.0 | -1.2 |
| sfx/impact_crystal_2.ogg | 0.68 s | mono | -17.2 | -0.7 |
| sfx/impact_flesh_1.ogg | 0.45 s | mono | -23.4 | -2.0 |
| sfx/impact_flesh_2.ogg | 0.45 s | mono | -22.4 | -0.3 |
| sfx/impact_flesh_3.ogg | 0.45 s | mono | -22.6 | -0.9 |
| sfx/impact_metal_1.ogg | 0.45 s | mono | -21.6 | -1.2 |
| sfx/impact_metal_2.ogg | 0.45 s | mono | -19.1 | -1.2 |
| sfx/impact_metal_3.ogg | 0.45 s | mono | -17.4 | -1.4 |
| sfx/item_pickup.ogg | 0.34 s | mono | n/a (too short) | -1.0 |
| sfx/jump.ogg | 0.68 s | mono | -19.9 | -1.2 |
| sfx/keycard_pickup.ogg | 0.50 s | mono | -24.6 | -1.9 |
| sfx/keypad_beep.ogg | 0.11 s | mono | n/a (too short) | -1.8 |
| sfx/keypad_err.ogg | 0.42 s | mono | -13.8 | -1.9 |
| sfx/keypad_ok.ogg | 0.55 s | mono | -11.2 | -1.5 |
| sfx/lamp_off.ogg | 0.09 s | mono | n/a (too short) | -1.2 |
| sfx/lamp_on.ogg | 0.26 s | mono | n/a (too short) | -0.6 |
| sfx/land.ogg | 0.64 s | mono | -20.8 | -1.2 |
| sfx/lift_loop.ogg | 3.01 s | mono | -15.1 | -0.9 |
| sfx/lift_stop.ogg | 1.42 s | mono | -16.6 | -1.5 |
| sfx/log_pickup.ogg | 0.82 s | mono | -25.4 | -1.3 |
| sfx/medkit_pickup.ogg | 0.59 s | mono | -20.9 | -0.7 |
| sfx/objective.ogg | 2.20 s | mono | -16.4 | -2.9 |
| sfx/pistol_fire_1.ogg | 0.30 s | mono | n/a (too short) | -1.1 |
| sfx/pistol_fire_2.ogg | 0.27 s | mono | n/a (too short) | -1.1 |
| sfx/pistol_reload.ogg | 1.23 s | mono | -18.4 | -0.8 |
| sfx/player_death.ogg | 3.48 s | mono | -6.1 | -0.8 |
| sfx/power_on.ogg | 2.89 s | mono | -21.5 | -1.3 |
| sfx/rifle_fire_1.ogg | 0.30 s | mono | n/a (too short) | -0.8 |
| sfx/rifle_fire_2.ogg | 0.32 s | mono | n/a (too short) | -1.2 |
| sfx/rifle_fire_3.ogg | 0.31 s | mono | n/a (too short) | -1.1 |
| sfx/rifle_reload.ogg | 2.00 s | mono | -18.0 | -1.1 |
| sfx/rifle_tail.ogg | 1.37 s | stereo | -15.2 | -3.1 |
| sfx/rumble.ogg | 3.00 s | mono | -18.7 | -1.1 |
| sfx/sentinel_alert.ogg | 1.60 s | mono | -12.9 | -1.1 |
| sfx/sentinel_bolt.ogg | 0.80 s | mono | -17.1 | -0.8 |
| sfx/sentinel_charge.ogg | 0.65 s | mono | -10.7 | -0.6 |
| sfx/sentinel_death.ogg | 2.20 s | mono | -11.3 | -0.9 |
| sfx/sentinel_hum.ogg | 3.91 s | mono | -14.7 | -1.0 |
| sfx/sentinel_hurt.ogg | 0.68 s | mono | -17.7 | -1.1 |
| sfx/shuttle_launch.ogg | 7.30 s | mono | -15.7 | -1.2 |
| sfx/signal_tone.ogg | 3.98 s | mono | -14.8 | -0.9 |
| sfx/sparks_1.ogg | 1.00 s | mono | -19.6 | -1.1 |
| sfx/sparks_2.ogg | 1.20 s | mono | -14.8 | -1.0 |
| sfx/stalker_attack.ogg | 0.86 s | mono | -12.2 | -0.7 |
| sfx/stalker_chitter.ogg | 2.93 s | mono | -22.8 | -1.0 |
| sfx/stalker_death.ogg | 2.00 s | mono | -10.2 | -0.4 |
| sfx/stalker_hurt.ogg | 0.68 s | mono | -9.6 | -1.0 |
| sfx/stalker_screech.ogg | 1.60 s | mono | -7.9 | -0.4 |
| sfx/steam_hiss.ogg | 1.48 s | mono | -10.0 | -0.9 |
| sfx/suit_hurt_1.ogg | 0.80 s | mono | -23.9 | -1.3 |
| sfx/suit_hurt_2.ogg | 0.88 s | mono | -20.4 | -0.9 |
| sfx/terminal_beep.ogg | 0.30 s | mono | n/a (too short) | -1.1 |
| sfx/ui_back.ogg | 0.16 s | mono | n/a (too short) | -2.9 |
| sfx/ui_click.ogg | 0.09 s | mono | n/a (too short) | -3.1 |
| sfx/ui_hover.ogg | 0.06 s | mono | n/a (too short) | -6.3 |
| sfx/vent_burst.ogg | 1.48 s | mono | -17.4 | -0.9 |
| sfx/weapon_switch.ogg | 0.26 s | mono | n/a (too short) | -1.2 |

### amb
| file | length | ch | LUFS | true peak dBTP |
|---|---|---|---|---|
| amb/amb_cryo.ogg | 76.00 s | stereo | -21.9 | -4.5 |
| amb/amb_exterior.ogg | 76.00 s | stereo | -22.1 | -4.2 |
| amb/amb_extraction.ogg | 76.00 s | stereo | -21.9 | -2.9 |
| amb/amb_reactor.ogg | 76.00 s | stereo | -22.0 | -8.5 |
| amb/amb_research.ogg | 76.00 s | stereo | -22.0 | -3.5 |
| amb/amb_security.ogg | 76.00 s | stereo | -21.9 | -5.1 |

### music
| file | length | ch | LUFS | true peak dBTP |
|---|---|---|---|---|
| music/music_boss.ogg | 110.00 s | stereo | -16.1 | -4.7 |
| music/music_combat.ogg | 67.87 s | stereo | -16.0 | -3.4 |
| music/music_ending.ogg | 78.05 s | stereo | -16.0 | -2.3 |
| music/music_explore.ogg | 92.21 s | stereo | -16.1 | -1.4 |
| music/music_menu.ogg | 145.74 s | stereo | -16.1 | -3.1 |
| music/music_tension.ogg | 69.50 s | stereo | -16.0 | -3.6 |
| music/sting_death.ogg | 4.50 s | stereo | -15.9 | -4.5 |
| music/sting_discovery.ogg | 6.50 s | stereo | -15.0 | -1.2 |
| music/sting_reveal.ogg | 8.50 s | stereo | -16.9 | -4.6 |
