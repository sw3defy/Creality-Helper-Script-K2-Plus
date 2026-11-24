# K2 Plus native fan slider compatibility — engineering acceptance criteria

Status: **unverified; do not enable installer**.

## Verified on the inspected printer

Creality's stock `gcode_macro.cfg` owns `M106` and `M107`, including `P` selection, Qmode, and minimum-speed logic. An older helper `fans_control.cfg` also defined those macros and could override stock behavior. The unmerged maintenance branch removes unreachable direct-pin override code and blocks fan install/removal.

## Critical distinction

A Mainsail or Fluidd **macro button** that sends `M106 P... S...` is not a native slider. A native slider may send `SET_FAN_SPEED`, `SET_PIN`, or other commands based on the exposed Klipper object. Merely adding `SET_FAN0` and `SET_FAN2` macros does **not** guarantee that sliders use stock logic.

## Proposed acceptance tests (hardware tests require explicit permission)

1. Identify exact exposed Klipper objects and their types from the printer's read-only Moonraker `printer.objects.list` response.
2. Identify native slider G-code or API commands in the installed Mainsail and Fluidd builds. Do not infer behavior from generic upstream documentation.
3. For each part/aux fan, compare the native slider's command with stock `M106 P0/P2 S...` behavior at 0, low, medium, and full speeds, including minimum-speed enforcement.
4. Verify Qmode and CFS operations do not regress; confirm state reporting and UI refresh without printer-side macro overrides.
5. Confirm that a standard Klipper `fan` object is not being confused with Creality's `output_pin fan0/fan2` or temperature-controlled chamber fan.
6. Test safe rollback and upgrades without editing `gcode_macro.cfg`, `box.cfg`, or `printer.cfg` unexpectedly.

## Design decision gate

If a native slider directly controls a Klipper fan object and bypasses `M106`, changing a macro alone cannot intercept it. Evaluate a UI-specific adapter or explicit stock-command controls. **Do not claim the native slider is fixed until the exact command path has been tested.**

No printer edits, restarts or live fan operations are authorized by this document.
