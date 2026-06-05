#!/bin/sh
# m600.sh - M600 filament change support for K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
M600_CFG=$CONFIG_DIR/m600.cfg

install_m600() {
    echo ""
    log_info "Installing M600 Support..."
    cat > "$M600_CFG" << 'EOF'
# M600 Filament Change — K2 Plus
# In CFS/multi-material mode, tool changes are handled by BOX_* macros.
# This M600 is for single-filament manual filament changes.

[gcode_macro M600]
description: Filament change — pause, retract, wait for manual swap
variable_park_x: 10
variable_park_y: 10
variable_retract: 5
gcode:
  {% set x = printer['gcode_macro M600'].park_x %}
  {% set y = printer['gcode_macro M600'].park_y %}
  {% set e = printer['gcode_macro M600'].retract %}

  SAVE_GCODE_STATE NAME=M600_STATE

  ; Retract
  {% if printer.extruder.can_extrude %}
    G91
    G1 E-{e} F3600
    G90
  {% endif %}

  ; Park
  {% set z_pos = printer.toolhead.position.z %}
  {% set z_target = [z_pos + 10, printer.toolhead.axis_maximum.z]|min %}
  G90
  G1 Z{z_target} F600
  G1 X{x} Y{y} F12000

  ; Pause heater slightly to avoid ooze, keep it warm
  {% set temp = printer.extruder.target %}
  M104 S{[temp - 20, 160]|max}

  PAUSE_BASE

  {action_respond_info("M600: Filament change paused. Swap filament then RESUME.")}

[gcode_macro FILAMENT_LOAD]
description: Load filament — heat and extrude
gcode:
  {% set temp = params.TEMP|default(200)|float %}
  M109 S{temp}
  G91
  G1 E80 F300
  G1 E30 F150
  G90
  {action_respond_info("Filament loaded.")}

[gcode_macro FILAMENT_UNLOAD]
description: Unload filament — heat, retract, pull
gcode:
  {% set temp = params.TEMP|default(200)|float %}
  M109 S{temp}
  G91
  G1 E5 F300
  G1 E-80 F1800
  G90
  {action_respond_info("Filament unloaded.")}
EOF
    add_include_to_printer_cfg "m600.cfg"
    restart_klipper
    mark_installed "m600_support"
    echo ""
    log_success "M600 Support installed!"
    log_info "Set slicer change filament G-code to: M600"
    echo ""
}

remove_m600() {
    remove_include_from_printer_cfg "m600.cfg"
    rm -f "$M600_CFG"
    restart_klipper
    mark_removed "m600_support"
    log_success "M600 Support removed."
}

case "$1" in
    install) install_m600 ;;
    remove)  remove_m600 ;;
esac
