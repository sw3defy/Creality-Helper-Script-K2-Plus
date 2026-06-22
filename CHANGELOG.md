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



### Also fixed (2026-06-17)
- **printer.cfg mesh_min edge artifact** — Stock Creality firmware sets
  `mesh_min: 5,5` which causes the adaptive bed mesh algorithm to probe
  too close to the bed edge, producing false spike readings at the front-left
  corner. The helper script now automatically patches this to `mesh_min: 20,20`
  on startup via `patch_stock_configs()` in `system.sh`.
- **Duplicate patch_stock_configs function** — Removed a duplicate function
  that was accidentally added to `system.sh`.

- **useful_macros.sh conflicting macros** — Removed START_PRINT, END_PRINT,
  PAUSE, RESUME, CANCEL_PRINT from useful_macros.sh. These are already defined
  in stock gcode_macro.cfg with full CFS integration (BOX_START_PRINT,
  BOX_END, BOX_END_PRINT etc). Overwriting them broke CFS filament loading
  and unloading. useful_macros.sh now only installs genuinely new macros:
  PID_HOTEND, PID_BED, PID_CHAMBER, BED_LEVELING, Z_TILT_CALIBRATE,
  WARMUP, CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS.


### Also fixed (2026-06-18)
- **patch_stock_configs not running on boot** — The stock config patches
  were only applied when helper.sh was run manually from the menu. This
  meant reboots would revert the fixes. Added install_rc_local_patch()
  which adds patch_stock_configs to /etc/rc.local so fixes are applied
  automatically on every boot.


### Also fixed (2026-06-22)
- **Moonraker silently ignoring UDISK extension config** — The stock
  moonraker init script only loads /usr/share/moonraker/moonraker.conf.
  The UDISK config at printer_data/config/moonraker.conf (where
  [timelapse] and the HelixScreen update_manager settings live) was
  never actually read. Added install_moonraker_include() which wires
  up the proper [include] directive and avoids a recursive-include
  loop. This was the root cause of prints getting stuck at 99% /
  showing as "Cancelled" in history -- TIMELAPSE_RENDER would throw
  an unregistered-remote-method error mid-END_PRINT and the gcode
  stream would abort before the file finished reading.
- **Missing END_PRINT underscore fixes** — _PRINT_PREPARE_CLEAR,
  _END_PRINT_Z_SAFE, _QMODE_EXIT, _END_PRINT_POINT, and
  _WAIT_TEMP_START were still called with underscores from inside
  other macros, even though their definitions were already patched.
  These are now fixed too.


### Also fixed (2026-06-22)
- **queue_gcode_uploads race condition** — Stock moonraker.conf has
  this set to False, causing Mainsail/Fluidd to poll for gcode
  metadata before background extraction finishes on larger files.
  This produced hundreds of "Metadata not available" errors per
  upload and made history permanently show "Unknown" as the slicer.
  install_moonraker_include() now also flips this to True.
- Fixed install_moonraker_include() returning early when the include
  line was already present, which skipped any fixes added after it.


### Also fixed (2026-06-22)
- **helper.sh failed on first run for everyone** — SCRIPTS_DIR was
  already set to .../helper-script/scripts, but the line sourcing
  system.sh appended another /scripts/ segment, producing a path
  that doesn't exist (scripts/scripts/system.sh). This crashed
  helper.sh immediately for any brand new install, before reaching
  the menu at all. Reported by a user attempting first setup.

### Known issues being investigated
- useful_macros.sh installs START_PRINT, END_PRINT, PAUSE, RESUME,
  CANCEL_PRINT macros that conflict with and override the stock Creality
  versions which have full CFS integration. This will be fixed in a future
  update to only install macros that do not exist in stock.
