#!/bin/sh
# Creality K2 Plus Helper Script
# https://github.com/sw3defy/Creality-Helper-Script-Wiki-K2-Plus

SCRIPT_DIR=/mnt/UDISK/helper-script
SCRIPTS_DIR=$SCRIPT_DIR/scripts
FILES_DIR=$SCRIPT_DIR/files
PRINTER_DATA=/mnt/UDISK/printer_data
CONFIG_DIR=$PRINTER_DATA/config
LOGS_DIR=$PRINTER_DATA/logs

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BLUE='\033[1;34m'
NC='\033[0m'

print_header() {
    clear
    echo ""
    echo -e "${WHITE}======================================================${NC}"
    echo -e "${WHITE}   Creality K2 Plus Helper Script${NC}"
    echo -e "${WHITE}======================================================${NC}"
    echo -e "${YELLOW}   https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus${NC}"
    echo -e "${WHITE}======================================================${NC}"
    echo ""
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}ERROR: This script must be run as root.${NC}"
        exit 1
    fi
}

check_printer() {
    if [ ! -f "$CONFIG_DIR/printer.cfg" ]; then
        echo -e "${RED}ERROR: printer.cfg not found at $CONFIG_DIR/printer.cfg${NC}"
        exit 1
    fi
}

main_menu() {
    print_header
        echo -e "  ${WHITE}[Install] Menu${NC}"
    echo -e "  ${CYAN}--- Step 1: Foundation (install first) ---${NC}"
    echo -e "    ${YELLOW}1)${NC} ${GREEN}Moonraker Extensions & Update Manager${NC}  ${WHITE}[recommended first]${NC}"
    echo ""
    echo -e "  ${CYAN}--- Step 2: Print macros ---${NC}"
    echo -e "    ${YELLOW}2)${NC} ${GREEN}Fans Control Macros${NC}                    ${WHITE}[needed by START_PRINT]${NC}"
    echo -e "    ${YELLOW}3)${NC} ${GREEN}Useful Macros (START_PRINT / END_PRINT)${NC}"
    echo -e "    ${YELLOW}4)${NC} ${GREEN}Save Z-Offset Macros${NC}"
    echo -e "    ${YELLOW}5)${NC} ${GREEN}M600 Filament Change Support${NC}"
    echo ""
    echo -e "  ${CYAN}--- Step 3: Leveling & calibration ---${NC}"
    echo -e "    ${YELLOW}6)${NC} ${GREEN}Klipper Adaptive Meshing & Purging (KAMP)${NC}"
    echo -e "    ${YELLOW}7)${NC} ${GREEN}Improved Shapers Calibrations${NC}"
    echo ""
    echo -e "  ${CYAN}--- Step 4: Web interface & camera ---${NC}"
    echo -e "    ${YELLOW}8)${NC} ${GREEN}Fluidd (install/update/repair — port 4408)${NC}"
    echo -e "    ${YELLOW}9)${NC} ${GREEN}Mainsail (install/update/repair — port 4409)${NC}"
    echo -e "   ${YELLOW}10)${NC} ${GREEN}Moonraker Timelapse${NC}"
    echo -e "   ${YELLOW}11)${NC} ${GREEN}Camera Support for Fluidd and Mainsail${NC}"
    echo -e "   ${YELLOW}12)${NC} ${GREEN}HelixScreen (touchscreen UI)${NC}"
    echo ""
    echo -e "  ${CYAN}--- Step 5: Remote access & notifications ---${NC}"
    echo -e "   ${YELLOW}13)${NC} ${GREEN}OctoEverywhere${NC}"
    echo -e "   ${YELLOW}14)${NC} ${GREEN}Mobileraker Companion${NC}"
    echo -e "   ${YELLOW}15)${NC} ${GREEN}Entware Package Manager${NC}"
    echo -e "   ${YELLOW}16)${NC} ${GREEN}Git Backup${NC}"
    echo ""
    echo -e "  ${WHITE}[Remove] Menu${NC}"
    echo -e "   ${YELLOW}17)${NC} ${GREEN}Remove a feature${NC}"
    echo ""
    echo -e "  ${WHITE}[Backup & Restore] Menu${NC}"
    echo -e "   ${YELLOW}18)${NC} ${GREEN}Backup Klipper configuration${NC}"
    echo -e "   ${YELLOW}19)${NC} ${GREEN}Restore Klipper configuration${NC}"
    echo ""
    echo -e "  ${WHITE}[Tools] Menu${NC}"
    echo -e "   ${YELLOW}20)${NC} ${GREEN}Restart Klipper${NC}"
    echo -e "   ${YELLOW}21)${NC} ${GREEN}Restart Moonraker${NC}"
    echo -e "   ${YELLOW}22)${NC} ${GREEN}Restart Nginx${NC}"
    echo -e "   ${YELLOW}23)${NC} ${GREEN}View Klipper log${NC}"
    echo -e "   ${YELLOW}24)${NC} ${GREEN}View Moonraker log${NC}"
    echo -e "   ${YELLOW}25)${NC} ${GREEN}Show installed features${NC}"
    echo ""
    echo -e "    ${YELLOW}0)${NC} ${RED}Exit${NC}"
    echo ""
printf "  \033[0;32mEnter choice:\033[0m "
    read choice
    handle_choice "$choice"
}

confirm_install() {
    echo ""
    printf "  This will install %s. Continue? [y/n]: " "$1"
    read confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]
}
handle_choice() {
    case "$1" in
        1)  confirm_install "Moonraker Extensions" && sh "$SCRIPTS_DIR/moonraker.sh" install ;;
        2)  confirm_install "Fans Control Macros" && sh "$SCRIPTS_DIR/fans.sh" install ;;
        3)  confirm_install "Useful Macros" && sh "$SCRIPTS_DIR/useful_macros.sh" install ;;
        4)  confirm_install "Save Z-Offset Macros" && sh "$SCRIPTS_DIR/z_offset.sh" install ;;
        5)  confirm_install "M600 Support" && sh "$SCRIPTS_DIR/m600.sh" install ;;
        6)  confirm_install "KAMP" && sh "$SCRIPTS_DIR/kamp.sh" install ;;
        7)  confirm_install "Improved Shapers Calibrations" && sh "$SCRIPTS_DIR/shapers.sh" install ;;
        8)  confirm_install "Fluidd" && sh "$SCRIPTS_DIR/fluidd.sh" install ;;
        9)  confirm_install "Mainsail" && sh "$SCRIPTS_DIR/mainsail.sh" install ;;
        10) confirm_install "Moonraker Timelapse" && sh "$SCRIPTS_DIR/timelapse.sh" install ;;
        11) sh "$SCRIPTS_DIR/camera.sh" install ;;
        12) sh "$SCRIPTS_DIR/helixscreen.sh" install ;;
        13) sh "$SCRIPTS_DIR/octoeverywhere.sh" install ;;
        14) sh "$SCRIPTS_DIR/mobileraker.sh" install ;;
        15) sh "$SCRIPTS_DIR/entware.sh" install ;;
        16) sh "$SCRIPTS_DIR/git_backup.sh" install ;;
        17) remove_menu ;;
        18) sh "$SCRIPTS_DIR/backup.sh" backup ;;
        19) sh "$SCRIPTS_DIR/backup.sh" restore ;;
        20) sh "$SCRIPTS_DIR/system.sh" restart_klipper ;;
        21) sh "$SCRIPTS_DIR/system.sh" restart_moonraker ;;
        22) sh "$SCRIPTS_DIR/system.sh" restart_nginx ;;
        23) tail -50 "$LOGS_DIR/klippy.log" | less ;;
        24) tail -50 "$LOGS_DIR/moonraker.log" | less ;;
        25) sh "$SCRIPTS_DIR/system.sh" show_installed ;;
        0)  echo ""; echo "Goodbye!"; echo ""; exit 0 ;;
        *)  echo -e "${RED}Invalid choice.${NC}"; sleep 1 ;;
    esac
    echo ""
    printf "Press Enter to return to menu..."
    read dummy
    main_menu
}

remove_menu() {
    print_header
    echo -e "  ${WHITE}[Remove] Menu${NC}"
    echo ""
    echo -e "    ${YELLOW}1)${NC}  ${GREEN}Moonraker Extensions${NC}"
    echo -e "    ${YELLOW}2)${NC}  ${GREEN}Fans Control Macros${NC}"
    echo -e "    ${YELLOW}3)${NC}  ${GREEN}Useful Macros${NC}"
    echo -e "    ${YELLOW}4)${NC}  ${GREEN}Save Z-Offset Macros${NC}"
    echo -e "    ${YELLOW}5)${NC}  ${GREEN}M600 Support${NC}"
    echo -e "    ${YELLOW}6)${NC}  ${GREEN}KAMP${NC}"
    echo -e "    ${YELLOW}7)${NC}  ${GREEN}Improved Shapers Calibrations${NC}"
    echo -e "    ${YELLOW}8)${NC}  ${GREEN}Restore stock Fluidd${NC}"
    echo -e "    ${YELLOW}9)${NC}  ${GREEN}Mainsail${NC}"
    echo -e "   ${YELLOW}10)${NC}  ${GREEN}Moonraker Timelapse${NC}"
    echo -e "   ${YELLOW}11)${NC}  ${GREEN}Camera Support for Fluidd and Mainsail${NC}"
    echo -e "   ${YELLOW}12)${NC}  ${GREEN}HelixScreen${NC}"
    echo -e "   ${YELLOW}13)${NC}  ${GREEN}Entware Package Manager${NC}"
    echo -e "    ${YELLOW}0)${NC}  ${RED}Back${NC}"
    echo ""
    printf "  ${GREEN}Enter choice:${NC} "
    read choice
    case "$choice" in
        1)  sh "$SCRIPTS_DIR/moonraker.sh" remove ;;
        2)  sh "$SCRIPTS_DIR/fans.sh" remove ;;
        3)  sh "$SCRIPTS_DIR/useful_macros.sh" remove ;;
        4)  sh "$SCRIPTS_DIR/z_offset.sh" remove ;;
        5)  sh "$SCRIPTS_DIR/m600.sh" remove ;;
        6)  sh "$SCRIPTS_DIR/kamp.sh" remove ;;
        7)  sh "$SCRIPTS_DIR/shapers.sh" remove ;;
        8)  sh "$SCRIPTS_DIR/fluidd.sh" remove ;;
        9)  sh "$SCRIPTS_DIR/mainsail.sh" remove ;;
        10) sh "$SCRIPTS_DIR/timelapse.sh" remove ;;
        11) sh "$SCRIPTS_DIR/camera.sh" remove ;;
        12) sh "$SCRIPTS_DIR/helixscreen.sh" remove ;;
        13) sh "$SCRIPTS_DIR/entware.sh" remove ;;
        0)  return ;;
        *)  echo -e "${RED}Invalid choice.${NC}" ;;
    esac
}


check_root
check_printer
main_menu
