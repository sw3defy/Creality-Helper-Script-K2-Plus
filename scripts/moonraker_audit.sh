#!/bin/sh
# Read-only Moonraker configuration topology check.
# Never edits service files, config files, or camera routes.
STOCK=/usr/share/moonraker/moonraker.conf
USER=/mnt/UDISK/printer_data/config/moonraker.conf
RC=/etc/rc.d/S56moonraker
echo "Moonraker configuration audit (read-only)"
echo "-----------------------------------------"
for f in "$RC" "$STOCK" "$USER"; do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
    else
        echo "MISSING: $f"
    fi
done
if [ -f "$RC" ]; then
    echo "Service configuration references:"
    grep -nE 'CONF=|moonraker.conf' "$RC" || :
fi
for f in "$STOCK" "$USER"; do
    if [ -f "$f" ]; then
        echo "Includes and relevant sections in $f:"
        grep -nE '^\\[include |^\\[file_manager\\]|^\\[timelapse\\]|^\\[update_manager' "$f" || :
    fi
done
if [ -f "$STOCK" ] && [ -f "$USER" ]; then
    if grep -Fq "[include $USER]" "$STOCK" && grep -Fq "[include $STOCK]" "$USER"; then
        echo "ERROR: Recursive Moonraker includes detected."
        exit 2
    fi
fi
echo
echo "OpenWrt service topology:"
if [ -L "$RC" ]; then
    target=$(readlink "$RC")
    echo "Startup symlink target: $target"
    if [ "$target" = "../init.d/moonraker" ]; then
        echo "OK: canonical Moonraker startup symlink"
    else
        echo "WARNING: unexpected Moonraker startup symlink target"
    fi
elif [ -f "$RC" ]; then
    echo "WARNING: startup entry is a regular file, not the canonical service symlink"
else
    echo "WARNING: Moonraker startup entry missing"
fi
if [ -f /etc/init.d/moonraker ]; then
    grep -n '^CONF=' /etc/init.d/moonraker || :
fi
echo
echo "Moonraker process inventory:"
ps | grep '[m]oonraker.py' || :
echo
echo "Procd Moonraker registration:"
if command -v ubus >/dev/null 2>&1; then
    ubus call service list '{"name":"moonraker","verbose":true}' || :
else
    echo "ubus unavailable"
fi
echo
echo "No files were modified. Review output before installing extensions."
