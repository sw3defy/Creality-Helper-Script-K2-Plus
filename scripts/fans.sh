#!/bin/sh
# fans.sh - Install/remove Fans Control Macros for K2 Plus

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

FANS_CFG=$CONFIG_DIR/fans_control.cfg

install_fans() {
    echo ""
    log_info "Installing Fans Control Macros..."
    echo ""

    cat > "$FANS_CFG" << 'EOF'
# Fans Control Macros — K2 Plus
# Managed by Creality Helper Script
# Part cooling: fan0 (nozzle_mcu:PB15, enable nozzle_mcu:PB6)
# Aux fan:      fan2 (PB4+PB3)
# Chamber fan:  chamber_fan (PA0, temperature_fan, watermark)
# Chamber heat: chamber_heater (PC12, heater_generic)

# ── Save / Restore fan state ──────────────────────────────────────────────────

[gcode_macro SAVE_FANS]
description: Save current fan speeds
variable_fan0_speed: 0
variable_fan2_speed: 0
gcode:
  SET_GCODE_VARIABLE MACRO=SAVE_FANS VARIABLE=fan0_speed VALUE={printer['output_pin fan0'].value}
  SET_GCODE_VARIABLE MACRO=SAVE_FANS VARIABLE=fan2_speed VALUE={printer['output_pin fan2'].value}

[gcode_macro RESTORE_FANS]
description: Restore previously saved fan speeds
gcode:
  {% set s = printer['gcode_macro SAVE_FANS'] %}
  SET_FAN0 S={( s.fan0_speed * 255 )|int}
  SET_FAN2 S={( s.fan2_speed * 255 )|int}

# ── Part cooling fan (fan0) ───────────────────────────────────────────────────

[gcode_macro SET_FAN0]
description: Set part cooling fan speed. S=0-255
gcode:
  {% set speed = params.S|default(0)|int %}
  {% set pwm = (speed / 255.0)|round(4) %}
  SET_PIN PIN=fan0_en VALUE={% if speed > 0 %}1{% else %}0{% endif %}
  SET_PIN PIN=fan0 VALUE={pwm}

# ── Aux fan (fan2) ────────────────────────────────────────────────────────────

[gcode_macro SET_FAN2]
description: Set aux fan speed. S=0-255
gcode:
  {% set speed = params.S|default(0)|int %}
  {% set pwm = (speed / 255.0)|round(4) %}
  SET_PIN PIN=fan2 VALUE={pwm}

# ── Turn off all output fans ──────────────────────────────────────────────────

[gcode_macro FANS_OFF]
description: Turn off all output fans (does not affect hotend_fan auto-control)
gcode:
  SET_FAN0 S=0
  SET_FAN2 S=0

# ── Chamber heater control ────────────────────────────────────────────────────

[gcode_macro CHAMBER_HEAT]
description: Set chamber heater target. Use WAIT=1 to wait for temp. TARGET=degrees
variable_chamber_target: 0
gcode:
  {% set target = params.TARGET|default(0)|float %}
  {% set wait = params.WAIT|default(0)|int %}
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={target}
  SET_GCODE_VARIABLE MACRO=CHAMBER_HEAT VARIABLE=chamber_target VALUE={target}
  {% if wait == 1 and target > 0 %}
    TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={target - 3}
    {action_respond_info("Chamber reached target temperature: %d°C" % target)}
  {% endif %}

[gcode_macro CHAMBER_COOL]
description: Disable chamber heater and run cooling fan at full speed
gcode:
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET=0
  SET_TEMPERATURE_FAN_TARGET TEMPERATURE_FAN=chamber_fan TARGET=20
  {action_respond_info("Chamber cooling: heater off, fan at full speed")}

# ── Convenience: chamber temperature status ───────────────────────────────────

[gcode_macro CHAMBER_STATUS]
description: Print current chamber temperature and target
gcode:
  {% set chamber_temp = printer['heater_generic chamber_heater'].temperature %}
  {% set chamber_target = printer['heater_generic chamber_heater'].target %}
  {action_respond_info("Chamber: %.1f°C / target: %.1f°C" % (chamber_temp, chamber_target))}
EOF

    add_include_to_printer_cfg "fans_control.cfg"
    restart_klipper

    mark_installed "fans_control_macros"
    echo ""
    log_success "Fans Control Macros installed!"
    echo ""
    log_info "Available macros: SET_FAN0, SET_FAN2, FANS_OFF, SAVE_FANS, RESTORE_FANS"
    log_info "Chamber macros:   CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS"
    echo ""
}

remove_fans() {
    echo ""
    log_info "Removing Fans Control Macros..."
    remove_include_from_printer_cfg "fans_control.cfg"
    rm -f "$FANS_CFG"
    restart_klipper
    mark_removed "fans_control_macros"
    log_success "Fans Control Macros removed."
    echo ""
}

case "$1" in
    install) install_fans ;;
    remove)  remove_fans ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
