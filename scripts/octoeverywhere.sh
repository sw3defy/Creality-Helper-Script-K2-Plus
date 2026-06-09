#!/bin/sh
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

install_octoeverywhere() {
    echo ""
    log_info "This feature is not yet implemented for K2 Plus."
    log_info "Please check the wiki for updates:"
    log_info "https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus/"
    echo ""
}

remove_octoeverywhere() {

    echo -e "${YELLOW}WARNING: This will remove OctoEverywhere.${NC}"
    printf "Are you sure? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    echo ""
    log_info "This feature is not yet implemented for K2 Plus."
    echo ""
}

case "$1" in
    install) install_octoeverywhere ;;
    remove)  remove_octoeverywhere ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
