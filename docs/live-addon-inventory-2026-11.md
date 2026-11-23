# Live add-on inventory — operator observation, 2026-11-24

This inventory was supplied by the printer operator. No live modifications were made. File timestamps are recorded as shown and are **not** reliable evidence of installation chronology.

## Observed

- `/mnt/UDISK/helper-script` exists. `scripts/system.sh` exists (8,852 bytes; listed timestamp June 10 19:55). This does **not** establish that the live script matches the development branch.
- `ls -la /mnt/UDISK/helper-script/installed 2>/dev/null` produced no output. Because stderr was suppressed, this does **not** distinguish a missing directory from other access errors or prove that no add-ons are installed. Treat installed-marker state as **unverified**.
- `/mnt/UDISK/printer_data/config` contains active-looking add-on configuration files: `KAMP/`, `fans_control.cfg`, `m600.cfg`, `shapers_calibration.cfg`, `timelapse.cfg`, `useful_macros.cfg`, `z_offset_macros.cfg`, and `helixscreen/`. Presence alone does **not** prove Klipper loads them; includes must be inspected.
- `printer.cfg` exists and is 10,340 bytes. Many `printer-*.cfg` snapshots and additional `.bak` files exist. Do not clean these up without ownership/retention analysis.
- HelixScreen process chain: launcher PID 3331, watchdog PID 4242, screen PID 4243.
- Camera processes: `go2rtc` PID 4261 and `camera_watchdog.py` PID 4272.
- Both `/etc/init.d/S99camera` and `/etc/rc.d/S99camera` are regular executable files, each 592 bytes. **Unlike the Moonraker symlink, this alone is not proof of a camera startup fault.** Inspect exact contents and `rc.local` before deciding whether the camera may be launched twice.
- `/mnt/UDISK`: 27.5G total, 538.1M used, 27.0G available (2% used).

## Findings and follow-up

1. **High-priority ownership uncertainty:** add-on files exist but installed-state markers were not observed. Never infer ownership or uninstall safety from a marker alone. Avoid automatic cleanup, reinstall, migration, or removal.
2. **Potential camera startup overlap (unconfirmed):** inspect read-only `/etc/init.d/S99camera`, `/etc/rc.d/S99camera`, `/etc/rc.local`, and `ubus` service registration. Do not change or restart the currently working camera.
3. **Config include verification needed:** inspect include directives in `printer.cfg`, relevant add-on sections in the user Moonraker config, and camera process ownership. Do not dump secrets, authorization keys, or full configuration publicly.
4. **Live script provenance needed:** identify script checkout/version using read-only metadata; do not overwrite the existing helper-script directory.

## Release implication

This supports the previous decision to keep legacy add-on removers blocked. The observed installation cannot safely be managed by marker-only or filename-only logic. A future migration needs exact config references, ownership records, snapshots, preflight checks and rollback.
