# K2 Plus Helper Script lifecycle audit — 2026-11-24

**Scope:** development branch only. No installation or service modification on a live printer. This is a source-level review, not firmware qualification.

## Verified field baseline

On the inspected K2 Plus, the canonical OpenWrt procd service loaded `/usr/share/moonraker/moonraker.conf`, which includes the UDISK extension configuration. Restoring `/etc/rc.d/S56moonraker -> ../init.d/moonraker` and rebooting yielded exactly one procd-owned Moonraker process. Moonraker reported Klipper ready, zero failed components and zero warnings; HelixScreen and both camera dashboards worked. See [recovery procedure](moonraker-duplicate-process-recovery.md).

## Source-level lifecycle matrix

| Feature | Install/update | Remove/rollback | Release gate |
| --- | --- | --- | --- |
| Moonraker extensions | Blocked | Blocked | Ownership-aware migration, preserve stock service/include |
| Moonraker restart | Blocked | N/A | Firmware-specific supervised restart and rollback |
| Timelapse | Blocked | Blocked | Preserve existing component, macros, camera integration |
| KAMP | Blocked | Blocked | Merge configs without duplicate sections; verify Creality macros |
| Fans, useful macros, M600, Z-offset, shapers | Blocked | Blocked | Check stock command/macro collisions, motion safety and CFS |
| HelixScreen | Blocked | Blocked | Review installer and mandatory reboot with explicit consent |
| Entware | Blocked | Blocked | Trusted bootstrap, /opt ownership and rollback |
| Fluidd web assets | Staged updater available | Blocked | Test asset rollback and nginx/camera preservation |
| Mainsail web assets | Staged updater available | Blocked | Test asset rollback and nginx/camera preservation |
| Camera bridge | Existing working installer retained | **Blocked** | Reversible, ownership-aware nginx/rc.local/webcam removal |
| Config backup | Available | Bulk restore blocked | Archive validation and safe restoration |
| Firmware inspector, Moonraker audit, update check | Read-only | N/A | Ensure no side effects |
| OctoEverywhere, Mobileraker, Git Backup | Not implemented | Not implemented | Do not advertise as installed |

### Findings addressed in this branch

1. Moonraker startup modifications and indiscriminate restart remain blocked. Read-only audit now shows symlink target, process inventory and procd registration.
2. Recovery documentation records the exact verified startup topology and operational checks.
3. Camera removal was previously destructive: broad regex edits to nginx and dashboard HTML could remove unrelated configuration. It now returns failure without changing files.
4. Fluidd removal previously cleared an installed marker and reported stock restoration without actually restoring the web assets or nginx configuration. It now returns failure without changing files.
5. Regression checks enforce these fail-closed protections. GitHub Actions is a **static/offline** gate; it cannot establish hardware compatibility.

### Open risks / intentionally deferred

- The working camera **installer** edits nginx, rc.local and web UI assets and requests reboot. It was deliberately preserved rather than rewritten without a hardware-backed rollback test. It must be separately reviewed before a general release.
- The staged web UI updater needs integration tests on firmware-matched snapshots, including preservation of the camera customization.
- Legacy unreachable implementation blocks remain in some scripts after fail-closed guards. They are not executed by normal menu paths, but should be removed only after archival and regression review.
- Existing installations may still have legacy startup files. The script should **diagnose**, not silently repair, those installations.
- A real K2 Plus validation pass is required before enabling any blocked installation, removal, reboot or service-management operation.

## Release decision

**Do not merge or deploy this branch as a full-featured release.** The current changes are safety hardening and diagnostics, not an assertion that blocked features are ready. A future release requires per-feature firmware compatibility, reversible migration and explicit user approval for printer-side changes.
