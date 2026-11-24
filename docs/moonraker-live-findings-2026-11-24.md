# Moonraker live findings — 24 November 2026

Development only; option 1 remains blocked.

Live K2 Plus: canonical S56moonraker symlink, one procd-managed process using /usr/share/moonraker/moonraker.conf, Klipper ready, no failed components or warnings. Stock config includes UDISK config. Effective file_manager.enable_object_processing is false despite true in UDISK; exclude_object is loaded in Klipper. Update status endpoint returns 404. Bundled update_manager source exists, automatically registers upstream Moonraker and Klipper, and full update invokes both; disabling system updates and auto refresh does not remove those paths. Root filesystem is writable overlay. Git exists at /opt/bin/git; stock Moonraker has no .git.

Proposed design: keep native update_manager disabled unless enforceable core protection is demonstrated. Use helper-owned allowlisted add-on updates with validation and rollback. Resolve object processing precedence with a minimal reviewed configuration migration, not reverse includes or service replacement. No live configuration changes performed. This design does not yet implement a working update manager or installer.

## K2-MR-007 — live activation passed

A timestamped backup and candidate were prepared; diff confirmed exactly one change, enable_object_processing False to True in the active overlay configuration. Canonical /etc/init.d/moonraker restart succeeded. API confirmed Klipper ready, no failed components or warnings, native update_manager absent, effective object processing true. Exit status 0. Original backup retained. Rollback code was present but not exercised. No ROM, startup script or Klipper macro changes. Installer integration and functional upload test remain pending.

All subsequent PuTTY test blocks should have unique component-specific test IDs and explicit START and END markers.

## K2-MR-008 through K2-MR-017

008: 13/13 health checks passed; single canonical Moonraker process, CFS objects present, exact one-line config diff. 009: upload and cleanup passed, synthetic header did not trigger processing. 010–013: corrected PrusaSlicer header exposed legacy DEFINE_OBJECT, START_CURRENT_OBJECT and END_CURRENT_OBJECT generation in preprocess_cancellation.py, incompatible with registered EXCLUDE_OBJECT commands. 014: isolated four-token replacement passed with polygon generation. 015: backup and candidate verified. 016: installed candidate verified, no restart required. 017: actual Moonraker upload generated all three supported commands, no legacy commands, no print started or queued, printer standby, cleanup and health passed.

Module path: /usr/share/moonraker-env/lib/python3.9/site-packages/preprocess_cancellation.py
Original SHA256: 7b6234ad164043d443aae64cfef911ed8dcdbaceab6331ac1417fc0d3d5c6f61
Corrected SHA256: ef07606aafc7d2188cda29a207d4950cd582fa56679c6eec666e616450dab4e4
Backup: /mnt/UDISK/helper-backups/preprocess_cancellation.py.20261124-225928

Limitations: one firmware environment and synthetic PrusaSlicer input tested; actual print, other slicers, rollback, reboot persistence and installer integration pending. Previously processed files are unchanged. Native update manager remains disabled. No evidence linking mismatch to nozzle clogs.
