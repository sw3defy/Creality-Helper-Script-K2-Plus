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
    log_info "Restarting Moonraker..."
    # Kill ALL running moonraker instances (stock + helper script)
    for pid in $(ps aux | grep moonraker.py | grep -v grep | awk '{print $1}'); do
        kill "$pid" 2>/dev/null
    done
    sleep 2
    /etc/rc.d/S56moonraker start
    sleep 3
    if pgrep -f "moonraker.py" > /dev/null; then
        log_success "Moonraker restarted successfully."
    else
        log_error "Moonraker failed to restart. Check $LOGS_DIR/moonraker.log"
    fi
}

restart_nginx() {
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
            echo "  ${GREEN}✓${NC} $line"
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
        sed -i "/^\[include ${include_file}\]$/d" "$printer_cfg"
        log_success "Removed [include ${include_file}] from printer.cfg"
    fi
}

# ── moonraker.conf management ─────────────────────────────────────────────────

MOONRAKER_CONF=$CONFIG_DIR/moonraker.conf
MOONRAKER_RC=/etc/rc.d/S56moonraker
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

# ── Entry point ───────────────────────────────────────────────────────────────
case "$1" in
    restart_klipper)   restart_klipper ;;
    restart_moonraker) restart_moonraker ;;
    restart_nginx)     restart_nginx ;;
    restart_camera)    restart_camera ;;
    show_installed)    show_installed ;;
esac
