# Live boot-hook dispatch verification — 2026-11-24

Operator read-only inspection of the **live** `/mnt/UDISK/helper-script/scripts/system.sh`:

- `grep -n -E 'patch_stock_configs|legacy_patch_stock_configs|case "\$1"|patch_moonraker_startup' ...` found `patch_moonraker_startup()` at line 160, `unpatch_moonraker_startup()` at line 178, and the dispatcher at line 249. It found **no** `patch_stock_configs` implementation or dispatch entry.
- The displayed dispatcher handles only `restart_klipper`, `restart_moonraker`, `restart_nginx`, `restart_camera`, and `show_installed`. There is no fallback mutation.
- Therefore the `/etc/rc.local` invocation `system.sh patch_stock_configs` is **not dispatched to a stock-patching action by the code shown**. This does not establish the absence of unrelated boot modifications.
- Legacy `patch_moonraker_startup()` still contains `sed -i` changing the stock `CONF=` path, and `unpatch_moonraker_startup()` still writes the startup script. These are not invoked by the observed dispatcher. Do not enable them.
- `/etc/inittab` references `/etc/init.d/rcS`, but the path was absent in read-only listings of `/etc/init.d/rcS`, `/etc/rcS`, `/etc/rc.d/rcS`, and `/sbin/rcS`. The system is nevertheless running. Do not infer a broken boot or edit `inittab` without understanding the firmware's actual init mechanism.
- The only `S99camera` text reference found under `/etc/init.d`, `/etc/rc.local`, `/etc/inittab` was `/etc/rc.local:13`. This does **not** prove that an rc.d enumerator does not execute `S99camera`.

## Action

No live changes recommended. In future, remove the obsolete `rc.local` line only through a narrowly scoped, backed-up migration after exact file-content matching and rollback validation. Keep Moonraker startup and camera uninstall guards fail-closed.
