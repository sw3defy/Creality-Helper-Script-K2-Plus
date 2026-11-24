#!/bin/sh
# HelixScreen compatibility gate for Creality K2 Plus.
# A verified installation MUST reboot immediately after explicit confirmation.
# Neither fresh installation nor update/removal is currently validated.
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

check_helixscreen() {
    [ -f /etc/init.d/S99helixscreen ] || [ -f /etc/rc.d/S99helixscreen ]
}

install_helixscreen() {
    log_error "HelixScreen installation/update is blocked pending verified installer, backup and recovery."
    log_warn "Once enabled, installation must require explicit consent and immediate mandatory reboot."
    log_warn "First boot may take longer; do not hard-reset merely because startup is slow."
    log_warn "No files, services or touchscreen startup paths were changed."
    return 1
}

remove_helixscreen() {
    log_error "HelixScreen removal is blocked pending verified recovery to stock touchscreen."
    log_warn "No files, services or touchscreen startup paths were changed."
    return 1
}

case "$1" in
    install) install_helixscreen ;;
    remove) remove_helixscreen ;;
    *) echo "Usage: $0 [install|remove]"; exit 2 ;;
esac
