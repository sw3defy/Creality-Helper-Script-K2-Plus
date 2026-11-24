#!/bin/sh
# Install/update the maintenance helper only; never install add-ons.
set -eu
BASE=/mnt/UDISK
DEST=$BASE/helper-script
REF=maintenance/2026-11-safe-update-audit
URL=https://github.com/sw3defy/Creality-Helper-Script-K2-Plus.git
[ "$(id -u)" = 0 ] || { echo "Run as root"; exit 1; }
[ -f "$BASE/printer_data/config/printer.cfg" ] || { echo "K2 Plus configuration not found"; exit 1; }
command -v git >/dev/null || { echo "git is required; existing installation unchanged"; exit 1; }
[ ! -L "$DEST" ] || { echo "Unexpected helper symlink; aborting"; exit 1; }
WORK=$(mktemp -d "$BASE/.helper-update.XXXXXX")
BACKUP="$BASE/helper-script.backup.$(date +%Y%m%d-%H%M%S)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
git clone --depth 1 --single-branch --branch "$REF" "$URL" "$WORK/new"
for f in helper.sh scripts/system.sh scripts/check_updates.sh scripts/moonraker_audit.sh; do
    [ -f "$WORK/new/$f" ] || exit 1
    sh -n "$WORK/new/$f"
done
# Preserve all existing local files, including installation records and local assets.
# Overlay only files tracked in the new checkout; never copy its .git metadata.
mkdir "$WORK/staged"
if [ -d "$DEST" ]; then cp -a "$DEST/." "$WORK/staged/"; fi
(cd "$WORK/new" && git archive HEAD) > "$WORK/source.tar"
tar -xf "$WORK/source.tar" -C "$WORK/staged"
if [ -f "$DEST/.installed" ]; then cp -p "$DEST/.installed" "$WORK/staged/.installed"; fi
# A copied old Git checkout must not advertise the new files as the old revision.
if [ -e "$WORK/staged/.git" ]; then mv "$WORK/staged/.git" "$WORK/old-git"; fi
git -C "$WORK/new" rev-parse HEAD > "$WORK/staged/.helper-source-commit"
[ ! -e "$BACKUP" ] || exit 1
if [ -d "$DEST" ]; then mv "$DEST" "$BACKUP"; fi
if ! mv "$WORK/staged" "$DEST"; then
    if [ -d "$BACKUP" ]; then mv "$BACKUP" "$DEST"; fi
    exit 1
fi
echo "Maintenance Helper Script installed."
echo "Previous installation (if present): $BACKUP"
echo "No add-ons installed, no services restarted."
echo "Start: sh $DEST/helper.sh"
