#!/bin/sh
# helixscreen.sh - Install/remove HelixScreen on K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

HELIX_INSTALL=/opt/helixscreen/install.sh

check_helixscreen() {
    [ -f "$HELIX_INSTALL" ] && return 0
    return 1
}

install_helixscreen() {
    echo ""
    log_info "Installing HelixScreen..."
    echo ""
    echo "======================================================"
    echo "  HelixScreen Installation"
    echo "======================================================"
    echo ""
    echo "  HelixScreen requires a reboot after installation."
    echo ""
    echo "  The installer will:"
    echo "    - Install HelixScreen"
    echo "    - Automatically reboot the printer"
    echo ""
    echo "  IMPORTANT:"
    echo "    - The first startup may take longer than normal."
    echo "    - The printer may remain on the Creality logo"
    echo "      for several minutes during the first boot."
    echo "    - Do NOT power off the printer during this process."
    echo "    - If stuck on Creality logo, use wipe_all USB recovery."
    echo ""
    printf "  Continue? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    if check_helixscreen; then
        log_info "HelixScreen is already installed."
        echo ""
        echo "  1) Update HelixScreen"
        echo "  0) Cancel"
        echo ""
        printf "  Enter choice: "
        read subchoice
        case "$subchoice" in
            1)
                log_info "Updating HelixScreen..."
                $HELIX_INSTALL --update
                log_success "HelixScreen updated."
                return 0 ;;
            *) log_info "Cancelled."; return 0 ;;
        esac
    fi

    log_info "Downloading and installing HelixScreen..."
    python3 -c "
import urllib.request as u
open('/tmp/install.sh','wb').write(
    u.urlopen(u.Request('http://dl.helixscreen.org/install.sh',
    headers={'User-Agent':'helixscreen-installer/1.0'}), timeout=30).read()
)
print('Downloaded installer')
"
    if [ ! -f /tmp/install.sh ]; then
        log_error "Failed to download HelixScreen installer."
        return 1
    fi

    sh /tmp/install.sh
    rm -f /tmp/install.sh

    if ! check_helixscreen; then
        log_error "HelixScreen installation failed."
        return 1
    fi

    # Remove update_manager section - not supported on K2 Plus
    python3 -c "
import re
try:
    content = open('/mnt/UDISK/printer_data/config/moonraker.conf').read()
    content = re.sub(r'\[update_manager helixscreen\][^\[]*', '', content)
    open('/mnt/UDISK/printer_data/config/moonraker.conf', 'w').write(content)
    print('Cleaned moonraker.conf')
except: pass
"
    mark_installed "helixscreen"
    echo ""
    log_success "HelixScreen installed successfully!"
    echo ""
    log_info "The touchscreen will show HelixScreen after reboot."
    log_info "Note: WiFi management shows as unavailable — this is normal."
    log_info "      Your printer WiFi connection is not affected."
    echo ""
    echo ""
    echo "======================================================"
    echo "  HelixScreen installed successfully."
    echo ""
    echo "  The printer will reboot in 10 seconds..."
    echo ""
    echo "  After reboot:"
    echo "    - Startup may take longer than usual."
    echo "    - Please be patient and do not power off."
    echo "======================================================"
    echo ""
    sleep 10
    reboot
}

remove_helixscreen() {

    echo -e "${YELLOW}WARNING: This will remove HelixScreen.${NC}"
    printf "Are you sure? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    echo ""
    log_info "Removing HelixScreen..."

    if ! check_helixscreen; then
        log_error "HelixScreen is not installed."
        return 1
    fi

    cp $HELIX_INSTALL /tmp/helix_uninstall.sh
    sh /tmp/helix_uninstall.sh --uninstall
    rm -f /tmp/helix_uninstall.sh

    mark_removed "helixscreen"
    echo ""
    log_success "HelixScreen removed. Stock Creality UI restored after reboot."
    echo ""
    echo "======================================================"
    echo "  HelixScreen removed successfully."
    echo ""
    echo "  The printer will reboot in 10 seconds..."
    echo "  Stock Creality UI will be restored after reboot."
    echo "======================================================"
    echo ""
    sleep 10
    reboot
}

case "$1" in
    install) install_helixscreen ;;
    remove)  remove_helixscreen ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
