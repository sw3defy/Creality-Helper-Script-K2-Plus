# Changelog

## [Unreleased] - 2026-06-17

### Fixed
- **CFS load/unload failures** — Root cause identified and fixed: stock Creality
  firmware ships box.cfg and gcode_macro.cfg with all macros prefixed with
  an underscore (e.g. _BOX_QUIT_MATERIAL, _WAIT_TEMP_START). In Klipper,
  a leading underscore makes a macro private/hidden, meaning it cannot be called
  by the CFS system, the UI, or other macros. The helper script now automatically
  patches these files on startup via patch_stock_configs() in system.sh.

### Errors resolved
- key865 - retrude error, failed to exit connections
- key789 - position tracking error on X/Y axes
- key22 - no trigger on Y after full movement
- key274 - unknown g-code state: helix_cfs_load
- Unknown command: WAIT_TEMP_START
- Unknown command: END_PRINT_POINT
- Unknown command: PRINT_PREPARE_CLEAR
- Unknown command: CANCEL_CHAMBER_FAN_SWITCH

### Known issues being investigated
- useful_macros.sh installs START_PRINT, END_PRINT, PAUSE, RESUME,
  CANCEL_PRINT macros that conflict with and override the stock Creality
  versions which have full CFS integration. This will be fixed in a future
  update to only install macros that do not exist in stock.
