# Camera boot-path validation — 2026-11-24

Operator-supplied, read-only observation; no printer changes.

## Confirmed

The Helper Script's `/mnt/UDISK/helper-script/.installed` file contains:
`moonraker_extensions`, `fans_control_macros`, `useful_macros`, `z_offset_macros`, `m600_support`, `kamp`, `improved_shapers`, `fluidd_updated`, `mainsail`, `moonraker_timelapse`, `camera_support`, `helixscreen`, `entware`.

The empty `installed/` directory check in the first inventory was a path mismatch, **not** missing tracking.

Camera startup inspection:
- `/etc/init.d/S99camera` and `/etc/rc.d/S99camera` are distinct regular files with matching content and different inodes.
- `/etc/rc.local` explicitly invokes `/etc/rc.d/S99camera start &`.
- `/etc/rc.d/S99camera.bak` exists and must not be overwritten or deleted.
- Existing `/tmp/camera_startup.log` shows one `Camera bridge started` line. This does not prove how many invocations occurred across the lifetime of the boot or whether logs were rotated/truncated.
- `/tmp/go2rtc.log` reports go2rtc 1.9.14 and listeners on 1984, 8554, 8555.
- Process inventory shows exactly one go2rtc process (PID 4261) and one camera watchdog process (PID 4272).
- Search for `rc.d`, `rc.local`, `run_scripts` in `/etc/init.d/rcS` and `/etc/inittab` produced no matches. This is inconclusive as to actual boot invocation.
- `ubus` showed no service registered under `S99camera`.

## Conclusion

No duplicate camera process is observed, but duplicate startup **configuration** remains possible. The observed single startup-log entry is reassuring, not conclusive. Do not change the currently working camera, delete startup entries, or execute the script's broad `stop` function.

A read-only inspection of `/etc/rc.d/S99camera.bak`, init boot sequencing, and `rc.local` context may clarify whether the duplicate path is executed. Do not publish camera stream secrets or private URLs.

Source-level release gate remains unchanged: camera removal must be ownership-aware and reversible; current legacy remover is blocked.
