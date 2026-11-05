# ECHOES OF THE VOID - Test report, v1.0.1

Build version 1.0.1 (Android versionCode 2). Date 2026-11-04 (UTC). Game code at commit b6b53c6 (tag v1.0.1).
Godot 4.7.2. Every result below was produced on the build machine: headless Linux, software GL (swiftshader/compat),
and wine for the Windows build. No real phone, no real GPU, no Android emulator was used.

## Automated results (final regression, 2026-11-04)
| Suite | Result |
|---|---|
| Script check (all project scripts compile) | 95 scripts, 0 failed |
| Collision sweep | 37,812 checks, 0 failures |
| Explore driver (all 6 areas, checkpoints, exits) | 161 checks, 0 failures |
| Movement | 24/24 |
| AI | 9/9 |
| v1.0.1 regression (falls, saves, camera, ui) | 31/31 |
| Save cross-process (save, quit, relaunch, continue) | 15/15 |
| Input flows (touch stick, look, fire, jump, aim, use, multi-touch, pause, Android back, death/retry x3, quit/continue x3) | 57/57 |
| UI layout at 20:9, 16:9, 4:3, 19.5:9, touch on and off | 1,460 checks, 0 problems |
| Full autotest (headless, desktop build) | 100/100 (weapon kills 15, forced kills 7) |
| Windows build under wine: autotest | 100/100 |

Notes on the earlier runs kept in the task folder: an early UI run at 1600x720 (6 problems) and 2400x1080 (4 problems)
was the pre-fix baseline; the final run at both sizes is in the 1,460-check result above.

## Performance (headless, software renderer; not a device measurement)
Perf logs were taken with the dummy audio driver. Frame times and memory on the web build and the APK budget
were measured only in this headless setup. Real-device frame times are NOT measured (see Untested).

## Untested
- Real Android phone (install over 1.0.0, touch layout on the device, back button, audio): not run.
- Real Windows PC with a GPU (only wine + software paths): not run.
- Web build on a real phone browser and a real desktop GPU: not run (headless Chromium only).
- A 30-45 minute human playthrough: not done.
- The Windows exe is unsigned (known issue, unchanged from 1.0.0).
