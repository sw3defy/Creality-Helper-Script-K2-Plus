#!/bin/sh
# system.sh - Service management and system utilities for K2 Plus Helper Script

SCRIPT_DIR=/mnt/UDISK/helper-script
CONFIG_DIR=/mnt/UDISK/printer_data/config
LOGS_DIR=/mnt/UDISK/printer_data/logs
INSTALLED_FILE=$SCRIPT_DIR/.installed

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# ── Service restarts ──────────────────────────────────────────────────────────

restart_klipper() {
    if [ "$1" != "force" ]; then
        printf "Restart Klipper? [y/n]: "
        read confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    fi
    log_info "Restarting Klipper..."
    /etc/rc.d/S55klipper restart
    sleep 3
    if pgrep -f "klippy.py" > /dev/null; then
        log_success "Klipper restarted successfully."
    else
        log_error "Klipper failed to restart. Check $LOGS_DIR/klippy.log"
    fi
}

restart_moonraker() {
    if [ "$1" != "force" ]; then
        printf "Restart Moonraker? [y/n]: "
        read confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    fi
    log_info "Restarting Moonraker..."
    # Kill ALL running moonraker instances (stock + helper script)
    for pid in $(ps aux | grep moonraker.py | grep -v grep | awk '{print $1}'); do
        kill "$pid" 2>/dev/null
    done
    sleep 2
    /etc/init.d/moonraker start
    sleep 3
    if pgrep -f "moonraker.py" > /dev/null; then
        log_success "Moonraker restarted successfully."
    else
        log_error "Moonraker failed to restart. Check $LOGS_DIR/moonraker.log"
    fi
}

restart_nginx() {
    if [ "$1" != "force" ]; then
        printf "Restart Nginx? [y/n]: "
        read confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    fi
    log_info "Restarting Nginx..."
    /etc/rc.d/S80nginx restart
    sleep 2
    if pgrep -f "nginx" > /dev/null; then
        log_success "Nginx restarted successfully."
    else
        log_error "Nginx failed to restart."
    fi
}

restart_camera() {
    log_info "Restarting WebRTC camera service..."
    /etc/rc.d/S97webrtc restart
    sleep 2
    log_success "Camera service restarted."
}

# ── Feature tracking ──────────────────────────────────────────────────────────

mark_installed() {
    local feature="$1"
    touch "$INSTALLED_FILE" 2>/dev/null
    if ! grep -q "^$feature$" "$INSTALLED_FILE" 2>/dev/null; then
        echo "$feature" >> "$INSTALLED_FILE"
    fi
}

mark_removed() {
    local feature="$1"
    if [ -f "$INSTALLED_FILE" ]; then
        sed -i "/^$feature$/d" "$INSTALLED_FILE"
    fi
}

is_installed() {
    local feature="$1"
    [ -f "$INSTALLED_FILE" ] && grep -q "^$feature$" "$INSTALLED_FILE"
}

show_installed() {
    echo ""
    echo "Installed features:"
    if [ -f "$INSTALLED_FILE" ] && [ -s "$INSTALLED_FILE" ]; then
        while IFS= read -r line; do
            echo -e "  ${GREEN}✓${NC} $line"
        done < "$INSTALLED_FILE"
    else
        echo "  None installed yet."
    fi
    echo ""
}

# ── printer.cfg include management ───────────────────────────────────────────

# Add an [include filename.cfg] line to printer.cfg if not already present
add_include_to_printer_cfg() {
    local include_file="$1"
    local printer_cfg="$CONFIG_DIR/printer.cfg"

    if grep -q "^\[include ${include_file}\]" "$printer_cfg" 2>/dev/null; then
        log_info "[include ${include_file}] already present in printer.cfg"
        return 0
    fi

    # Insert after the last existing [include ...] line, or at top if none
    if grep -q "^\[include " "$printer_cfg"; then
        # Find line number of last include and insert after it
        last_include=$(grep -n "^\[include " "$printer_cfg" | tail -1 | cut -d: -f1)
        sed -i "${last_include}a [include ${include_file}]" "$printer_cfg"
    else
        # No includes yet - add after the first comment block
        sed -i "1s/^/[include ${include_file}]\n/" "$printer_cfg"
    fi

    log_success "Added [include ${include_file}] to printer.cfg"
}

# Remove an [include filename.cfg] line from printer.cfg
remove_include_from_printer_cfg() {
    local include_file="$1"
    local printer_cfg="$CONFIG_DIR/printer.cfg"

    if grep -q "^\[include ${include_file}\]" "$printer_cfg" 2>/dev/null; then
        sed -i "\|^\[include ${include_file}\]$|d" "$printer_cfg"
        log_success "Removed [include ${include_file}] from printer.cfg"
    fi
}

# ── moonraker.conf management ─────────────────────────────────────────────────

MOONRAKER_CONF=$CONFIG_DIR/moonraker.conf
MOONRAKER_RC=/etc/rc.d/S56moonraker
MOONRAKER_RC_BAK=/mnt/UDISK/helper-script/.S56moonraker.orig
MOONRAKER_STOCK_CONF=/usr/share/moonraker/moonraker.conf

# Patch S56moonraker to use our config wrapper instead of the stock one
patch_moonraker_startup() {
    if grep -q "CONF=/mnt/UDISK" "$MOONRAKER_RC" 2>/dev/null; then
        log_info "Moonraker startup already patched."
        return 0
    fi

    # Back up original
    if [ ! -f "${MOONRAKER_RC}.orig" ]; then
        cp "$MOONRAKER_RC" "${MOONRAKER_RC}.orig"
        log_success "Backed up original S56moonraker to ${MOONRAKER_RC}.orig"
    fi

    # Replace the CONF= line
    sed -i "s|CONF=/usr/share/moonraker/moonraker.conf|CONF=/mnt/UDISK/printer_data/config/moonraker.conf|g" "$MOONRAKER_RC"
    log_success "Patched S56moonraker to use /mnt/UDISK/printer_data/config/moonraker.conf"
}

# Restore the original CONF= line
unpatch_moonraker_startup() {
    if [ -f "${MOONRAKER_RC}.orig" ]; then
        cp "${MOONRAKER_RC}.orig" "$MOONRAKER_RC"
        log_success "Restored original S56moonraker startup."
        rm -f "${MOONRAKER_RC}.orig"
    else
        # Restore manually if backup is missing
        sed -i "s|CONF=/mnt/UDISK/printer_data/config/moonraker.conf|CONF=/usr/share/moonraker/moonraker.conf|g" "$MOONRAKER_RC"
        log_success "Restored S56moonraker CONF to stock path."
    fi
}

# Add a section to our moonraker.conf (idempotent)
add_moonraker_section() {
    local section_name="$1"
    local section_content="$2"

    if grep -q "^\[${section_name}" "$MOONRAKER_CONF" 2>/dev/null; then
        log_info "[$section_name] already present in moonraker.conf"
        return 0
    fi

    echo "" >> "$MOONRAKER_CONF"
    echo "$section_content" >> "$MOONRAKER_CONF"
    log_success "Added [$section_name] to moonraker.conf"
}

# Remove a section from our moonraker.conf
remove_moonraker_section() {
    local section_name="$1"
    if [ ! -f "$MOONRAKER_CONF" ]; then return 0; fi

    # Remove from [section_name] to the next blank line + section start
    python3 - "$MOONRAKER_CONF" "$section_name" << 'PYEOF'
import sys, re
path, section = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Remove the section block
pattern = r'\n\[' + re.escape(section) + r'\][^\[]*'
content = re.sub(pattern, '', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF
    log_success "Removed [$section_name] from moonraker.conf"
}

# ── nginx management ──────────────────────────────────────────────────────────

NGINX_CONF=/etc/nginx/nginx.conf
NGINX_CONF_BAK=/mnt/UDISK/helper-script/.nginx.conf.bak

backup_nginx_conf() {
    if [ ! -f "$NGINX_CONF_BAK" ]; then
        cp "$NGINX_CONF" "$NGINX_CONF_BAK"
        log_success "Backed up nginx.conf to $NGINX_CONF_BAK"
    fi
}

restore_nginx_conf() {
    if [ -f "$NGINX_CONF_BAK" ]; then
        cp "$NGINX_CONF_BAK" "$NGINX_CONF"
        log_success "Restored nginx.conf from backup."
        rm -f "$NGINX_CONF_BAK"
        restart_nginx
    else
        log_warn "No nginx.conf backup found."
    fi
}

# ── Stock config patch (fix underscore prefix bug) ────────────────────────────

patch_stock_configs() {
    local box_cfg="$CONFIG_DIR/box.cfg"
    local macro_cfg="$CONFIG_DIR/gcode_macro.cfg"

    log_info "Patching stock config files to fix macro naming..."

    if [ -f "$box_cfg" ]; then
        sed -i 's/\[gcode_macro _BOX_/[gcode_macro BOX_/g' "$box_cfg"
        log_success "Patched box.cfg"
    fi

    if [ -f "$macro_cfg" ]; then
        sed -i \
          -e 's/\[gcode_macro _PRINTER_PARAM\]/[gcode_macro PRINTER_PARAM]/g' \
          -e "s/gcode_macro _PRINTER_PARAM'/gcode_macro PRINTER_PARAM'/g" \
          -e 's/printer\["gcode_macro _PRINTER_PARAM"\]/printer["gcode_macro PRINTER_PARAM"]/g' \
          -e 's/MACRO=_PRINTER_PARAM/MACRO=PRINTER_PARAM/g' \
          -e 's/\[gcode_macro _MAINTENANCE_ITEM_PARAM\]/[gcode_macro MAINTENANCE_ITEM_PARAM]/g' \
          -e 's/\[gcode_macro _IF_NEED_HOME\]/[gcode_macro IF_NEED_HOME]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL_CLOSE_FAN2\]/[gcode_macro LOAD_MATERIAL_CLOSE_FAN2]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL_RESTORE_FAN2\]/[gcode_macro LOAD_MATERIAL_RESTORE_FAN2]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL_HEATING\]/[gcode_macro LOAD_MATERIAL_HEATING]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL_MATERIAL_FLUSH\]/[gcode_macro LOAD_MATERIAL_MATERIAL_FLUSH]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL_END\]/[gcode_macro LOAD_MATERIAL_END]/g' \
          -e 's/\[gcode_macro _LOAD_MATERIAL\]/[gcode_macro LOAD_MATERIAL]/g' \
          -e 's/\[gcode_macro _QUIT_MATERIAL_HEATING\]/[gcode_macro QUIT_MATERIAL_HEATING]/g' \
          -e 's/\[gcode_macro _QUIT_MATERIAL_CUT_MATERIAL\]/[gcode_macro QUIT_MATERIAL_CUT_MATERIAL]/g' \
          -e 's/\[gcode_macro _QUIT_MATERIAL_RETRUDE_MATERIAL\]/[gcode_macro QUIT_MATERIAL_RETRUDE_MATERIAL]/g' \
          -e 's/\[gcode_macro _QUIT_MATERIAL_END\]/[gcode_macro QUIT_MATERIAL_END]/g' \
          -e 's/\[gcode_macro _QUIT_MATERIAL\]/[gcode_macro QUIT_MATERIAL]/g' \
          -e 's/\[gcode_macro _Qmode\]/[gcode_macro Qmode]/g' \
          -e "s/gcode_macro _Qmode'/gcode_macro Qmode'/g" \
          -e 's/MACRO=_Qmode/MACRO=Qmode/g' \
          -e 's/\[gcode_macro _Qmode_exit\]/[gcode_macro Qmode_exit]/g' \
          -e 's/\[gcode_macro _M205\]/[gcode_macro M205]/g' \
          -e 's/\[gcode_macro _M106\]/[gcode_macro M106]/g' \
          -e 's/\[gcode_macro _M107\]/[gcode_macro M107]/g' \
          -e 's/\[gcode_macro _M900\]/[gcode_macro M900]/g' \
          -e 's/\[gcode_macro _WAIT_TEMP_START\]/[gcode_macro WAIT_TEMP_START]/g' \
          -e 's/\[gcode_macro _WAIT_TEMP_END\]/[gcode_macro WAIT_TEMP_END]/g' \
          -e 's/\[gcode_macro _PRINT_CALIBRATION\]/[gcode_macro PRINT_CALIBRATION]/g' \
          -e 's/\[gcode_macro _FIRST_FLOOR_PAUSE_POSITION\]/[gcode_macro FIRST_FLOOR_PAUSE_POSITION]/g' \
          -e 's/\[gcode_macro _PRINT_TEMP_SET\]/[gcode_macro PRINT_TEMP_SET]/g' \
          -e 's/\[gcode_macro _ZDOWN_SWITCH_SET\]/[gcode_macro ZDOWN_SWITCH_SET]/g' \
          -e 's/\[gcode_macro _PRINT_PREPARED\]/[gcode_macro PRINT_PREPARED]/g' \
          -e 's/\[gcode_macro _PRINT_PREPARE_CLEAR\]/[gcode_macro PRINT_PREPARE_CLEAR]/g' \
          -e 's/\[gcode_macro _END_PRINT_POINT_WITHOUT_LIFTING\]/[gcode_macro END_PRINT_POINT_WITHOUT_LIFTING]/g' \
          -e 's/\[gcode_macro _END_PRINT_Z_SAFE\]/[gcode_macro END_PRINT_Z_SAFE]/g' \
          -e 's/\[gcode_macro _END_PRINT_POINT\]/[gcode_macro END_PRINT_POINT]/g' \
          -e 's/\[gcode_macro _FIRST_FLOOR_PAUSE\]/[gcode_macro FIRST_FLOOR_PAUSE]/g' \
          -e 's/\[gcode_macro _FIRST_FLOOR_RESUME\]/[gcode_macro FIRST_FLOOR_RESUME]/g' \
          -e 's/\[gcode_macro _PAUSE_EXTERNAL\]/[gcode_macro PAUSE_EXTERNAL]/g' \
          -e 's/\[gcode_macro _RESUME_EXTERNAL_PROCESS\]/[gcode_macro RESUME_EXTERNAL_PROCESS]/g' \
          -e 's/\[gcode_macro _RESUME_EXTERNAL\]/[gcode_macro RESUME_EXTERNAL]/g' \
          -e 's/\[gcode_macro _MOTOR_CANCEL_PRINT\]/[gcode_macro MOTOR_CANCEL_PRINT]/g' \
          -e 's/\[gcode_macro _BED_MANUAL_CAL_START\]/[gcode_macro BED_MANUAL_CAL_START]/g' \
          -e 's/\[gcode_macro _BED_MANUAL_CAL_END\]/[gcode_macro BED_MANUAL_CAL_END]/g' \
          -e 's/\[gcode_macro _BED_MESH_CALIBRATE_START_PRINT\]/[gcode_macro BED_MESH_CALIBRATE_START_PRINT]/g' \
          -e 's/\[gcode_macro _CANCEL_CHAMBER_FAN_SWITCH\]/[gcode_macro CANCEL_CHAMBER_FAN_SWITCH]/g' \
          -e 's/\[gcode_macro _INPUTSHAPER\]/[gcode_macro INPUTSHAPER]/g' \
          -e 's/\[gcode_macro _BEDPID\]/[gcode_macro BEDPID]/g' \
          -e 's/\[gcode_macro _NOZZLE_PID\]/[gcode_macro NOZZLE_PID]/g' \
          -e 's/\[gcode_macro _NOZZLE_PID_HIGH\]/[gcode_macro NOZZLE_PID_HIGH]/g' \
          -e 's/\[gcode_macro _TUNOFFINPUTSHAPER\]/[gcode_macro TUNOFFINPUTSHAPER]/g' \
          -e 's/    _PRINT_PREPARE_CLEAR/    PRINT_PREPARE_CLEAR/g' \
          -e 's/  _END_PRINT_Z_SAFE/  END_PRINT_Z_SAFE/g' \
          -e 's/  _QMODE_EXIT/  QMODE_EXIT/g' \
          -e 's/  _PRINT_PREPARE_CLEAR/  PRINT_PREPARE_CLEAR/g' \
          -e 's/  _END_PRINT_POINT/  END_PRINT_POINT/g' \
          -e 's/  _WAIT_TEMP_START/  WAIT_TEMP_START/g' \
          -e 's/M140 S{params\.BED_TEMP}/M140 S{BED_TEMP}/g' \
          -e 's/M104 S{params\.EXTRUDER_TEMP}/M104 S{EXTRUDER_TEMP}/g' \
          -e 's/M190 S{params\.BED_TEMP}/M190 S{BED_TEMP}/g' \
          -e 's/M109 S{params\.EXTRUDER_TEMP}/M109 S{EXTRUDER_TEMP}/g' \
          "$macro_cfg"
        log_success "Patched gcode_macro.cfg"
    fi

    local printer_cfg="$CONFIG_DIR/printer.cfg"
    if [ -f "$printer_cfg" ]; then
        sed -i 's/mesh_min: 5,5/mesh_min: 20,20/' "$printer_cfg"
        log_success "Patched printer.cfg mesh_min"
    fi

    # Restore motor_control.cfg from stock if it has been truncated/modified.
    # A stripped-down motor_control.cfg (missing the PID/protection/LESO
    # tuning block, e.g. x_protection_param_prt_track_max_err) makes the
    # closed-loop X stepper far more sensitive to position-tracking errors,
    # causing key789 stalls during the CFS cut-position move (CR_BOX_CUT).
    local motor_cfg="$CONFIG_DIR/motor_control.cfg"
    local stock_motor_cfg="/rom/usr/share/klipper/config/F008_CR0CN240319C13/motor_control.cfg"
    if [ -f "$motor_cfg" ] && [ -f "$stock_motor_cfg" ]; then
        if ! diff -q "$stock_motor_cfg" "$motor_cfg" > /dev/null 2>&1; then
            cp "$motor_cfg" "${motor_cfg}.before_patch" 2>/dev/null
            cp "$stock_motor_cfg" "$motor_cfg"
            log_success "Restored motor_control.cfg from stock (was truncated/modified - this caused X-axis tracking errors during CFS cuts)"
        else
            log_info "motor_control.cfg already matches stock."
        fi
    fi
}


# ── rc.local patch (ensure patch_stock_configs runs on every boot) ────────────

install_rc_local_patch() {
    local rc_local="/etc/rc.local"
    if grep -q "patch_stock_configs" "$rc_local" 2>/dev/null; then
        log_info "rc.local patch already installed."
    else
        sed -i 's|exit 0|# Patch stock Klipper configs\n/bin/sh /mnt/UDISK/helper-script/scripts/system.sh patch_stock_configs\n\nexit 0|' "$rc_local"
        log_success "Added patch_stock_configs to rc.local"
    fi

    if grep -q "install_moonraker_include" "$rc_local" 2>/dev/null; then
        log_info "moonraker include rc.local patch already installed."
    else
        sed -i 's|exit 0|# Ensure Moonraker loads UDISK extension config\n/bin/sh /mnt/UDISK/helper-script/scripts/system.sh install_moonraker_include\n\nexit 0|' "$rc_local"
        log_success "Added install_moonraker_include to rc.local"
    fi
}

# ── Moonraker include fix (ensure UDISK moonraker.conf is actually loaded) ────

install_moonraker_include() {
    local real_conf="/usr/share/moonraker/moonraker.conf"
    local udisk_conf="$CONFIG_DIR/moonraker.conf"
    local include_line="[include $udisk_conf]"

    if [ ! -f "$real_conf" ]; then
        log_info "Moonraker base config not found at $real_conf, skipping."
        return 0
    fi

    if [ ! -f "$udisk_conf" ]; then
        log_info "No UDISK moonraker.conf found, skipping include fix."
        return 0
    fi

    # Remove any stale/incorrect include in the UDISK file pointing back at
    # the real config -- this causes a recursive include loop.
    if grep -q "\[include $real_conf\]" "$udisk_conf" 2>/dev/null; then
        sed -i "\|\[include $real_conf\]|d" "$udisk_conf"
        log_info "Removed recursive include from $udisk_conf"
    fi

    if grep -qF "$include_line" "$real_conf" 2>/dev/null; then
        log_info "Moonraker include already installed."
    else
        sed -i "1i\\
$include_line
" "$real_conf"
        log_success "Added include for $udisk_conf to $real_conf"
        log_info "Without this, sections like [timelapse] and [update_manager] in $udisk_conf are silently ignored by Moonraker."
    fi

    # Queue gcode uploads so the UI waits for metadata extraction to finish
    # instead of hammering Moonraker with "Metadata not available" requests
    # and falling back to showing the slicer as "Unknown" in history.
    if grep -q "queue_gcode_uploads: False" "$real_conf" 2>/dev/null; then
        sed -i "s/queue_gcode_uploads: False/queue_gcode_uploads: True/" "$real_conf"
        log_success "Enabled queue_gcode_uploads in $real_conf"
    fi
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "$1" in
    restart_klipper)   restart_klipper ;;
    restart_moonraker) restart_moonraker ;;
    restart_nginx)     restart_nginx ;;
    restart_camera)    restart_camera ;;
    show_installed)    show_installed ;;
    patch_stock_configs) patch_stock_configs ;;
    install_rc_local_patch) install_rc_local_patch ;;
    install_moonraker_include) install_moonraker_include ;;
esac
