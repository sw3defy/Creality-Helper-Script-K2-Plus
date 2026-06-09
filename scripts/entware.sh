#!/bin/sh
# entware.sh - Install Entware package manager on K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

install_entware() {
    echo ""
    log_info "Installing Entware Package Manager..."
    echo ""
    echo "  Entware provides hundreds of Linux packages for the K2 Plus."
    echo "  This uses a Python-based wget shim to bootstrap the installer."
    echo ""
    printf "  Continue? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }

    if [ -f /opt/bin/opkg ]; then
        log_info "Entware already installed."
        echo ""
        echo "  What would you like to do?"
        echo "   1) Install useful packages"
        echo "   2) Update package list"
        echo "   3) Open opkg shell"
        echo "   0) Back"
        echo ""
        printf "  Enter choice: "
        read choice
        case "$choice" in
            1) install_packages ;;
            2) export PATH=/opt/bin:/opt/sbin:$PATH; opkg update; log_success "Package list updated." ;;
            3) export PATH=/opt/bin:/opt/sbin:$PATH; sh ;;
        esac
        return 0
    fi

    # Create dummy wget
    log_info "Creating dummy wget..."
    mkdir -p ~/bin
    python3 -c "
import urllib.request
urllib.request.urlretrieve(
    'https://github.com/vsevolod-volkov/K2Plus-entware/raw/refs/heads/main/wget',
    '/root/bin/wget'
)
"
    chmod +x ~/bin/wget
    export PATH=$PATH:~/bin

    # Run installer
    log_info "Running Entware installer..."
    wget http://bin.entware.net/armv7sf-k2.6/installer/generic.sh -O - | sh

    # Setup PATH
    export PATH=/opt/bin:/opt/sbin:$PATH

    # Install real wget and remove dummy
    log_info "Installing real wget..."
    opkg update
    opkg install wget
    rm -f ~/bin/wget

    # Make PATH persistent
    python3 -c "
content = open('/etc/rc.local').read()
if 'entware' not in content:
    content = content.replace('exit 0', '# Entware\n[ -f /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung start\nexport PATH=/opt/bin:/opt/sbin:\$PATH\nexit 0')
    open('/etc/rc.local', 'w').write(content)
    print('Added Entware to rc.local')
else:
    print('Already in rc.local')
"

    # Add to profile
    test -f ~/.profile || echo '#!/bin/ash' > ~/.profile
    chmod +x ~/.profile
    grep -q 'opt/bin' ~/.profile || echo 'export PATH=/opt/bin:/opt/sbin:$PATH' >> ~/.profile

    mark_installed "entware"
    echo ""
    log_success "Entware installed!"
    echo ""
    echo "  Would you like to install useful packages now?"
    printf "  [y/n]: "
    read confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] && install_packages
}

install_packages() {
    export PATH=/opt/bin:/opt/sbin:$PATH
    echo ""
    echo "  Select packages to install:"
    echo "   1) nano        — better text editor"
    echo "   2) htop        — process monitor"
    echo "   3) git         — version control"
    echo "   4) openssh-sftp-server — SFTP file transfer"
    echo "   5) curl        — HTTP client"
    echo "   6) All of the above"
    echo "   0) Back"
    echo ""
    printf "  Enter choice: "
    read choice
    case "$choice" in
        1) opkg install nano ;;
        2) opkg install htop ;;
        3) opkg install git git-http && ln -sf /opt/bin/git /usr/bin/git ;;
        4) opkg install openssh-sftp-server
           ln -sf /opt/libexec/sftp-server /usr/libexec/sftp-server
           python3 -c "
content = open('/etc/rc.local').read()
if 'sftp-server' not in content:
    content = content.replace('# Entware', '# Entware
ln -sf /opt/libexec/sftp-server /usr/libexec/sftp-server 2>/dev/null')
    open('/etc/rc.local', 'w').write(content)
"
           ;;
        5) opkg install curl && ln -sf /opt/bin/curl /usr/bin/curl ;;
        6)
            opkg install nano htop git git-http curl openssh-sftp-server
            ln -sf /opt/bin/git /usr/bin/git
            ln -sf /opt/libexec/sftp-server /usr/libexec/sftp-server
            ln -sf /opt/bin/curl /usr/bin/curl
            ;;
        0) return ;;
    esac
    echo ""
    log_success "Done!"
}

remove_entware() {
    echo ""
    echo -e "${YELLOW}WARNING: This will remove Entware and all installed packages.${NC}"
    printf "Are you sure? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }

    rm -rf /opt
    python3 -c "
content = open('/etc/rc.local').read()
content = content.replace('# Entware\n[ -f /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung start\nexport PATH=/opt/bin:/opt/sbin:\$PATH\n', '')
open('/etc/rc.local', 'w').write(content)
"
    mark_removed "entware"
    log_success "Entware removed."
}

case "$1" in
    install) install_entware ;;
    remove)  remove_entware ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
