# Moonraker live findings — 24 November 2026

Development only; option 1 remains blocked.

Live K2 Plus: canonical S56moonraker symlink, one procd-managed process using /usr/share/moonraker/moonraker.conf, Klipper ready, no failed components or warnings. Stock config includes UDISK config. Effective file_manager.enable_object_processing is false despite true in UDISK; exclude_object is loaded in Klipper. Update status endpoint returns 404. Bundled update_manager source exists, automatically registers upstream Moonraker and Klipper, and full update invokes both; disabling system updates and auto refresh does not remove those paths. Root filesystem is writable overlay. Git exists at /opt/bin/git; stock Moonraker has no .git.

Proposed design: keep native update_manager disabled unless enforceable core protection is demonstrated. Use helper-owned allowlisted add-on updates with validation and rollback. Resolve object processing precedence with a minimal reviewed configuration migration, not reverse includes or service replacement. No live configuration changes performed. This design does not yet implement a working update manager or installer.
