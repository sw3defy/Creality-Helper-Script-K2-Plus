#!/bin/sh
# dxc2.sh - Make configuration changes for DXC2 extruder.

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

MACRO_CFG=$CONFIG_DIR/gcode_macro.cfg
ORIGINAL_MACRO="G0 E-10 F360"
TARGET_MACRO="G0 E-40 F360"

BOX_CFG=$CONFIG_DIR/box.cfg
ORIGINAL_BOX="Tn_retrude: -10"
TARGET_BOX="Tn_retrude: -20"

function install_dxc2 {
    echo ""
    log_info "Installing DXC2 configuration"
    echo ""
    sed -i "s/$ORIGINAL_MACRO/$TARGET_MACRO/" $MACRO_CFG
    sed -i "s/$ORIGINAL_BOX/$TARGET_BOX/" $BOX_CFG
    mark_installed "hardware_dxc2"

    echo ""
    log_success "DXC2 configuration installed"
    echo ""
}


function uninstall_dxc2 {
    echo ""
    log_info "Uninstalling DXC2 configuration"
    echo ""

    sed -i "s/$TARGET_MACRO/$ORIGINAL_MACRO/" $MACRO_CFG
    sed -i "s/$TARGET_BOX/$ORIGINAL_BOX/" $BOX_CFG
    mark_removed "hardware_dxc2"

    echo ""
    log_success "DXC2 configuration uninstalled"
    echo ""
}


case "$1" in
    install) install_dxc2 ;;
    remove)  uninstall_dxc2 ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
