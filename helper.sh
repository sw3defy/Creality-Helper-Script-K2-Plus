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
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_header() {
    clear
    echo ""
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${WHITE}   Creality K2 Plus Helper Script${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}   https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus${NC}"
    echo -e "${CYAN}======================================================${NC}"
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
    echo -e "  ${YELLOW}--- Step 1: Foundation (install first) ---${NC}"
    echo -e "    1) Moonraker Extensions & Update Manager  ${GREEN}[recommended first]${NC}"
    echo ""
    echo -e "  ${YELLOW}--- Step 2: Print macros ---${NC}"
    echo -e "    2) Fans Control Macros                    ${CYAN}[needed by START_PRINT]${NC}"
    echo "    3) Useful Macros (START_PRINT / END_PRINT)"
    echo "    4) Save Z-Offset Macros"
    echo "    5) M600 Filament Change Support"
    echo ""
    echo -e "  ${YELLOW}--- Step 3: Leveling & calibration ---${NC}"
    echo "    6) Klipper Adaptive Meshing & Purging (KAMP)"
    echo "    7) Improved Shapers Calibrations"
    echo ""
    echo -e "  ${YELLOW}--- Step 4: Web interface & camera ---${NC}"
    echo "    8) Fluidd (install/update/repair — port 4408)"
    echo "    9) Mainsail (install/update/repair — port 4409)"
    echo "   10) Moonraker Timelapse"
    echo ""
    echo -e "  ${YELLOW}--- Step 5: Remote access & notifications ---${NC}"
    echo "   12) Entware (package manager)"
    echo "   13) OctoEverywhere"
    echo "   14) Mobileraker Companion"
    echo "   15) Git Backup"
    echo ""
    echo -e "  ${WHITE}[Remove] Menu${NC}"
    echo "   16) Remove a feature"
    echo ""
    echo -e "  ${WHITE}[Backup & Restore] Menu${NC}"
    echo "   17) Backup Klipper configuration"
    echo "   18) Restore Klipper configuration"
    echo ""
    echo -e "  ${WHITE}[Tools] Menu${NC}"
    echo "   19) Restart Klipper"
    echo "   20) Restart Moonraker"
    echo "   21) Restart Nginx"
    echo "   22) View Klipper log"
    echo "   23) View Moonraker log"
    echo "   24) Show installed features"
    echo ""
    echo "    0) Exit"
    echo ""
    printf "  Enter choice: "
    read choice
    handle_choice "$choice"
}

handle_choice() {
    case "$1" in
        1)  sh "$SCRIPTS_DIR/moonraker.sh" install ;;
        2)  sh "$SCRIPTS_DIR/fans.sh" install ;;
        3)  sh "$SCRIPTS_DIR/useful_macros.sh" install ;;
        4)  sh "$SCRIPTS_DIR/z_offset.sh" install ;;
        5)  sh "$SCRIPTS_DIR/m600.sh" install ;;
        6)  sh "$SCRIPTS_DIR/kamp.sh" install ;;
        7)  sh "$SCRIPTS_DIR/shapers.sh" install ;;
        8)  sh "$SCRIPTS_DIR/fluidd.sh" install ;;
        9)  sh "$SCRIPTS_DIR/mainsail.sh" install ;;
        10) sh "$SCRIPTS_DIR/timelapse.sh" install ;;
        11) sh "$SCRIPTS_DIR/camera.sh" install ;;
        12) sh "$SCRIPTS_DIR/entware.sh" install ;;
        13) sh "$SCRIPTS_DIR/octoeverywhere.sh" install ;;
        14) sh "$SCRIPTS_DIR/mobileraker.sh" install ;;
        15) sh "$SCRIPTS_DIR/git_backup.sh" install ;;
        16) remove_menu ;;
        17) sh "$SCRIPTS_DIR/backup.sh" backup ;;
        18) sh "$SCRIPTS_DIR/backup.sh" restore ;;
        19) sh "$SCRIPTS_DIR/system.sh" restart_klipper ;;
        20) sh "$SCRIPTS_DIR/system.sh" restart_moonraker ;;
        21) sh "$SCRIPTS_DIR/system.sh" restart_nginx ;;
        22) tail -50 "$LOGS_DIR/klippy.log" | less ;;
        23) tail -50 "$LOGS_DIR/moonraker.log" | less ;;
        24) sh "$SCRIPTS_DIR/system.sh" show_installed ;;
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
    echo "    1) Moonraker Extensions"
    echo "    2) Fans Control Macros"
    echo "    3) Useful Macros"
    echo "    4) Save Z-Offset Macros"
    echo "    5) M600 Support"
    echo "    6) KAMP"
    echo "    7) Improved Shapers Calibrations"
    echo "    8) Fluidd"
    echo "    9) Mainsail"
    echo "   10) Moonraker Timelapse"
    echo "   11) Entware"
    echo "   13) OctoEverywhere"
    echo "   14) Mobileraker Companion"
    echo "   15) Git Backup"
    echo "    0) Back"
    echo ""
    printf "  Enter choice: "
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
        12) sh "$SCRIPTS_DIR/entware.sh" remove ;;
        13) sh "$SCRIPTS_DIR/octoeverywhere.sh" remove ;;
        14) sh "$SCRIPTS_DIR/mobileraker.sh" remove ;;
        15) sh "$SCRIPTS_DIR/git_backup.sh" remove ;;
        0)  return ;;
        *)  echo -e "${RED}Invalid choice.${NC}" ;;
    esac
}

check_root
check_printer
main_menu
