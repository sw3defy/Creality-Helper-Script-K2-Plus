#!/bin/sh
# useful_macros.sh - Useful macros suite for K2 Plus
# NOTE: Does NOT install START_PRINT, END_PRINT, PAUSE, RESUME, CANCEL_PRINT
# Those are already defined in stock gcode_macro.cfg with full CFS integration

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

MACROS_CFG=$CONFIG_DIR/useful_macros.cfg

install_useful_macros() {

    if is_installed "useful_macros"; then
        log_info "Useful Macros is already installed."
        echo ""
        printf "  Reinstall? [y/n]: "
        read confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return 0
    fi
    echo ""
    log_info "Installing Useful Macros..."
    echo ""

    cat > "$MACROS_CFG" << CFGEOF
# Useful Macros - K2 Plus
# Managed by Creality Helper Script
# https://github.com/sw3defy/Creality-Helper-Script-K2-Plus
#
# NOTE: START_PRINT, END_PRINT, PAUSE, RESUME, CANCEL_PRINT are NOT included
# here. They are already defined in stock gcode_macro.cfg with full CFS
# integration. Overwriting them breaks filament loading and unloading.
#
# Included macros:
#   PID_BED, PID_HOTEND, PID_CHAMBER
#   BED_LEVELING, Z_TILT_CALIBRATE
#   WARMUP (movement stress test)
#   CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS

# =============================================================================
# PID CALIBRATION
# =============================================================================

[gcode_macro PID_HOTEND]
description: PID calibration for the hotend. Usage: PID_HOTEND TEMP=220
gcode:
  {% set temp = params.TEMP|default(220)|float %}
  {action_respond_info("Starting hotend PID calibration at %.0f C..." % temp)}
  {action_respond_info("This will take several minutes. Do not interrupt.")}
  PID_CALIBRATE HEATER=extruder TARGET={temp}
  SAVE_CONFIG
  {action_respond_info("Hotend PID calibration complete. Config saved.")}

[gcode_macro PID_BED]
description: PID calibration for the heated bed. Usage: PID_BED TEMP=60
gcode:
  {% set temp = params.TEMP|default(60)|float %}
  {action_respond_info("Starting bed PID calibration at %.0f C..." % temp)}
  {action_respond_info("This will take several minutes. Do not interrupt.")}
  PID_CALIBRATE HEATER=heater_bed TARGET={temp}
  SAVE_CONFIG
  {action_respond_info("Bed PID calibration complete. Config saved.")}

[gcode_macro PID_CHAMBER]
description: Tune the chamber heater. Usage: PID_CHAMBER TEMP=45
gcode:
  {% set temp = params.TEMP|default(45)|float %}
  {action_respond_info("Heating chamber to %.0f C..." % temp)}
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={temp}
  TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={temp - 2}
  {action_respond_info("Chamber reached %.0f C." % temp)}

# =============================================================================
# BED LEVELING
# =============================================================================

[gcode_macro BED_LEVELING]
description: Full bed leveling sequence. Usage: BED_LEVELING BED_TEMP=60 EXTRUDER_TEMP=150
gcode:
  {% set bed_temp      = params.BED_TEMP|default(60)|float %}
  {% set extruder_temp = params.EXTRUDER_TEMP|default(150)|float %}
  {action_respond_info("Starting bed leveling sequence...")}
  G28
  M140 S{bed_temp}
  M109 S{extruder_temp}
  M190 S{bed_temp}
  Z_TILT_ADJUST
  BED_MESH_CALIBRATE PROFILE=default
  SAVE_CONFIG
  {action_respond_info("Bed leveling complete. Mesh saved as default.")}

[gcode_macro Z_TILT_CALIBRATE]
description: Run Z-tilt adjustment only. Home first if needed.
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}
  {action_respond_info("Running Z-tilt adjustment...")}
  Z_TILT_ADJUST
  {action_respond_info("Z-tilt complete.")}

# =============================================================================
# WARMUP
# =============================================================================

[gcode_macro WARMUP]
description: Movement warm-up. Usage: WARMUP LOOPS=10 ACCEL=5000
variable_start_x: 5
variable_start_y: 5
variable_end_x: 345
variable_end_y: 345
gcode:
  {% set loops = params.LOOPS|default(10)|int %}
  {% set accel = params.ACCEL|default(5000)|int %}
  {action_respond_info("Starting warmup: %d loops" % loops)}
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}
  {% set orig_accel = printer.toolhead.max_accel %}
  SET_VELOCITY_LIMIT ACCEL={accel}
  G90
  G1 F12000
  {% for i in range(loops) %}
    G1 X{printer["gcode_macro WARMUP"].start_x} Y{printer["gcode_macro WARMUP"].start_y}
    G1 X{printer["gcode_macro WARMUP"].end_x}   Y{printer["gcode_macro WARMUP"].start_y}
    G1 X{printer["gcode_macro WARMUP"].end_x}   Y{printer["gcode_macro WARMUP"].end_y}
    G1 X{printer["gcode_macro WARMUP"].start_x} Y{printer["gcode_macro WARMUP"].end_y}
    G1 X{printer["gcode_macro WARMUP"].start_x} Y{printer["gcode_macro WARMUP"].start_y}
    G1 X{printer["gcode_macro WARMUP"].end_x}   Y{printer["gcode_macro WARMUP"].end_y}
    G1 X{printer["gcode_macro WARMUP"].start_x} Y{printer["gcode_macro WARMUP"].end_y}
    G1 X{printer["gcode_macro WARMUP"].end_x}   Y{printer["gcode_macro WARMUP"].start_y}
  {% endfor %}
  SET_VELOCITY_LIMIT ACCEL={orig_accel}
  {action_respond_info("Warmup complete. %d loops done." % loops)}

# =============================================================================
# CHAMBER CONTROL
# =============================================================================

[gcode_macro CHAMBER_HEAT]
description: Set chamber heater target. Usage: CHAMBER_HEAT TARGET=45 WAIT=1
gcode:
  {% set target = params.TARGET|default(0)|float %}
  {% set wait   = params.WAIT|default(0)|int %}
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={target}
  {% if wait == 1 and target > 0 %}
    {action_respond_info("Waiting for chamber to reach %.0f C..." % target)}
    TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={target - 3}
    {action_respond_info("Chamber reached target: %.0f C" % target)}
  {% endif %}

[gcode_macro CHAMBER_COOL]
description: Disable chamber heater and run cooling fan
gcode:
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET=0
  SET_TEMPERATURE_FAN_TARGET TEMPERATURE_FAN=chamber_fan TARGET=20
  {action_respond_info("Chamber cooling: heater off, cooling fan running.")}

[gcode_macro CHAMBER_STATUS]
description: Print current chamber temperature and target
gcode:
  {% set temp   = printer["heater_generic chamber_heater"].temperature %}
  {% set target = printer["heater_generic chamber_heater"].target %}
  {action_respond_info("Chamber: %.1f C  /  target: %.1f C" % (temp, target))}

CFGEOF

    add_include_to_printer_cfg "useful_macros.cfg"
    restart_klipper force

    mark_installed "useful_macros"
    echo ""
    log_success "Useful Macros installed!"
    echo ""
    echo "  Available macros:"
    echo "  PID:      PID_HOTEND, PID_BED, PID_CHAMBER"
    echo "  Leveling: BED_LEVELING, Z_TILT_CALIBRATE"
    echo "  Warmup:   WARMUP [LOOPS=10] [ACCEL=5000]"
    echo "  Chamber:  CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS"
    echo ""
}

remove_useful_macros() {
    if ! is_installed "useful_macros"; then
        log_info "Useful Macros is not installed."
        return 0
    fi

    echo "WARNING: This will remove Useful Macros."
    printf "Are you sure? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    echo ""
    log_info "Removing Useful Macros..."
    remove_include_from_printer_cfg "useful_macros.cfg"
    rm -f "$MACROS_CFG"
    restart_klipper force
    mark_removed "useful_macros"
    log_success "Useful Macros removed."
    echo ""
}

case "$1" in
    install) install_useful_macros ;;
    remove)  remove_useful_macros ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
