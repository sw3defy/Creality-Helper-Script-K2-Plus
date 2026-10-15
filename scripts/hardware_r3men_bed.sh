#!/bin/sh
# hardware_r3men_bed.sh - Install/remove R3Men graphite bed configuration for K2 Plus

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
                                                                                                                                                                                                                            
PRINTER_CFG=$CONFIG_DIR/printer.cfg
BED_CFG=$CONFIG_DIR/r3men_bed.cfg

SENSOR_PIN='PC4'
SENSOR_TYPE='EPCOS 100K B57560G104F'
TARGET_TYPE='R3men_bed'

install_bed() {
    echo ""
    log_info "Installing R3Men bed configuration"
    echo ""

    cat > "$BED_CFG" << 'EOF'
[thermistor R3men_bed]
temperature1: 25
resistance1: 100000
temperature2: 97
resistance2: 1385
temperature3: 248
resistance3: 165
EOF

    add_include_to_printer_cfg "r3men_bed.cfg"

    echo sed -i -e ':a' -e 'N' -e '$!ba' -e "s/sensor_type: $SENSOR_TYPE\nsensor_pin: $SENSOR_PIN/sensor_type: $TARGET_TYPE\nsensor_pin: $SENSOR_PIN/" "$PRINTER_CFG"
    #restart_klipper

    mark_installed "hardware_r3men_bed"
    echo ""
    log_success "R3Men Bed Installed!"
    echo ""
}

remove_bed() {
    echo ""
    log_info "Removing R3Men bed configuration..."
    remove_include_from_printer_cfg "r3men_bed.cfg"
    rm -f "$FANS_CFG"
    sed -i -e ':a' -e 'N' -e '$!ba' -e "s/sensor_type: $TARGET_TYPE\nsensor_pin: $SENSOR_PIN/sensor_type: $SENSOR_TYPE\nsensor_pin: $SENSOR_PIN/" "$PRINTER_CFG"
    restart_klipper
    mark_removed "hardware_r3men_bed"
    log_success "R3Men Bed configuration removed."
    echo ""
}

case "$1" in
    install) install_bed ;;
    remove)  remove_bed ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
