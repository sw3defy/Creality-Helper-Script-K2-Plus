#!/bin/sh
# Creality K2 Plus Helper Script
# https://github.com/sw3defy/Creality-Helper-Script-Wiki-K2-Plus
# Compatible with: Creality K2 Plus, K2 Plus Combo
# OS: Tina 5.0 / OpenWrt 21.02

SCRIPT_DIR=/mnt/UDISK/helper-script
SCRIPTS_DIR=$SCRIPT_DIR/scripts
FILES_DIR=$SCRIPT_DIR/files
PRINTER_DATA=/mnt/UDISK/printer_data
CONFIG_DIR=$PRINTER_DATA/config
LOGS_DIR=$PRINTER_DATA/logs

# Colors
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
        echo "Make sure the printer has booted fully before running this script."
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
    echo -e "    9) Mainsail (install/update/repair — port 4409)"
    echo "   10) Moonraker Timelapse"
    echo ""
    echo -e "  ${YELLOW}--- Step 5: Remote access & notifications ---${NC}"
    echo "   11) Entware (package manager)
   12) OctoEverywhere"
    echo "   13) Mobileraker Companion"
    echo "   14) Git Backup"
    echo ""
    echo -e "  ${WHITE}[Remove] Menu${NC}"
    echo "   15) Remove a feature"
    echo ""
    echo -e "  ${WHITE}[Backup & Restore] Menu${NC}"
    echo "   16) Backup Klipper configuration"
    echo "   17) Restore Klipper configuration"
    echo ""
    echo -e "  ${WHITE}[Tools] Menu${NC}"
    echo "   18) Restart Klipper"
    echo "   19) Restart Moonraker"
    echo "   20) Restart Nginx"
    echo "   21) View Klipper log"
    echo "   22) View Moonraker log"
    echo "   23) Show installed features"
    echo ""
    echo "    0) Exit"
    echo ""
    printf "  Enter choice: "
    read choice
    handle_choice "$choice"
}

handle_choice() {
    case "$1" in
        # Step 1 — Foundation
        1)  sh "$SCRIPTS_DIR/moonraker.sh" install ;;
        # Step 2 — Print macros (fans before useful_macros — chamber refs)
        2)  sh "$SCRIPTS_DIR/fans.sh" install ;;
        3)  sh "$SCRIPTS_DIR/useful_macros.sh" install ;;
        4)  sh "$SCRIPTS_DIR/z_offset.sh" install ;;
        5)  sh "$SCRIPTS_DIR/m600.sh" install ;;
        # Step 3 — Leveling & calibration
        6)  sh "$SCRIPTS_DIR/kamp.sh" install ;;
        7)  sh "$SCRIPTS_DIR/shapers.sh" install ;;
        # Step 4 — Web interface & camera
        8)  sh "$SCRIPTS_DIR/fluidd.sh" install ;;
        9)  sh "$SCRIPTS_DIR/mainsail.sh" install ;;
        10) sh "$SCRIPTS_DIR/timelapse.sh" install ;;
        # Step 5 — Remote access
        11) sh "$SCRIPTS_DIR/entware.sh" install ;;
        12) sh "$SCRIPTS_DIR/octoeverywhere.sh" install ;;
        13) sh "$SCRIPTS_DIR/mobileraker.sh" install ;;
        14) sh "$SCRIPTS_DIR/git_backup.sh" install ;;
        # Other menus
        15) remove_menu ;;
        16) sh "$SCRIPTS_DIR/backup.sh" backup ;;
        17) sh "$SCRIPTS_DIR/backup.sh" restore ;;
        18) sh "$SCRIPTS_DIR/system.sh" restart_klipper ;;
        19) sh "$SCRIPTS_DIR/system.sh" restart_moonraker ;;
        20) sh "$SCRIPTS_DIR/system.sh" restart_nginx ;;
        21) tail -50 "$LOGS_DIR/klippy.log" | less ;;
        22) tail -50 "$LOGS_DIR/moonraker.log" | less ;;
        23) sh "$SCRIPTS_DIR/system.sh" show_installed ;;
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
    echo -e "    9) Mainsail (install/update/repair — port 4409)"
    echo "   10) Moonraker Timelapse"
    echo "   11) Entware (package manager)
   12) OctoEverywhere"
    echo "   13) Mobileraker Companion"
    echo "   14) Git Backup"
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
        11) sh "$SCRIPTS_DIR/entware.sh" remove ;;
        12) sh "$SCRIPTS_DIR/octoeverywhere.sh" remove ;;
        13) sh "$SCRIPTS_DIR/mobileraker.sh" remove ;;
        14) sh "$SCRIPTS_DIR/git_backup.sh" remove ;;
        0)  return ;;
        *)  echo -e "${RED}Invalid choice.${NC}" ;;
    esac
}

# Entry point
check_root
check_printer
main_menu
