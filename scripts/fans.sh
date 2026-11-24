#!/bin/sh
# K2 Plus fan control compatibility gate.
# Creality's gcode_macro.cfg owns M106/M107, including P, minimum-speed
# and Qmode logic. Do not bypass these macros with SET_PIN or replace them.
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

install_fans() {
    log_error "Fan-control installation is blocked until stock-compatible UI sliders and migration are verified."
    log_warn "Creality M106/M107, Qmode and CFS fan behavior are preserved."
    log_warn "No fan pins, macros, includes or services were changed."
    return 1
}

remove_fans() {
    log_error "Fan-control removal is blocked until ownership of older fans_control.cfg is verified."
    log_warn "Existing printer configuration and fan behavior are preserved."
    return 1
}

case "$1" in
    install) install_fans ;;
    remove) remove_fans ;;
    *) echo "Usage: $0 [install|remove]"; exit 2 ;;
esac
