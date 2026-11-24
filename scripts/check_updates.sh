#!/bin/sh
# Read-only inventory. Never installs, restarts, patches, or modifies printer files.
# Run: sh /mnt/UDISK/helper-script/scripts/check_updates.sh
python3 - <<'PY'
import json
import os
from pathlib import Path
import urllib.request

CONFIG = Path('/mnt/UDISK/printer_data/config')
BASE = Path('/mnt/UDISK/helper-script')
FEATURES = BASE / '.installed'

def local_version(path):
    try:
        p = Path(path)
        if p.is_file():
            return p.read_text(errors='replace').strip()[:120] or 'empty'
    except (OSError, UnicodeError):
        pass
    return 'unknown'

def github_latest(repo):
    url = 'https://api.github.com/repos/{}/releases/latest'.format(repo)
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'K2Plus-Helper-ReadOnly-Update-Checker',
            'Accept': 'application/vnd.github+json'})
        with urllib.request.urlopen(req, timeout=8) as response:
            data = json.load(response)
        return data.get('tag_name') or 'unknown'
    except Exception:
        return 'unavailable (offline, rate limited, or no stable release)'

print('=== K2 PLUS READ-ONLY UPDATE AUDIT ===')
print('No changes will be made. Versions are NOT compatibility approvals.')
flags = set()
try:
    flags = set(FEATURES.read_text().splitlines())
except OSError:
    pass
print('\nFeature flags (not version evidence):')
for feature in sorted(flags):
    print('  ' + feature)

print('\nHelixScreen:')
try:
    info = json.loads(Path('/opt/helixscreen/release_info.json').read_text())
    print('  installed:', info.get('version', 'unknown'))
    print('  asset:', info.get('asset_name', 'unknown'))
except (OSError, ValueError):
    print('  installed: unknown')
print('  upstream stable:', github_latest('prestonbrown/helixscreen'))

print('\nWeb interfaces:')
for name, repo in [('Fluidd', 'fluidd-core/fluidd'), ('Mainsail', 'mainsail-crew/mainsail')]:
    folder = Path('/usr/share') / name.lower()
    print('  {}: present={}, version={}, upstream stable={}'.format(
        name, (folder / 'index.html').is_file(),
        next((v for v in (local_version(folder / '.helper-release-version'), local_version(folder / '.version'), local_version(folder / 'version')) if v not in ('unknown', 'empty')), 'unknown'), github_latest(repo)))

print('\nSource-based add-ons (installed commit not tracked by .installed):')
for name, repo in [
    ('KAMP', 'kyleisah/Klipper-Adaptive-Meshing-Purging'),
    ('Moonraker Timelapse', 'mainsail-crew/moonraker-timelapse')]:
    print('  {}: latest published release={}, installed revision=unknown'.format(
        name, github_latest(repo)))

print('\nCustom features (no independent upstream version):')
print('  Moonraker extensions, fans, useful macros, Z-offset, M600,')
print('  improved shapers, git backup: require source and firmware review.')
print('  Entware: opkg list-upgradable is informational; not run automatically.')
print('  OctoEverywhere/Mobileraker: verify actual installation before updates.')
print('\nCamera support: PROTECTED. Not inspected or modified.')
print('CFS, homing, endstops, motor_control.cfg: NOT modified.')
print('No automatic update, installation, patch, or reboot was performed.')
PY
