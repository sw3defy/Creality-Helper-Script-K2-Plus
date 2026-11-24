# K2 Plus Moonraker duplicate-process recovery (verified 2026-11-24)

## Scope and observed failure

On a Creality K2 Plus running Creality's OpenWrt 21.02 firmware, three `moonraker.py` processes were observed. The healthy process was supervised by OpenWrt procd and loaded `/usr/share/moonraker/moonraker.conf`. Two unsupervised processes loaded either the same stock file or the extension-only `/mnt/UDISK/printer_data/config/moonraker.conf`. Logs showed address-in-use errors.

The installed legacy Helper Script had replaced `/etc/rc.d/S56moonraker` with an independent executable setting `CONF=/mnt/UDISK/printer_data/config/moonraker.conf`. The canonical `/etc/init.d/moonraker` still used `CONF=/usr/share/moonraker/moonraker.conf`. The stock configuration already contained `[include /mnt/UDISK/printer_data/config/moonraker.conf]`. Thus the UDISK file was an extension, **not** a standalone server configuration.

## Verified outcome

With the printer idle, the two known unsupervised duplicate PIDs were terminated after checking their command lines and confirming the procd-owned PID. The standard startup link was restored with backups. Following a **normal OS reboot**, only one procd-supervised Moonraker process started, using the stock configuration. The Moonraker API reported Klipper ready, zero failed components and zero warnings. HelixScreen started, and both Mainsail and Fluidd camera feeds worked.

This outcome was verified on **one specific printer/firmware build**. It does not prove that other K2 Plus firmware revisions share the same startup layout.

## Read-only inspection

Run from an SSH shell; these commands do not change the printer:

```sh
ls -l /etc/init.d/moonraker /etc/rc.d/S56moonraker
grep -n '^CONF=' /etc/init.d/moonraker /etc/rc.d/S56moonraker
grep -Fn '[include /mnt/UDISK/printer_data/config/moonraker.conf]' /usr/share/moonraker/moonraker.conf
ps | grep '[m]oonraker.py'
ubus call service list '{"name":"moonraker","verbose":true}'
curl -sS --max-time 5 http://127.0.0.1:7125/server/info
```

**Expected verified arrangement:** `/etc/rc.d/S56moonraker -> ../init.d/moonraker`; the canonical service uses the stock config, which includes the extension config.

## Recovery boundaries

- **Do not blindly kill all Moonraker processes.** Identify the procd-owned PID and preserve it.
- **Do not reboot or modify startup files during a print.** Confirm the printer is idle, and retain physical access.
- **Do not run the extension-only configuration as a second server.**
- **Do not remove the UDISK extension or camera scripts** merely to repair startup.
- Before changing startup entries, back up the original `/etc/init.d/moonraker`, `/etc/rc.d/S56moonraker`, and any `S56moonraker.orig` to a timestamped directory on UDISK. Confirm the stock config includes the extension and that the canonical service uses the stock config.
- Only after confirming this **exact known layout**, restore the standard symlink. Preserve the backup for rollback. Never overwrite a different firmware layout automatically.
- Validate the process count, procd ownership, API health, HelixScreen and both camera feeds **after a normal OS reboot**.
- On the verified firmware, `[machine] provider: none` means Mainsail's Host Control reboot action is unavailable. Do not change the provider as part of this repair; use the printer's supported normal OS reboot method instead.

## Helper Script development requirements

The installer, updater and uninstaller must not replace the canonical startup symlink, start an independent Moonraker server, kill processes indiscriminately, or remove third-party configuration. Any future automated repair needs a firmware-specific preflight, backups, explicit user confirmation, post-change checks and a rollback path. Until those exist, **fail closed**. Preserve the functioning camera pipeline and HelixScreen. Never treat this field recovery as a blanket authorization to alter a user's live printer.
