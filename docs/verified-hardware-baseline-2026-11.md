# Verified K2 Plus hardware baseline — 2026-11-24

This is a **read-only observation**, not approval to deploy changes.

The operator ran the following commands on the live printer `K2Plus-DE6C` and supplied their output:

| Check | Observed result |
| --- | --- |
| `ls -l /etc/rc.d/S56moonraker` | Symlink to `../init.d/moonraker` |
| `ps \| grep '[m]oonraker.py'` | Exactly one Moonraker process, PID 3184 |
| `ubus call service list '{"name":"moonraker","verbose":true}'` | `instance1` running, PID 3184, stock config |
| `curl http://127.0.0.1:7125/server/info` | `klippy_connected=true`, `klippy_state=ready`, no failed components, no warnings |
| Stock Moonraker include check | Line 1 includes `/mnt/UDISK/printer_data/config/moonraker.conf` |

Process command line: `/usr/share/moonraker-env/bin/python /usr/share/moonraker/moonraker.py -c /usr/share/moonraker/moonraker.conf -l /mnt/UDISK/printer_data/logs/moonraker.log`.

Moonraker API components included `timelapse` and `webcam`; this confirms component loading, **not** image delivery. Earlier separate operator observation confirmed HelixScreen and both Mainsail and Fluidd camera feeds worked.

## Conclusions

- The previously repaired Moonraker startup topology remained correct at the time of inspection.
- No duplicate Moonraker instance was observed.
- No live repair, restart, reboot, or install is indicated by these checks.
- This observation **does not** validate any currently blocked installer, uninstaller, or the development branch's compatibility with the printer.
- Preserve the current live installation. Next steps must be read-only inventory and offline tests before any firmware-side change.
