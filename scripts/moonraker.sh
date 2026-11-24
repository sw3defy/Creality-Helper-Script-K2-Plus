#!/bin/sh
# Moonraker integration for Creality K2 Plus.
# Safe-by-default: no stock service edits, no reverse includes, no restarts.
# Firmware-specific installation and removal require a reviewed migration.
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

install_moonraker_extensions() {
    log_error "Moonraker extension installation is blocked pending a reviewed migration."
    log_warn "Preserving existing /mnt/UDISK/printer_data/config/moonraker.conf."
    log_warn "No service scripts, include directives, or runtime processes were changed."
    return 1
}

remove_moonraker_extensions() {
    log_error "Moonraker extension removal is blocked pending configuration ownership verification."
    log_warn "Existing Moonraker, Timelapse, and Update Manager configuration is preserved."
    return 1
}

case "$1" in
    install) install_moonraker_extensions ;;
    remove) remove_moonraker_extensions ;;
    *) echo "Usage: $0 [install|remove]"; exit 2 ;;
esac
