# Boot startup inspection — 2026-11-24

Operator-supplied read-only results.

- `/etc/inittab` uses `::sysinit:/etc/init.d/rcS S boot` and `::shutdown:/etc/init.d/rcS K shutdown`. The `/etc/init.d/rcS` path was not found by `ls`, so do not assume standard OpenWrt startup sequencing without locating the actual boot runner.
- `/etc/rc.d/S95done -> ../init.d/done`, and `/etc/init.d/done` executes `sh /etc/rc.local` when present.
- `/etc/rc.local` contains a Moonraker status/start guard (lines 9-11), `/etc/rc.d/S99camera start &` (line 13), an Entware startup (line 15), and `/bin/sh /mnt/UDISK/helper-script/scripts/system.sh patch_stock_configs` (line 18).
- The last command is a **potentially mutating boot hook**. The live `system.sh` has not been inspected, so effects and current behavior are **unknown**. Do not assume the development branch's disabled patch handler is deployed.
- `S99camera.bak` differs from the active camera script by starting `k2rtc.py` and adding its stop handler; the active script does not run `k2rtc.py`. Do not restore backup without verifying current go2rtc pipeline.
- Duplicate camera boot invocation remains unproven. Need inspect boot runner and `rc.local` context read-only.

## Safety decision

Do not reboot or modify the working printer until the live `system.sh patch_stock_configs` behavior and the actual boot sequence have been identified. Do not change `rc.local` or camera startup files speculatively.
