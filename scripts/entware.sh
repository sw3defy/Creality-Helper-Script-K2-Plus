#!/bin/sh
# entware.sh - Install Entware on K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

ENTWARE_DIR=/mnt/UDISK/entware
ENTWARE_INSTALLER=http://bin.entware.net/armv7sf-k3.2/installer/generic.sh

check_entware() {
    [ -f "$ENTWARE_DIR/bin/opkg" ] && return 0
    return 1
}

setup_entware_path() {
    PROFILE=/etc/profile
    if ! grep -q "entware" "$PROFILE" 2>/dev/null; then
        printf '\n# Entware\nexport PATH=/mnt/UDISK/entware/bin:/mnt/UDISK/entware/sbin:$PATH\nexport LD_LIBRARY_PATH=/mnt/UDISK/entware/lib:/mnt/UDISK/entware/usr/lib:$LD_LIBRARY_PATH\n' >> "$PROFILE"
        log_success "Added Entware to PATH in /etc/profile"
    fi
    export PATH="$ENTWARE_DIR/bin:$ENTWARE_DIR/sbin:$PATH"
    export LD_LIBRARY_PATH="$ENTWARE_DIR/lib:$ENTWARE_DIR/usr/lib:$LD_LIBRARY_PATH"
}

install_entware() {
    echo ""
    log_info "Installing Entware..."
    echo ""

    if check_entware; then
        log_info "Entware already installed at $ENTWARE_DIR"
        echo ""
        echo "  1) Update Entware packages"
        echo "  2) Reinstall Entware"
        echo "  0) Cancel"
        echo ""
        printf "  Enter choice: "
        read subchoice
        case "$subchoice" in
            1)
                log_info "Updating Entware packages..."
                $ENTWARE_DIR/bin/opkg update && $ENTWARE_DIR/bin/opkg upgrade
                log_success "Entware packages updated."
                return 0 ;;
            2) : ;;
            *) log_info "Cancelled."; return 0 ;;
        esac
    fi

    mkdir -p "$ENTWARE_DIR"

    log_info "Downloading Entware installer..."
    python3 -c "
import urllib.request, os, stat
urllib.request.urlretrieve('$ENTWARE_INSTALLER', '/tmp/entware_install.sh')
os.chmod('/tmp/entware_install.sh', 0o755)
print('Downloaded')
"
    if [ ! -f /tmp/entware_install.sh ]; then
        log_error "Failed to download Entware installer."
        return 1
    fi

    log_info "Running Entware installer..."
    OPENWRT_PREFIX="$ENTWARE_DIR" sh /tmp/entware_install.sh
    rm -f /tmp/entware_install.sh

    if ! check_entware; then
        log_error "Entware installation failed."
        return 1
    fi

    setup_entware_path
    log_info "Updating Entware package list..."
    $ENTWARE_DIR/bin/opkg update

    mark_installed "entware"
    echo ""
    log_success "Entware installed successfully!"
    echo ""
    log_info "Use 'opkg install <package>' to install packages"
    log_info "Useful: opkg install mjpg-streamer git wget curl nano"
    echo ""
}

remove_entware() {
    echo ""
    echo "${YELLOW}WARNING: This removes Entware and all installed packages.${NC}"
    printf "Are you sure? [y/N]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    sed -i '/# Entware/,+2d' /etc/profile
    rm -rf "$ENTWARE_DIR"
    mark_removed "entware"
    log_success "Entware removed."
    echo ""
}

case "$1" in
    install) install_entware ;;
    remove)  remove_entware ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
