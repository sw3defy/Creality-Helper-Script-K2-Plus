#!/bin/sh
# z_offset.sh - Save Z-Offset Macros for K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
Z_CFG=$CONFIG_DIR/z_offset_macros.cfg

install_z_offset() {
    echo ""
    log_info "Installing Save Z-Offset Macros..."
    cat > "$Z_CFG" << 'EOF'
# Save Z-Offset Macros — K2 Plus (prtouch_v3 strain-gauge probe)

[gcode_macro SAVE_Z_OFFSET]
description: Save current live Z offset to printer.cfg
gcode:
  Z_OFFSET_APPLY_PROBE
  SAVE_CONFIG

[gcode_macro SET_Z_OFFSET]
description: Apply a Z offset value and save. Usage: SET_Z_OFFSET Z=0.05
gcode:
  {% set z = params.Z|default(0)|float %}
  SET_GCODE_OFFSET Z={z} MOVE=1
  {action_respond_info("Z offset set to %.3f — run SAVE_Z_OFFSET to persist" % z)}

[gcode_macro RESET_Z_OFFSET]
description: Reset Z offset to 0
gcode:
  SET_GCODE_OFFSET Z=0 MOVE=1
  {action_respond_info("Z offset reset to 0")}
EOF
    add_include_to_printer_cfg "z_offset_macros.cfg"
    restart_klipper
    mark_installed "z_offset_macros"
    echo ""
    log_success "Save Z-Offset Macros installed!"
    echo ""
}

remove_z_offset() {
    remove_include_from_printer_cfg "z_offset_macros.cfg"
    rm -f "$Z_CFG"
    restart_klipper
    mark_removed "z_offset_macros"
    log_success "Z-Offset Macros removed."
}

case "$1" in
    install) install_z_offset ;;
    remove)  remove_z_offset ;;
esac
