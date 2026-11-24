#!/bin/sh
# Verified adoption and activation entrypoint.
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
case "$1" in
install)
    PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/scripts/moonraker_install.py" || {
        log_error "Moonraker verification or activation failed. Inspect output before retrying."
        exit 1
    }
    mark_installed "moonraker_extensions" || exit 1
    is_installed "moonraker_extensions" || exit 1
    log_success "Moonraker Extensions verified and registered."
    ;;
remove)
    for dependency in kamp moonraker_timelapse; do
        if is_installed "$dependency"; then
            log_error "Remove $dependency first. Moonraker Extensions remain installed."
            exit 1
        fi
    done
    log_error "Removal blocked pending ownership-aware restoration validation."
    exit 1
    ;;
*) exit 2 ;;
esac
