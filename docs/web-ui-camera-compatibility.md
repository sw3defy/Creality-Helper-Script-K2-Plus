# K2 Plus web UI update and camera compatibility

## Scope and current validation

The helper's existing camera installer injects `enableCamera()` into Fluidd
and `enableMainsailCams()` into Mainsail. These scripts use the UI's private
Vue `__vue__.$store` structure. Preserving the scripts during an update does
**not** prove that a new Fluidd or Mainsail release still supports that private
API. The camera bridge, watchdog, nginx and Moonraker registration remain
separate from the UI asset updater.

The update utility validates an official release archive, stages files away
from the active installation, transplants the existing camera script when it
can be unambiguously identified, and keeps a previous-directory rollback.
Offline tests cover staging, archive rejection and rollback, but **do not
validate camera streaming or printer firmware compatibility**.

## Hardware acceptance checks before merging PR #7

1. Record K2 Plus firmware, Fluidd and Mainsail versions, Moonraker version,
   camera endpoints and whether both dashboards display a live feed.
2. Back up the original `/usr/share/fluidd` and `/usr/share/mainsail`
   trees and verify that the backups can be restored.
3. Verify printer is idle and all existing camera streams, CFS and stock
   functions are operating before any UI update.
4. On a controlled printer test, update **one** UI at a time using the
   explicit confirmation. Verify the camera stream, dashboard navigation,
   reconnect behavior, websocket and webcam settings after the update.
5. Confirm that the original camera script is present once, that the nginx
   configuration is unchanged, and that no Klipper/Moonraker/camera service
   was restarted by the updater.
6. If the camera disappears, **do not repeat the installer blindly**.
   Restore the saved UI directory and investigate the private Vue API
   compatibility before attempting another update.
7. Repeat separately for the other UI. Confirm the rollback backup cannot
   be overwritten and that existing printer controls still function.

**Release gate:** CI passing is necessary but insufficient. Do not merge
until a human has completed these printer-side checks. No hardware operation
is performed by this document or by the offline test suite.
