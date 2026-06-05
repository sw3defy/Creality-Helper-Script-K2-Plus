#!/bin/sh
# kamp.sh - Install/remove Klipper Adaptive Meshing & Purging for K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
KAMP_DIR=$CONFIG_DIR/KAMP
KAMP_URL=https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging/archive/refs/heads/main.zip

install_kamp() {
    echo ""
    log_info "Installing Klipper Adaptive Meshing & Purging (KAMP)..."
    echo ""

    if ! is_installed "moonraker_extensions"; then
        log_warn "Moonraker Extensions not installed. Installing now (required for KAMP)..."
        sh "$SCRIPT_DIR/scripts/moonraker.sh" install
    fi

    mkdir -p "$KAMP_DIR"

    log_info "Downloading KAMP..."
    python3 << 'PYEOF'
import urllib.request, zipfile, os, shutil, glob
print('Downloading KAMP...')
urllib.request.urlretrieve(
    'https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging/archive/refs/heads/main.zip',
    '/tmp/kamp.zip'
)
print('Extracting...')
with zipfile.ZipFile('/tmp/kamp.zip', 'r') as z:
    z.extractall('/tmp/kamp_extract/')
src = '/tmp/kamp_extract/Klipper-Adaptive-Meshing-Purging-main/Configuration/'
import os
os.makedirs('/mnt/UDISK/printer_data/config/KAMP', exist_ok=True)
for f in glob.glob(src + '*.cfg'):
    shutil.copy(f, '/mnt/UDISK/printer_data/config/KAMP/')
    print('Copied: ' + os.path.basename(f))
import shutil as sh
sh.rmtree('/tmp/kamp_extract', ignore_errors=True)
os.remove('/tmp/kamp.zip')
print('Done')
PYEOF

    # Write KAMP_Settings.cfg tuned for K2 Plus 350x350 bed
    cat > "$KAMP_DIR/KAMP_Settings.cfg" << 'EOF'
# KAMP Settings — K2 Plus (350x350mm bed)
[include ./Adaptive_Meshing.cfg]
[include ./Line_Purge.cfg]

[gcode_macro _KAMP_Settings]
variable_verbose_enable: True
variable_mesh_margin: 5
variable_fuzz_amount: 0
variable_probe_dock_enable: False
variable_attach_macro: 'Attach_Probe'
variable_detach_macro: 'Dock_Probe'
variable_purge_height: 0.8
variable_tip_distance: 3
variable_purge_margin: 10
variable_purge_amount: 30
variable_flow_rate: 12
variable_start_x: 10
variable_start_y: 10
variable_size: 15
variable_smart_park_height: 5
gcode:
EOF

    add_include_to_printer_cfg "KAMP/KAMP_Settings.cfg"

    # Ensure object processing is enabled in moonraker.conf
    if [ -f "$CONFIG_DIR/moonraker.conf" ]; then
        if ! grep -q "enable_object_processing: True" "$CONFIG_DIR/moonraker.conf"; then
            echo "" >> "$CONFIG_DIR/moonraker.conf"
            echo "[file_manager]" >> "$CONFIG_DIR/moonraker.conf"
            echo "enable_object_processing: True" >> "$CONFIG_DIR/moonraker.conf"
            restart_moonraker
        fi
    fi

    restart_klipper
    mark_installed "kamp"
    echo ""
    log_success "KAMP installed!"
    log_info "Add BED_MESH_CALIBRATE to your START_PRINT macro."
    log_info "Add LINE_PURGE after heating for a purge line at the print edge."
    echo ""
}

remove_kamp() {
    echo ""
    log_info "Removing KAMP..."
    remove_include_from_printer_cfg "KAMP/KAMP_Settings.cfg"
    rm -rf "$KAMP_DIR"
    restart_klipper
    mark_removed "kamp"
    log_success "KAMP removed."
    echo ""
}

case "$1" in
    install) install_kamp ;;
    remove)  remove_kamp ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
