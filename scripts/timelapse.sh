#!/bin/sh
# timelapse.sh - Moonraker Timelapse for K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
TIMELAPSE_URL=https://github.com/mainsail-crew/moonraker-timelapse/archive/refs/heads/main.zip
TIMELAPSE_DIR=/mnt/UDISK/printer_data/timelapse
TIMELAPSE_COMPONENT=/usr/share/moonraker/components/timelapse.py

install_timelapse() {
    echo ""
    log_info "Installing Moonraker Timelapse..."
    echo ""

    if ! is_installed "moonraker_extensions"; then
        log_warn "Moonraker Extensions not installed. Installing now (required for timelapse)..."
        sh "$SCRIPT_DIR/scripts/moonraker.sh" install
    fi

    log_info "Downloading moonraker-timelapse..."
    python3 << PYEOF || { log_error "Download failed."; return 1; }
import urllib.request, zipfile, os
os.makedirs('/tmp/timelapse_extract', exist_ok=True)
print('Downloading moonraker-timelapse...')
urllib.request.urlretrieve('$TIMELAPSE_URL', '/tmp/timelapse.zip')
print('Extracting...')
with zipfile.ZipFile('/tmp/timelapse.zip', 'r') as z:
    z.extractall('/tmp/timelapse_extract/')
os.remove('/tmp/timelapse.zip')
print('Done')
PYEOF

    # Install the moonraker component
    cp /tmp/timelapse_extract/moonraker-timelapse-main/component/timelapse.py "$TIMELAPSE_COMPONENT"

    # Install the Klipper macro
    cp /tmp/timelapse_extract/moonraker-timelapse-main/klipper_macro/timelapse.cfg "$CONFIG_DIR/"

    rm -rf /tmp/timelapse.zip /tmp/timelapse_extract

    # Create timelapse output directory
    mkdir -p "$TIMELAPSE_DIR"

    # Add moonraker section
    add_moonraker_section "timelapse" "[timelapse]
output_path: /mnt/UDISK/printer_data/timelapse/
frame_path: /tmp/timelapse/
ffmpeg_binary_path: /usr/bin/ffmpeg"

    add_include_to_printer_cfg "timelapse.cfg"

    restart_moonraker
    restart_klipper

    mark_installed "moonraker_timelapse"
    echo ""
    log_success "Moonraker Timelapse installed!"
    log_info "Add TIMELAPSE_TAKE_FRAME to your layer change G-code in the slicer."
    log_info "Add TIMELAPSE_RENDER to your end G-code."
    log_info "Videos saved to: /mnt/UDISK/printer_data/timelapse/"
    echo ""
}

remove_timelapse() {
    echo ""
    log_info "Removing Moonraker Timelapse..."
    remove_moonraker_section "timelapse"
    remove_include_from_printer_cfg "timelapse.cfg"
    rm -f "$TIMELAPSE_COMPONENT"
    rm -f "$CONFIG_DIR/timelapse.cfg"
    restart_moonraker
    restart_klipper
    mark_removed "moonraker_timelapse"
    log_success "Moonraker Timelapse removed."
    echo ""
}

case "$1" in
    install) install_timelapse ;;
    remove)  remove_timelapse ;;
esac
