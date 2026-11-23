# Stock Creality behavior preservation policy

**Non-negotiable release gate:** The Helper Script is additive. It must not replace, disable, or silently change stock Creality K2 Plus behavior, especially CFS filament loading, feeding, switching, runout detection, or the stock print sequence.

## Required implementation constraints

1. Preserve Creality-provided firmware, Klipper binaries and stock services. Do not replace bundled Klipper/Moonraker or alter their startup ownership without a separately validated compatibility and rollback procedure.
2. Prefer isolated add-on config and non-conflicting macro names. Never overwrite stock macros or CFS/filament sensor definitions.
3. No blind `sed` patches to stock configs, service scripts, or `rc.local`. Every permitted migration must verify the exact precondition, back up affected files, be idempotent, and support rollback.
4. Installation/removal must fail closed where preservation cannot be demonstrated. Existing unsafe operations remain disabled.
5. HelixScreen integration requires review of all installer mutations and dependencies, not just the UI binary. Reboot after installation must be a mandatory, explicitly confirmed normal reboot only after the install path is validated.
6. Validate service health **and actual printing**. A Klipper `ready` state, Moonraker connectivity, and camera feed do not prove that printing works.
7. CFS regression acceptance: stock print workflow and repeat Benchy with CFS after updates, watching for delayed under-extrusion. If print fails, do not declare compatibility.

## Current evidence and limits

Operator reports CFS worked flawlessly with stock Creality printing, whereas three Benchy prints later started and developed under-extrusion after add-on installation. This raises a plausible software/config regression hypothesis, **not proof HelixScreen caused it**. Compare installation changes, print macros, firmware integration and filament sensor behavior before modifying the printer.

This policy governs development branch only; it authorizes no deployment or live printer changes.
