#!/bin/sh
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

install_mobileraker() {
    echo ""
    log_info "This feature is not yet implemented for K2 Plus."
    log_info "Please check the wiki for updates:"
    log_info "https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus/"
    echo ""
}

remove_mobileraker() {
    echo ""
    log_info "This feature is not yet implemented for K2 Plus."
    echo ""
}

case "$1" in
    install) install_mobileraker ;;
    remove)  remove_mobileraker ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
