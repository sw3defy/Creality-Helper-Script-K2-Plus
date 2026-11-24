# Live ROM versus installed configuration differences — 2026-11-24

Read-only operator diff of `/rom/usr/share/klipper/config/F008_CR0CN240319C13` against `/mnt/UDISK/printer_data/config`.

## Confirmed

- `box.cfg`, `box.cfg.bak` match stock exactly. `motor_control.cfg` matches stock exactly.
- `gcode_macro.cfg` differs from ROM. `gcode_macro.cfg.bak` differs from both ROM and active; do not assume backup is pristine.
- `ACCURATE_G28` stock `ACCURATE_HOME_Z` changed to `NEXT_HOMEZ_NACCU` then `G28 Z`.
- `SET_CHAMBER_FAN`, `WAIT_BED_STABLE_POS`, `TEST_HOME`, diagnostic macros, timer macros renamed with underscore prefix in active file.
- `START_PRINT` references `params.BED_TEMP` / `params.EXTRUDER_TEMP` changed to local `BED_TEMP` / `EXTRUDER_TEMP`. This may be intentional if those local variables are set; inspect surrounding macro before concluding a defect.
- `Qmode_exit` calls changed to `QMODE_EXIT`.
- `G29` and `BED_MESH_CALIBRATE_START_PRINT` `PROBE_COUNT` string concatenation changed to include equals sign.
- `printer.cfg` adds includes for `fans_control.cfg`, `useful_macros.cfg`, `z_offset_macros.cfg`, `m600.cfg`, `shapers_calibration.cfg`, `timelapse.cfg`; KAMP include is commented.
- `[mcu rpi]` and `[bl24c16f]` commented out in active file.
- Bed heater explicit PID parameters commented out in active main config; auto-generated SAVE_CONFIG block includes bed PID values. Do not discard SAVE_CONFIG.
- `[prtouch_v3]` `speed` 5 -> 300; `[bed_mesh]` `mesh_min` 5,5 -> 20,20.
- Active `SAVE_CONFIG` contains `[box]` `cut_pos_x=-7.80`, auto address, bed mesh, bed PID; preserve.
- CFS under-extrusion reported after three Benchy attempts, but no causal link proven. Do not attribute edits to HelixScreen without installation-history evidence.

## Follow-up priorities

1. Read-only inspect exact `START_PRINT` variable declarations, the active and stock `ACCURATE_G28` callers, and the relevant stock/active macro backup differences.
2. Audit active add-on macros for conflicts and modifications to extrusion/feed/flow/pressure advance or CFS.
3. Trace file-edit origins from Helper Script installers and history.
4. No bulk ROM restoration, no printer restart or configuration changes without precise backup, impact review and user approval.

Policy: preserve working stock Creality macros; only optional, measured, reversible enhancements.
