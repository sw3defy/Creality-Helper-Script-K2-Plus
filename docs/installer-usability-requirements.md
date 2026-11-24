# Beginner-safe Helper Script installation

Agreed design requirement, 24 November 2026. Implementation and hardware acceptance pending.

- Order menu by verified prerequisites, not historical installer numbering. Moonraker foundation is the first investigation and acceptance target. Distinguish mandatory dependencies from optional integrations and recommended order.
- Before any install/update/repair, check actual prerequisite files, services, API capabilities and compatible versions as applicable. An `.installed` marker alone is not proof. If missing or unhealthy, explain in plain English which menu option to use first; return without modifying the printer. Never silently install dependencies or bypass safety gates.
- Show installed, not installed, update available, repair needed, unknown and blocked states based on evidence. Do not imply an update is available without a successful version comparison.
- Explain purpose, dependencies, effects, restart/reboot requirements and expected startup delay before confirmation. HelixScreen requires a controlled reboot immediately after a successful installation; no forced power cycle.
- Preserve stock firmware behavior, CFS, camera, calibration and local configuration. Backup and verify before mutation, verify outcomes before marking installed, provide rollback guidance, and report failures clearly.
- Test fresh rooted and existing installations, missing/unhealthy dependencies, interrupted updates, rollback, and repeated installation. Keep unresolved installers blocked until their individual implementation and hardware tests pass.
- Synchronize menu numbering, prerequisites and verified results with the public Wiki and website. Do not advertise proposed behavior as already implemented.
