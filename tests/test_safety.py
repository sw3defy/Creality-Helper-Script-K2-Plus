#!/usr/bin/env python3
"""Offline safety regression checks. Run: python3 tests/test_safety.py"""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
scripts = sorted((root / "scripts").glob("*.sh")) + [root / "helper.sh"]
failures = []
for path in scripts:
    p = subprocess.run(["sh", "-n", str(path)], capture_output=True, text=True)
    if p.returncode:
        failures.append("{}: shell syntax: {}".format(path.name, p.stderr.strip()))

helper = (root / "helper.sh").read_text()
for old in ("\npatch_stock_configs\n", "\ninstall_rc_local_patch\n", "\ninstall_moonraker_include\n"):
    if old in helper:
        failures.append("helper.sh invokes unsafe automatic startup patch: " + old.strip())
if '27) sh "$SCRIPTS_DIR/moonraker_audit.sh"' not in helper:
    failures.append("Read-only Moonraker audit not available from menu")

guards = {
    "moonraker.sh": ["install_moonraker_extensions", "remove_moonraker_extensions"],
    "kamp.sh": ["install_kamp", "remove_kamp"],
    "timelapse.sh": ["install_timelapse", "remove_timelapse"],
    "m600.sh": ["install_m600", "remove_m600"],
    "fans.sh": ["install_fans", "remove_fans"],
    "useful_macros.sh": ["install_useful_macros", "remove_useful_macros"],
    "shapers.sh": ["install_shapers", "remove_shapers"],
    "z_offset.sh": ["install_z_offset", "remove_z_offset"],
}
for name, functions in guards.items():
    source = (root / "scripts" / name).read_text()
    for function in functions:
        pattern = r"(?m)^" + re.escape(function) + r"\(\) \{\s*log_error"
        if not re.search(pattern, source):
            failures.append("{}: missing fail-closed guard for {}".format(name, function))

for name in ("fluidd.sh", "mainsail.sh"):
    source = (root / "scripts" / name).read_text()
    if "scripts/web_ui_release.py" not in source:
        failures.append(name + ": missing staged web UI updater")

if failures:
    for failure in failures:
        print("FAIL:", failure)
    sys.exit(1)
print("PASS: {} shell scripts parsed; safety guards and read-only menu checks present".format(len(scripts)))
print("NOTE: Static checks do not validate firmware compatibility or hardware behavior.")
