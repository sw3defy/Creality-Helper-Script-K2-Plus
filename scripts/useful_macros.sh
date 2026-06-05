#!/bin/sh
# useful_macros.sh - Full useful macros suite for K2 Plus
# Includes all K1 macros adapted for K2 Plus hardware + K2 Plus-specific additions

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

MACROS_CFG=$CONFIG_DIR/useful_macros.cfg

install_useful_macros() {
    echo ""
    log_info "Installing Useful Macros..."
    echo ""

    cat > "$MACROS_CFG" << 'EOF'
# Useful Macros — K2 Plus
# Managed by Creality Helper Script
# https://github.com/sw3defy/Creality-Helper-Script-K2-Plus
#
# Included macros:
#   START_PRINT, END_PRINT, PAUSE, RESUME, CANCEL_PRINT
#   PID_BED, PID_HOTEND, PID_CHAMBER
#   BED_LEVELING, Z_TILT_CALIBRATE
#   WARMUP (movement stress test)
#   CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS
#   KLIPPER_BACKUP_CONFIG, KLIPPER_RESTORE_CONFIG
#   MOONRAKER_BACKUP_DATABASE, MOONRAKER_RESTORE_DATABASE
#   RELOAD_CAMERA
#   SET_PRINT_STATS_INFO

# ═════════════════════════════════════════════════════════════════════════════
# PRINT START / END
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro START_PRINT]
description: Start a print — called by slicer start G-code
gcode:
  {% set BED_TEMP      = params.BED_TEMP|default(60)|float %}
  {% set EXTRUDER_TEMP = params.EXTRUDER_TEMP|default(200)|float %}
  {% set CHAMBER_TEMP  = params.CHAMBER_TEMP|default(0)|float %}

  CLEAR_PAUSE
  M220 S100   ; reset speed override
  M221 S100   ; reset flow override
  G90         ; absolute positioning
  M83         ; extruder relative mode

  ; Start heating bed immediately (don't wait yet)
  M140 S{BED_TEMP}

  ; Start chamber heater if a target was provided
  {% if CHAMBER_TEMP > 0 %}
    SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={CHAMBER_TEMP}
  {% endif %}

  ; Home all axes
  G28

  ; Z-tilt adjustment — mandatory on K2 Plus (dual Z motors)
  Z_TILT_ADJUST

  ; Wait for bed temperature
  M190 S{BED_TEMP}

  ; Wait for chamber temperature if requested
  {% if CHAMBER_TEMP > 0 %}
    TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={CHAMBER_TEMP - 3}
  {% endif %}

  ; Pre-heat nozzle to 80% to minimise ooze during bed mesh
  M109 S{(EXTRUDER_TEMP * 0.8)|int}

  ; Adaptive or full bed mesh
  BED_MESH_CALIBRATE

  ; Full nozzle temperature
  M109 S{EXTRUDER_TEMP}

  ; Purge line (requires KAMP — skipped gracefully if not installed)
  {% if printer['gcode_macro LINE_PURGE'] is defined %}
    LINE_PURGE
  {% endif %}

  SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]

[gcode_macro END_PRINT]
description: End a print — called by slicer end G-code
gcode:
  {% set max_x = printer.toolhead.axis_maximum.x %}
  {% set max_y = printer.toolhead.axis_maximum.y %}

  ; Small retract
  G91
  G1 E-2 F3600
  G1 Z5 F600
  G90

  ; Turn off all heaters
  M104 S0
  M140 S0
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET=0

  ; Turn off fans
  M107
  {% if printer['gcode_macro FANS_OFF'] is defined %}
    FANS_OFF
  {% endif %}

  ; Park toolhead and present print
  G1 X{max_x / 2} Y{max_y - 10} F12000

  ; Disable steppers (keep Z to hold position)
  M84 X Y E

  {action_respond_info("Print complete!")}

# ═════════════════════════════════════════════════════════════════════════════
# PAUSE / RESUME / CANCEL
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro PAUSE]
description: Pause the print and park the toolhead
rename_existing: PAUSE_BASE
variable_park_x: 10
variable_park_y: 10
variable_park_z_lift: 10
variable_extrude: 1.0
gcode:
  {% set x      = params.X|default(printer['gcode_macro PAUSE'].park_x)|float %}
  {% set y      = params.Y|default(printer['gcode_macro PAUSE'].park_y)|float %}
  {% set z_lift = params.Z|default(printer['gcode_macro PAUSE'].park_z_lift)|float %}
  {% set e      = printer['gcode_macro PAUSE'].extrude|float %}

  SAVE_GCODE_STATE NAME=PAUSE_STATE
  PAUSE_BASE

  {% if printer.extruder.can_extrude %}
    G91
    G1 E-{e} F3600
    G90
  {% endif %}

  {% set z_pos    = printer.toolhead.position.z %}
  {% set z_target = [z_pos + z_lift, printer.toolhead.axis_maximum.z]|min %}
  G90
  G1 Z{z_target} F600
  G1 X{x} Y{y} F12000

[gcode_macro RESUME]
description: Resume the print
rename_existing: RESUME_BASE
variable_extrude: 1.0
gcode:
  {% set e = printer['gcode_macro RESUME'].extrude|float %}
  {% if printer.extruder.can_extrude %}
    G91
    G1 E{e} F3600
    G90
  {% endif %}
  RESTORE_GCODE_STATE NAME=PAUSE_STATE MOVE=1
  RESUME_BASE

[gcode_macro CANCEL_PRINT]
description: Cancel the current print
rename_existing: CANCEL_PRINT_BASE
gcode:
  CANCEL_PRINT_BASE
  END_PRINT

# ═════════════════════════════════════════════════════════════════════════════
# PID CALIBRATION
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro PID_HOTEND]
description: PID calibration for the hotend. Usage: PID_HOTEND TEMP=220
gcode:
  {% set temp = params.TEMP|default(220)|float %}
  {action_respond_info("Starting hotend PID calibration at %.0f°C..." % temp)}
  {action_respond_info("This will take several minutes. Do not interrupt.")}
  PID_CALIBRATE HEATER=extruder TARGET={temp}
  SAVE_CONFIG
  {action_respond_info("Hotend PID calibration complete. Config saved.")}

[gcode_macro PID_BED]
description: PID calibration for the heated bed. Usage: PID_BED TEMP=60
gcode:
  {% set temp = params.TEMP|default(60)|float %}
  {action_respond_info("Starting bed PID calibration at %.0f°C..." % temp)}
  {action_respond_info("This will take several minutes. Do not interrupt.")}
  PID_CALIBRATE HEATER=heater_bed TARGET={temp}
  SAVE_CONFIG
  {action_respond_info("Bed PID calibration complete. Config saved.")}

[gcode_macro PID_CHAMBER]
description: Tune the chamber heater watermark. Usage: PID_CHAMBER TEMP=45
gcode:
  {% set temp = params.TEMP|default(45)|float %}
  {action_respond_info("Heating chamber to %.0f°C for thermal soak observation..." % temp)}
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={temp}
  TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={temp - 2}
  {action_respond_info("Chamber reached %.0f°C. Note: chamber_heater uses watermark control, not PID." % temp)}
  {action_respond_info("Adjust max_delta in printer.cfg [verify_heater chamber_heater] if needed.")}

# ═════════════════════════════════════════════════════════════════════════════
# BED LEVELING
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro BED_LEVELING]
description: Full bed leveling sequence with Z-tilt and mesh. Usage: BED_LEVELING BED_TEMP=60 EXTRUDER_TEMP=150
gcode:
  {% set bed_temp      = params.BED_TEMP|default(60)|float %}
  {% set extruder_temp = params.EXTRUDER_TEMP|default(150)|float %}

  {action_respond_info("Starting bed leveling sequence...")}
  {action_respond_info("Bed: %.0f°C  Nozzle: %.0f°C" % (bed_temp, extruder_temp))}

  G28
  M140 S{bed_temp}
  M109 S{extruder_temp}
  M190 S{bed_temp}

  {action_respond_info("Running Z-tilt adjustment...")}
  Z_TILT_ADJUST

  {action_respond_info("Running full 9x9 bed mesh...")}
  BED_MESH_CALIBRATE PROFILE=default

  SAVE_CONFIG
  {action_respond_info("Bed leveling complete. Mesh saved as 'default'.")}

[gcode_macro Z_TILT_CALIBRATE]
description: Run Z-tilt adjustment only (no bed mesh). Home first if needed.
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}
  {action_respond_info("Running Z-tilt adjustment...")}
  Z_TILT_ADJUST
  {action_respond_info("Z-tilt complete.")}

# ═════════════════════════════════════════════════════════════════════════════
# WARMUP (movement stress test — adapted from K1 for CoreXY / K2 Plus)
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro WARMUP]
description: Movement warm-up to seat bearings and rods. Usage: WARMUP LOOPS=10 ACCEL=5000
variable_start_x: 5
variable_start_y: 5
variable_end_x: 345
variable_end_y: 345
gcode:
  {% set loops = params.LOOPS|default(10)|int %}
  {% set accel = params.ACCEL|default(5000)|int %}

  {action_respond_info("Starting warmup: %d loops at %d mm/s² acceleration" % (loops, accel))}
  {action_respond_info("This moves the toolhead across the full bed. Make sure it is clear.")}

  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}

  ; Save current acceleration
  {% set orig_accel = printer.toolhead.max_accel %}
  SET_VELOCITY_LIMIT ACCEL={accel}

  G90
  G1 F12000

  {% for i in range(loops) %}
    G1 X{printer['gcode_macro WARMUP'].start_x} Y{printer['gcode_macro WARMUP'].start_y}
    G1 X{printer['gcode_macro WARMUP'].end_x}   Y{printer['gcode_macro WARMUP'].start_y}
    G1 X{printer['gcode_macro WARMUP'].end_x}   Y{printer['gcode_macro WARMUP'].end_y}
    G1 X{printer['gcode_macro WARMUP'].start_x} Y{printer['gcode_macro WARMUP'].end_y}
    G1 X{printer['gcode_macro WARMUP'].start_x} Y{printer['gcode_macro WARMUP'].start_y}
    G1 X{printer['gcode_macro WARMUP'].end_x}   Y{printer['gcode_macro WARMUP'].end_y}
    G1 X{printer['gcode_macro WARMUP'].start_x} Y{printer['gcode_macro WARMUP'].end_y}
    G1 X{printer['gcode_macro WARMUP'].end_x}   Y{printer['gcode_macro WARMUP'].start_y}
  {% endfor %}

  ; Restore original acceleration
  SET_VELOCITY_LIMIT ACCEL={orig_accel}

  G1 X{(printer['gcode_macro WARMUP'].end_x / 2)|int} Y{(printer['gcode_macro WARMUP'].end_y / 2)|int}
  {action_respond_info("Warmup complete. %d loops done." % loops)}

# ═════════════════════════════════════════════════════════════════════════════
# CHAMBER CONTROL
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro CHAMBER_HEAT]
description: Set chamber heater target. Use WAIT=1 to wait for temp. Usage: CHAMBER_HEAT TARGET=45 WAIT=1
gcode:
  {% set target = params.TARGET|default(0)|float %}
  {% set wait   = params.WAIT|default(0)|int %}
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET={target}
  {% if wait == 1 and target > 0 %}
    {action_respond_info("Waiting for chamber to reach %.0f°C..." % target)}
    TEMPERATURE_WAIT SENSOR="heater_generic chamber_heater" MINIMUM={target - 3}
    {action_respond_info("Chamber reached target: %.0f°C" % target)}
  {% endif %}

[gcode_macro CHAMBER_COOL]
description: Disable chamber heater and run cooling fan at full speed
gcode:
  SET_HEATER_TEMPERATURE HEATER=chamber_heater TARGET=0
  SET_TEMPERATURE_FAN_TARGET TEMPERATURE_FAN=chamber_fan TARGET=20
  {action_respond_info("Chamber cooling: heater off, cooling fan running.")}

[gcode_macro CHAMBER_STATUS]
description: Print current chamber temperature and target
gcode:
  {% set temp   = printer['heater_generic chamber_heater'].temperature %}
  {% set target = printer['heater_generic chamber_heater'].target %}
  {action_respond_info("Chamber: %.1f°C  /  target: %.1f°C" % (temp, target))}

# ═════════════════════════════════════════════════════════════════════════════
# BACKUP & RESTORE (from Fluidd/Mainsail console)
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro KLIPPER_BACKUP_CONFIG]
description: Back up Klipper config files to backup_config.tar.gz in config folder
gcode:
  {action_respond_info("Backing up Klipper configuration...")}
  RUN_SHELL_COMMAND CMD=klipper_backup_config
  {action_respond_info("Backup saved as backup_config.tar.gz in your config folder.")}

[gcode_macro KLIPPER_RESTORE_CONFIG]
description: Restore Klipper config from backup_config.tar.gz — CAUTION: overwrites current config
gcode:
  {action_respond_info("Restoring Klipper configuration from backup_config.tar.gz...")}
  RUN_SHELL_COMMAND CMD=klipper_restore_config
  {action_respond_info("Config restored. Restarting Klipper...")}
  FIRMWARE_RESTART

[gcode_macro MOONRAKER_BACKUP_DATABASE]
description: Back up Moonraker database to backup_database.tar.gz in config folder
gcode:
  {action_respond_info("Backing up Moonraker database...")}
  RUN_SHELL_COMMAND CMD=moonraker_backup_database
  {action_respond_info("Moonraker database backup complete.")}

[gcode_macro MOONRAKER_RESTORE_DATABASE]
description: Restore Moonraker database from backup_database.tar.gz
gcode:
  {action_respond_info("Restoring Moonraker database...")}
  RUN_SHELL_COMMAND CMD=moonraker_restore_database
  {action_respond_info("Database restored.")}

# ═════════════════════════════════════════════════════════════════════════════
# CAMERA
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro RELOAD_CAMERA]
description: Restart the WebRTC camera service without rebooting
gcode:
  {action_respond_info("Restarting camera service...")}
  RUN_SHELL_COMMAND CMD=restart_camera
  {action_respond_info("Camera service restarted.")}

# ═════════════════════════════════════════════════════════════════════════════
# SLICER INTEGRATION HELPERS
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro SET_PRINT_STATS_INFO]
rename_existing: SET_PRINT_STATS_INFO_BASE
description: Update print stats with layer info from slicer
gcode:
  {% if params.TOTAL_LAYER is defined %}
    SET_PRINT_STATS_INFO_BASE TOTAL_LAYER={params.TOTAL_LAYER}
  {% endif %}
  {% if params.CURRENT_LAYER is defined %}
    SET_PRINT_STATS_INFO_BASE CURRENT_LAYER={params.CURRENT_LAYER}
  {% endif %}

# ═════════════════════════════════════════════════════════════════════════════
# Z-OFFSET
# ═════════════════════════════════════════════════════════════════════════════

[gcode_macro SAVE_Z_OFFSET]
description: Save current live Z offset to printer.cfg
gcode:
  Z_OFFSET_APPLY_PROBE
  SAVE_CONFIG

[gcode_macro SET_Z_OFFSET]
description: Apply a Z offset value and optionally save. Usage: SET_Z_OFFSET Z=0.05 SAVE=1
gcode:
  {% set z    = params.Z|default(0)|float %}
  {% set save = params.SAVE|default(0)|int %}
  SET_GCODE_OFFSET Z={z} MOVE=1
  {action_respond_info("Z offset set to %.3fmm" % z)}
  {% if save == 1 %}
    SAVE_Z_OFFSET
  {% endif %}

EOF

    # Add gcode_shell_command entries (requires Klipper Gcode Shell Command)
    cat >> "$MACROS_CFG" << 'EOF'
# ─── Shell commands (used by backup/restore/camera macros) ───────────────────
# These require the Klipper Gcode Shell Command feature.
# If not installed, the backup/restore/camera macros will not work.

[gcode_shell_command restart_camera]
command: /etc/rc.d/S97webrtc restart
timeout: 10.0
verbose: False

[gcode_shell_command klipper_backup_config]
command: tar -czf /mnt/UDISK/printer_data/config/backup_config.tar.gz -C /mnt/UDISK/printer_data config/
timeout: 30.0
verbose: True

[gcode_shell_command klipper_restore_config]
command: tar -xzf /mnt/UDISK/printer_data/config/backup_config.tar.gz -C /mnt/UDISK/printer_data/
timeout: 30.0
verbose: True

[gcode_shell_command moonraker_backup_database]
command: tar -czf /mnt/UDISK/printer_data/config/backup_database.tar.gz -C /mnt/UDISK/printer_data database/
timeout: 30.0
verbose: True

[gcode_shell_command moonraker_restore_database]
command: tar -xzf /mnt/UDISK/printer_data/config/backup_database.tar.gz -C /mnt/UDISK/printer_data/
timeout: 30.0
verbose: True
EOF

    add_include_to_printer_cfg "useful_macros.cfg"
    restart_klipper

    mark_installed "useful_macros"
    echo ""
    log_success "Useful Macros installed!"
    echo ""
    echo "  Available macros:"
    echo -e "  ${GREEN}Print:${NC}        START_PRINT, END_PRINT, PAUSE, RESUME, CANCEL_PRINT"
    echo -e "  ${GREEN}PID:${NC}          PID_HOTEND, PID_BED, PID_CHAMBER"
    echo -e "  ${GREEN}Leveling:${NC}     BED_LEVELING, Z_TILT_CALIBRATE"
    echo -e "  ${GREEN}Warmup:${NC}       WARMUP [LOOPS=10] [ACCEL=5000]"
    echo -e "  ${GREEN}Chamber:${NC}      CHAMBER_HEAT, CHAMBER_COOL, CHAMBER_STATUS"
    echo -e "  ${GREEN}Z-Offset:${NC}     SAVE_Z_OFFSET, SET_Z_OFFSET"
    echo -e "  ${GREEN}Backup:${NC}       KLIPPER_BACKUP_CONFIG, KLIPPER_RESTORE_CONFIG"
    echo "                MOONRAKER_BACKUP_DATABASE, MOONRAKER_RESTORE_DATABASE"
    echo -e "  ${GREEN}Camera:${NC}       RELOAD_CAMERA"
    echo ""
    log_info "Slicer start G-code:"
    echo "  START_PRINT BED_TEMP=[bed_temperature_initial_layer_single] EXTRUDER_TEMP=[nozzle_temperature_initial_layer] CHAMBER_TEMP=[chamber_temperature]"
    log_info "Slicer end G-code:"
    echo "  END_PRINT"
    echo ""
}

remove_useful_macros() {
    echo ""
    log_info "Removing Useful Macros..."
    remove_include_from_printer_cfg "useful_macros.cfg"
    rm -f "$MACROS_CFG"
    restart_klipper
    mark_removed "useful_macros"
    log_success "Useful Macros removed."
    echo ""
}

case "$1" in
    install) install_useful_macros ;;
    remove)  remove_useful_macros ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
