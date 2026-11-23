# K2 Plus Timelapse and Benchy clogging investigation — 24 November 2026

> **Open investigation — not a confirmed root cause**
Three Benchy attempts stopped extruding and ended with nozzle clogs, including after a Micro Swiss high-flow nozzle upgrade. Timelapse was reportedly enabled during those attempts. **Do not enable Timelapse parking for further tests until compatibility is established.** No firmware, CFS or stock macro changes have been authorized.

## Verified read-only findings

- Five stored Benchy G-code files each contain **300 executable `TIMELAPSE_TAKE_FRAME` calls and one executable `TIMELAPSE_RENDER`**. Two other stored Benchy G-code files have neither. A second render reference in the slicer metadata is only a comment.
- Example at the first layer: `G92 E0`, `G1 E-.8 F3000`, then `TIMELAPSE_TAKE_FRAME`. The slicer has already retracted 0.8 mm.
- Current Moonraker `/machine/timelapse/settings`: `enabled=false`, `parkhead=true`, front-left park, `park_retract_distance=1.0`, `park_extrude_distance=1.0`, `fw_retract=false`, `autorender=true`. **These are current settings, not a record of settings during failed prints.**
- Current live Klipper macro state: `enable=false`, `park.enable=true`, park coordinates `x=-7.8, y=-6.2`, `macro.pause=PAUSE_BASE`, `macro.resume=RESUME_BASE`, 1 mm retract/restore. Parking coordinates require checking against the actual printer motion envelope; do not presume they are invalid.
- `TIMELAPSE_TAKE_FRAME` retracts, pauses, parks, captures, resumes and restores extrusion **only if both capture and parking are enabled**. When parking is disabled, it does not execute that retract/pause/park branch.
- Creality's **full** `PAUSE` calls `PAUSE_EXTERNAL`, which includes `M104 S140`, additional retraction, nozzle cleaning and fan changes. The full `RESUME` includes temperature restoration and CFS-related handling. **The live Timelapse configuration calls `PAUSE_BASE` / `RESUME_BASE`, bypassing these full Creality routines. There is no evidence that Timelapse caused the nozzle to cool to 140°C.**
- One Moonraker process was observed; duplicate MP4s were observed for some models, but no proof of duplicate running Timelapse components or duplicate render G-code.
- Klipper object list confirms `TIMELAPSE_TAKE_FRAME`, `print_stats`, `PAUSE`, `RESUME` and CFS macros are registered. Correct object query uses separate URL query parameters, e.g. `curl -sG --data-urlencode 'gcode_macro TIMELAPSE_TAKE_FRAME' --data-urlencode 'print_stats' http://127.0.0.1:7125/printer/objects/query`.

## Working hypotheses, not conclusions

1. If parking was enabled during the failed prints, frequent additional retractions, parking movements or restoration timing may contribute to extrusion interruption or clogging. Balanced 1 mm retract and 1 mm restore **do not automatically imply cumulative filament loss**.
2. Heat creep, hotend fan behavior, filament grinding, temperature anomalies, or CFS feeding issues remain plausible.
3. The repeated clogging across two nozzle setups points toward investigating shared operating conditions rather than assuming a nozzle defect.
4. Timelapse is **not yet proven causal**; historical macro settings and logs remain to be correlated with the failed prints.

## Next read-only checks

- Inspect complete Timelapse setup/state restoration macros, particularly `_SET_TIMELAPSE_SETUP`, `_WAIT_TIMELAPSE_TAKE_FRAME` and state restoration.
- Inspect remainder of Creality `RESUME_EXTERNAL` (including the calculated `PAUSE.extrude + 80.0`), but do not infer that it ran under Timelapse's current base-macro configuration.
- Examine relevant `klippy.log` and Moonraker logs around failure timestamps for heater targets, filament sensor/CFS events, extrusion errors, and pause/resume activity.
- Correlate failed print filenames, timestamps and effective Timelapse settings; verify whether the parked head and extruder state were actually active.
- Only after evidence review, plan a controlled print with Timelapse disabled and otherwise comparable settings.

**Safety:** Preserve stock `box.cfg`, `motor_control.cfg`, Creality CFS macros, calibration and `SAVE_CONFIG`. Do not restore ROM configs wholesale, modify the live printer, reboot, or merge untested installer changes without explicit approval. Main Helper Script maintenance work remains in unmerged PR #7.
