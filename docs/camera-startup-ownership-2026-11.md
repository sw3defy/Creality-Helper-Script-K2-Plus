# Camera startup and config ownership — observed 2026-11-24

Read-only live inspection provided by operator.

## Confirmed

- Installed-state tracker is `/mnt/UDISK/helper-script/.installed` (a file), **not** a directory named `installed`. The earlier empty listing was due to inspecting the wrong path.
- `printer.cfg` directly includes `sensorless.cfg`, `gcode_macro.cfg`, `printer_params.cfg`, `box.cfg`, `motor_control.cfg`, `fans_control.cfg`, `useful_macros.cfg`, `z_offset_macros.cfg`, `m600.cfg`, `shapers_calibration.cfg`, and `timelapse.cfg`.
- User Moonraker config includes `[file_manager]` (line 9) and `[timelapse]` (line 12).
- Camera startup script exists as two **regular executable files**, `/etc/init.d/S99camera` and `/etc/rc.d/S99camera`. SHA-256 of both is `46bdd0aca0d50ad9507e36e1ae003160db75056dc7f826062926c9446f1f336d`.
- Each script's `start` sleeps 60 seconds, starts go2rtc, sleeps 5 seconds, then starts `camera_watchdog.py`. `stop` uses broad `killall go2rtc` and process-list parsing; this is not ownership-safe.
- `/etc/rc.local` line 13 also launches `/etc/rc.d/S99camera start &`.
- `ubus call service list '{"name":"S99camera","verbose":true}'` returned an empty object, indicating no matching procd registration in that response.
- Earlier process inventory showed exactly one go2rtc process and one camera watchdog process.

## Assessment

Potential **duplicate invocation** if the system boot sequence automatically runs `/etc/rc.d/S99camera` and `rc.local` also starts it. The evidence does not yet prove duplicate invocation or duplicate running processes. Confirm boot sequence behavior and inspect existing logs/process start times **read-only** before any remediation.

Do **not** remove either file, disable rc.local, call `stop`/`restart`, or use `killall` on the working printer. Preserve camera feeds and HelixScreen. Future camera installer must use a single owned startup mechanism, detect legacy duplicate registrations, and provide a backup/rollback plan.

The installed-state tracker content and exact boot invocation remain unverified.
