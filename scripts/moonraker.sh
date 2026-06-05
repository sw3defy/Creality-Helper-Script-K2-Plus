#!/bin/sh
# moonraker.sh - Install/remove Moonraker extensions for K2 Plus

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

MOONRAKER_CONF=$CONFIG_DIR/moonraker.conf
STOCK_MOONRAKER_CONF=/usr/share/moonraker/moonraker.conf

install_moonraker_extensions() {
    echo ""
    log_info "Installing Moonraker Extensions..."
    echo ""

    # 1. Create our moonraker.conf wrapper in /mnt/UDISK
    if [ ! -f "$MOONRAKER_CONF" ]; then
        cat > "$MOONRAKER_CONF" << 'EOF'
# Creality K2 Plus - Moonraker extension config
# Managed by Creality Helper Script
# https://github.com/sw3defy/Creality-Helper-Script-Wiki-K2-Plus
#
# This file loads the stock read-only Moonraker config first,
# then extensions added by the helper script appear below.

[include /usr/share/moonraker/moonraker.conf]
EOF
        log_success "Created $MOONRAKER_CONF"
    else
        log_info "moonraker.conf already exists, checking include..."
        # Ensure include is present
        if ! grep -q "include /usr/share/moonraker/moonraker.conf" "$MOONRAKER_CONF"; then
            sed -i "1s/^/[include \/usr\/share\/moonraker\/moonraker.conf]\n\n/" "$MOONRAKER_CONF"
            log_success "Added stock config include to existing moonraker.conf"
        fi
    fi

    # 2. Patch S56moonraker to point to our config
    patch_moonraker_startup

    # 4. Restart Moonraker
    restart_moonraker

    mark_installed "moonraker_extensions"
    echo ""
    log_success "Moonraker Extensions installed successfully!"
    echo ""
    log_info "Update Manager is now available in Fluidd under Settings → Software Updates."
    log_info "Object processing enabled (required for KAMP)."
    echo ""
}

remove_moonraker_extensions() {
    echo ""
    log_info "Removing Moonraker Extensions..."
    echo ""

    # Only remove the extensions file if it exists
    if [ ! -f "$MOONRAKER_CONF" ]; then
        log_warn "No moonraker.conf found at $MOONRAKER_CONF — nothing to remove."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}WARNING: This will remove your moonraker.conf and restore the stock config.${NC}"
    echo "Any other extensions (timelapse, KAMP, etc.) that added sections to"
    echo "moonraker.conf will also stop working until re-installed."
    echo ""
    printf "Are you sure? [y/N]: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        return 0
    fi

    # Restore stock moonraker startup
    unpatch_moonraker_startup

    # Archive the config rather than deleting it
    mv "$MOONRAKER_CONF" "${MOONRAKER_CONF}.removed.$(date +%Y%m%d)"
    log_success "Archived moonraker.conf"

    restart_moonraker

    mark_removed "moonraker_extensions"
    log_success "Moonraker Extensions removed. Stock config restored."
}

case "$1" in
    install) install_moonraker_extensions ;;
    remove)  remove_moonraker_extensions ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
