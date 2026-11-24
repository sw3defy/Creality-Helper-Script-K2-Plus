# Live stock macro comparison — 2026-11-24

Operator read-only SHA-256 comparison against ROM stock path `/rom/usr/share/klipper/config/F008_CR0CN240319C13`:

- `box.cfg`: **identical** to stock, SHA-256 `5e152bfcf7103895aca4d46340ea8b2e792f263538933cd881a989b3bdcc649a`.
- `motor_control.cfg`: **identical** to stock, SHA-256 `19bfced4b414347e9c13b3e5da3db9702dee40211b809bdd880559fb2bc3afbc`.
- `gcode_macro.cfg`: **different**. Stock SHA-256 `c78b880ade9779bad6c4d6e17ad9934b9ca766b15cc8fe5eb04b3c0dd6dfec6a`; active `244f2b285ef8dda40d2793edc4bae05c40a1e414647e3c1c0428c42b32f44f38`.
- `printer.cfg`: **different**. Stock SHA-256 `cb2a33c5af33acc15db1dfdfcea36b737f1d3fc47b6950f6d39167899e55e4ea`; active `e947ba018a743a02c9826bb5d61a8a4a94d9482a52574b8a128be338390d2bc0`.
- Active `box.cfg` has `BOX_LOAD_MATERIAL*`, `BOX_QUIT_MATERIAL*` and `BOX_INFO_REFRESH` macros.
- Active `gcode_macro.cfg` contains `LOAD_MATERIAL*`, `QUIT_MATERIAL*`, `START_PRINT`, `END_PRINT`, `PAUSE`, `RESUME`.
- Active `m600.cfg` adds `M600`, `FILAMENT_LOAD`, `FILAMENT_UNLOAD`.
- Historical `box.cfg.bak` and `gcode_macro.cfg.bak` exist. Their contents/age are unverified.

## Interpretation

The CFS box macro file and motor-control configuration are intact relative to ROM. This narrows the focus to **exact differences** in `gcode_macro.cfg` and `printer.cfg`, any macro name collisions and call-chain effects. A hash mismatch is not proof of a regression; compare line-by-line before recommending changes. Do not restore backups, patch stock files or restart the printer.

## Policy

Stock macro edits are prohibited by default. Optional improvements must be additive, measured and reversible; modifying a stock macro requires specific demonstrated defect, validated behavior and rollback.
