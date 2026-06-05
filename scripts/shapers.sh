#!/bin/sh
# shapers.sh - Improved Shapers Calibrations for K2 Plus (LIS2DW accelerometer)
# Includes all K1 Max shaper macros adapted for K2 Plus hardware
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
SHAPERS_CFG=$CONFIG_DIR/shapers_calibration.cfg

install_shapers() {
    echo ""
    log_info "Installing Improved Shapers Calibrations..."
    echo ""

    cat > "$SHAPERS_CFG" << 'EOF'
# Improved Shapers Calibrations — K2 Plus
# Managed by Creality Helper Script
#
# Hardware: LIS2DW accelerometer on nozzle_mcu via SPI
#   CS: nozzle_mcu:PA4 | SCLK: nozzle_mcu:PA5
#   MOSI: nozzle_mcu:PA7 | MISO: nozzle_mcu:PA6
#   Axes map: x,z,y | Probe point: 175,175,175
#
# Macros included:
#   INPUT_SHAPER_CALIBRATION  - full X+Y calibration (recommended)
#   SHAPER_CALIBRATE_X        - X axis only
#   SHAPER_CALIBRATE_Y        - Y axis only
#   BELTS_SHAPER_CALIBRATION  - belt tension analysis via frequency profile
#   EXCITATE_AXIS_AT_FREQ     - hold excitation at a specific frequency for diagnosis
#   AUTOTUNE_SHAPERS          - apply and save recommended shaper settings
#   TEST_RESONANCES_GRAPHS    - generate CSV data for external analysis
#   RESTORE_SHAPERS           - restore previously saved shaper settings

# ── Full calibration (recommended workflow) ───────────────────────────────────

[gcode_macro INPUT_SHAPER_CALIBRATION]
description: Run full X and Y resonance test and save recommended shaper settings
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    {action_respond_info("Homing printer first...")}
    G28
  {% endif %}

  {action_respond_info("Starting input shaper calibration for X and Y axes...")}
  {action_respond_info("This will take several minutes. Keep the printer still.")}

  SHAPER_CALIBRATE

  {action_respond_info("Calibration complete. Run SAVE_CONFIG to apply the results.")}
  {action_respond_info("Or run AUTOTUNE_SHAPERS to apply and save automatically.")}

# ── Per-axis calibration ──────────────────────────────────────────────────────

[gcode_macro SHAPER_CALIBRATE_X]
description: Run resonance test on X axis only
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}
  {action_respond_info("Testing X axis resonances...")}
  SHAPER_CALIBRATE AXIS=X
  {action_respond_info("X axis test complete. Run SAVE_CONFIG to apply.")}

[gcode_macro SHAPER_CALIBRATE_Y]
description: Run resonance test on Y axis only
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}
  {action_respond_info("Testing Y axis resonances...")}
  SHAPER_CALIBRATE AXIS=Y
  {action_respond_info("Y axis test complete. Run SAVE_CONFIG to apply.")}

# ── Belt tension analysis ─────────────────────────────────────────────────────
# K2 Plus has dual belts (X and Y CoreXY).
# This macro performs a low-frequency sweep on each axis to compare the
# frequency profiles of individual belts, helping diagnose uneven tension.
# Target belt tension: 140N (see [belt_mdl] in printer.cfg)

[gcode_macro BELTS_SHAPER_CALIBRATION]
description: Analyse belt tension via frequency sweep. Compare X and Y profiles.
variable_min_freq: 5.0
variable_max_freq: 60.0
variable_hz_per_sec: 1.0
variable_accel_per_hz: 200.0
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}

  {action_respond_info("Starting belt tension analysis...")}
  {action_respond_info("Min freq: %.1fHz  Max freq: %.1fHz" % (printer['gcode_macro BELTS_SHAPER_CALIBRATION'].min_freq, printer['gcode_macro BELTS_SHAPER_CALIBRATION'].max_freq))}
  {action_respond_info("Both axes should show similar frequency peaks if belt tension is balanced.")}
  {action_respond_info("Unbalanced peaks indicate one belt is tighter/looser than the other.")}
  {action_respond_info("Target belt tension: 140N (check Settings > Self-check > Belt Tension)")}

  TEST_RESONANCES AXIS=X OUTPUT=raw_data NAME=belt_x \
    FREQ_START={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].min_freq} \
    FREQ_END={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].max_freq} \
    HZ_PER_SEC={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].hz_per_sec} \
    ACCEL_PER_HZ={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].accel_per_hz}

  TEST_RESONANCES AXIS=Y OUTPUT=raw_data NAME=belt_y \
    FREQ_START={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].min_freq} \
    FREQ_END={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].max_freq} \
    HZ_PER_SEC={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].hz_per_sec} \
    ACCEL_PER_HZ={printer['gcode_macro BELTS_SHAPER_CALIBRATION'].accel_per_hz}

  {action_respond_info("Belt analysis complete.")}
  {action_respond_info("CSV files saved to /mnt/UDISK/printer_data/config/")}
  {action_respond_info("Download and plot both files to compare belt frequency profiles.")}

# ── Excitation at fixed frequency (vibration diagnosis) ──────────────────────
# Hold a specific frequency to locate vibration sources (rattles, loose parts).
# Move around the printer while it vibrates to find the source.

[gcode_macro EXCITATE_AXIS_AT_FREQ]
description: Hold axis excitation at a fixed frequency for vibration diagnosis
gcode:
  {% set axis  = params.AXIS|default("X")|upper %}
  {% set freq  = params.FREQ|default(25)|float %}
  {% set time  = params.TIME|default(10)|int %}
  {% set accel = params.ACCEL|default(5000)|float %}

  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}

  {action_respond_info("Exciting %s axis at %.1fHz for %ds" % (axis, freq, time))}
  {action_respond_info("Listen/feel for rattles and loose parts while it vibrates.")}

  TEST_RESONANCES AXIS={axis} \
    FREQ_START={freq} \
    FREQ_END={freq + 0.1} \
    HZ_PER_SEC=0.01 \
    ACCEL_PER_HZ={accel} \
    OUTPUT=raw_data

  {action_respond_info("Excitation complete.")}

# ── Apply and save recommended shapers ───────────────────────────────────────

[gcode_macro AUTOTUNE_SHAPERS]
description: Apply and save the recommended shaper settings from the last calibration
gcode:
  {action_respond_info("Saving shaper calibration results to printer.cfg...")}
  SAVE_CONFIG
  {action_respond_info("Shaper settings saved. Klipper will restart to apply.")}

# ── Generate raw CSV data for external analysis ───────────────────────────────

[gcode_macro TEST_RESONANCES_GRAPHS]
description: Generate raw resonance CSV data for both axes for external analysis
gcode:
  {% if printer.toolhead.homed_axes != "xyz" %}
    G28
  {% endif %}

  {action_respond_info("Generating resonance data for X axis...")}
  TEST_RESONANCES AXIS=X OUTPUT=raw_data NAME=resonance_x

  {action_respond_info("Generating resonance data for Y axis...")}
  TEST_RESONANCES AXIS=Y OUTPUT=raw_data NAME=resonance_y

  {action_respond_info("Done. CSV files saved to /mnt/UDISK/printer_data/config/")}
  {action_respond_info("Download via Fluidd file manager for analysis with Klipper's calibrate_shaper.py")}

# ── Restore saved shaper settings ────────────────────────────────────────────

[gcode_macro RESTORE_SHAPERS]
description: Restore the shaper settings from printer.cfg SAVE_CONFIG block
gcode:
  {action_respond_info("Restoring shaper settings from SAVE_CONFIG block...")}
  {% set x_type  = printer.configfile.settings.input_shaper.shaper_type_x %}
  {% set x_freq  = printer.configfile.settings.input_shaper.shaper_freq_x %}
  {% set y_type  = printer.configfile.settings.input_shaper.shaper_type_y %}
  {% set y_freq  = printer.configfile.settings.input_shaper.shaper_freq_y %}
  SET_INPUT_SHAPER SHAPER_TYPE_X={x_type} SHAPER_FREQ_X={x_freq} SHAPER_TYPE_Y={y_type} SHAPER_FREQ_Y={y_freq}
  {action_respond_info("Restored: X=%s @ %.1fHz  Y=%s @ %.1fHz" % (x_type, x_freq, y_type, y_freq))}

# ── Quick status check ────────────────────────────────────────────────────────

[gcode_macro SHAPER_STATUS]
description: Show current active input shaper settings
gcode:
  {% set x_type = printer.configfile.settings.input_shaper.shaper_type_x %}
  {% set x_freq = printer.configfile.settings.input_shaper.shaper_freq_x %}
  {% set y_type = printer.configfile.settings.input_shaper.shaper_type_y %}
  {% set y_freq = printer.configfile.settings.input_shaper.shaper_freq_y %}
  {action_respond_info("Input Shaper status:")}
  {action_respond_info("  X: %s @ %.1f Hz" % (x_type, x_freq))}
  {action_respond_info("  Y: %s @ %.1f Hz" % (y_type, y_freq))}
EOF

    add_include_to_printer_cfg "shapers_calibration.cfg"
    restart_klipper

    mark_installed "improved_shapers"
    echo ""
    log_success "Improved Shapers Calibrations installed!"
    echo ""
    echo "  Available macros:"
    echo -e "  ${GREEN}Full calibration:${NC}   INPUT_SHAPER_CALIBRATION"
    echo -e "  ${GREEN}Per-axis:${NC}           SHAPER_CALIBRATE_X  |  SHAPER_CALIBRATE_Y"
    echo -e "  ${GREEN}Belt analysis:${NC}      BELTS_SHAPER_CALIBRATION"
    echo -e "  ${GREEN}Diagnosis:${NC}          EXCITATE_AXIS_AT_FREQ [AXIS=X] [FREQ=25] [TIME=10]"
    echo -e "  ${GREEN}Raw data:${NC}           TEST_RESONANCES_GRAPHS"
    echo -e "  ${GREEN}Apply & save:${NC}       AUTOTUNE_SHAPERS"
    echo -e "  ${GREEN}Restore:${NC}            RESTORE_SHAPERS"
    echo -e "  ${GREEN}Status:${NC}             SHAPER_STATUS"
    echo ""
    log_info "Recommended workflow:"
    echo "  1. Run INPUT_SHAPER_CALIBRATION"
    echo "  2. Review results in console"
    echo "  3. Run AUTOTUNE_SHAPERS to save"
    echo ""
    log_info "Belt tension check: Settings → Self-check → Belt Tension (target: 140N)"
    echo ""
}

remove_shapers() {
    echo ""
    log_info "Removing Improved Shapers Calibrations..."
    remove_include_from_printer_cfg "shapers_calibration.cfg"
    rm -f "$SHAPERS_CFG"
    restart_klipper
    mark_removed "improved_shapers"
    log_success "Improved Shapers Calibrations removed."
    echo ""
}

case "$1" in
    install) install_shapers ;;
    remove)  remove_shapers ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
