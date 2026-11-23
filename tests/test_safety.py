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
if '28) python3 "$SCRIPTS_DIR/firmware_inspector.py"' not in helper:
    failures.append("Firmware Inspector not available from menu")
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
    "helixscreen.sh": ["install_helixscreen", "remove_helixscreen"],

    "entware.sh": ["install_entware"],
    "backup.sh": ["restore_config"],
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

inspector = (root / "scripts" / "firmware_inspector.py").read_text()
for marker in ("BACKUP.match(name)", "Active Klipper include graph", "COLLISION:", 'walk("printer.cfg")'):
    if marker not in inspector:
        failures.append("Firmware Inspector missing static safety feature: " + marker)
if "recommended first" in helper or "needed by START_PRINT" in helper:
    failures.append("Menu still recommends blocked installation paths")
for label in ("Moonraker Extensions & Update Manager", "Fans Control Macros", "Useful Macros"):
    if label not in helper:
        failures.append("Menu missing feature label: " + label)
p = subprocess.run([sys.executable, "-m", "py_compile", str(root / "scripts" / "firmware_inspector.py")], capture_output=True, text=True)
if p.returncode:
    failures.append("Firmware Inspector syntax: " + p.stderr.strip())

assessment = root / "scripts" / "migration_assessment.py"
p = subprocess.run([sys.executable, "-m", "py_compile", str(assessment)], capture_output=True, text=True)
if p.returncode:
    failures.append("Migration assessment syntax: " + p.stderr.strip())
source = assessment.read_text()
for marker in ("OFFLINE MIGRATION ASSESSMENT", "Refusing live printer paths", "COLLISION:", "no automatic edits"):
    if marker not in source:
        failures.append("Migration assessment missing safety marker: " + marker)

moonraker_installer = (root / "scripts" / "moonraker.sh").read_text()
for forbidden in ("patch_moonraker_startup", "unpatch_moonraker_startup", "restart_moonraker", "sed -i", "mv \"$MOONRAKER_CONF\"", "add_moonraker_section"):
    if forbidden in moonraker_installer:
        failures.append("Moonraker installer still contains legacy mutation: " + forbidden)
if "return 1" not in moonraker_installer:
    failures.append("Moonraker installer must fail closed")

system_source = (root / "scripts" / "system.sh").read_text()
restart_body = system_source.split("restart_moonraker() {", 1)[1].split("\n}\n", 1)[0]
for forbidden in ("kill \"$pid\"", "/etc/init.d/moonraker start", "/etc/rc.d/S56moonraker restart"):
    if forbidden in restart_body:
        failures.append("Moonraker restart has unverified mutation: " + forbidden)
if "return 1" not in restart_body:
    failures.append("Moonraker restart must fail closed until validated")

helix = (root / "scripts" / "helixscreen.sh").read_text()
for forbidden in ("urlopen(", "http://", "sh \"$HELIX_INSTALL\" --update", "reboot\n", "rm -rf"):
    if forbidden in helix:
        failures.append("HelixScreen installer contains unverified mutation: " + forbidden)

# Camera fix is an explicitly preserved working feature. Do not block it
# while auditing unrelated installers or accidentally remove its menu route.
camera_source = (root / "scripts" / "camera.sh").read_text()
camera_install = camera_source.split("install_camera() {", 1)[1].split("\nremove_camera() {", 1)[0]
for required in ("go2rtc", "camera_watchdog.py", "nginx_go2rtc.py",
                 "server/webcams/item", "mark_installed \"camera_support\""):
    if required not in camera_install:
        failures.append("Existing camera installation missing: " + required)
if re.search(r"install_camera\(\) \{\s*log_error", camera_source):
    failures.append("Working camera installer was unexpectedly blocked")
if '11) sh "$SCRIPTS_DIR/camera.sh" install' not in helper:
    failures.append("Camera install menu route missing")
if '11) sh "$SCRIPTS_DIR/camera.sh" remove' not in helper:
    failures.append("Camera removal menu route missing")
if "Camera Support for Fluidd and Mainsail [BLOCKED]" in helper:
    failures.append("Working camera feature incorrectly labeled blocked")

updater = (root / "scripts" / "web_ui_release.py").read_text()
for marker in ("enableCamera", "enableMainsailCams", "go2rtc_keepalive",
               "preserve_camera_scripts", "extract_camera_scripts"):
    if marker not in updater:
        failures.append("Web UI updater does not preserve camera customization: " + marker)

# Verified single-instance recovery: prevent reintroduction of startup hijacking.
recovery_doc = root / "docs" / "moonraker-duplicate-process-recovery.md"
if not recovery_doc.is_file():
    failures.append("Missing verified Moonraker duplicate-process recovery documentation")
else:
    recovery_text = recovery_doc.read_text()
    for marker in ("S56moonraker -> ../init.d/moonraker", "procd", "normal OS reboot", "HelixScreen", "Mainsail", "Fluidd", "fail closed"):
        if marker not in recovery_text:
            failures.append("Moonraker recovery documentation missing: " + marker)

for name in ("moonraker.sh", "system.sh"):
    source = (root / "scripts" / name).read_text()
    if name == "moonraker.sh":
        for marker in ("No service scripts", "return 1"):
            if marker not in source:
                failures.append("Moonraker installer lacks startup protection: " + marker)
    else:
        for function_name in ("patch_moonraker_startup", "unpatch_moonraker_startup"):
            match = re.search(r"(?ms)^" + function_name + r"\(\) \{(.*?)^\}", source)
            if not match or "return 1" not in match.group(1):
                failures.append("Unsafe Moonraker startup helper not blocked: " + function_name)

moonraker_audit = (root / "scripts" / "moonraker_audit.sh").read_text()
for marker in ('readlink "$RC"', 'ps | grep', 'ubus call service list', 'canonical Moonraker startup symlink'):
    if marker not in moonraker_audit:
        failures.append("Read-only Moonraker audit missing: " + marker)
for forbidden in ('ln -s ', 'rm /etc/rc.d/', 'kill -', '/etc/init.d/moonraker restart'):
    if forbidden in moonraker_audit:
        failures.append("Moonraker audit must remain read-only: " + forbidden)

# Preserve the working camera installer; legacy broad-regex removal stays blocked.
camera_remove = camera_source.split("remove_camera() {", 1)[1]
if not re.search(r'(?m)^\s*log_error "Camera removal is blocked', camera_remove):
    failures.append("Legacy camera removal is not explicitly blocked")
if 'Existing go2rtc, nginx, Mainsail, Fluidd' not in camera_remove:
    failures.append("Camera removal does not document preservation boundary")

# Fluidd removal must not falsely report success while leaving files in place.
fluidd_source = (root / "scripts" / "fluidd.sh").read_text()
fluidd_remove = fluidd_source.split("remove_fluidd() {", 1)[1].split("status_fluidd() {", 1)[0]
if not re.search(r'(?m)^\s*log_error "Fluidd removal/stock restoration is blocked', fluidd_remove):
    failures.append("Fluidd removal must fail closed")
if not re.search(r'(?m)^\s*return 1', fluidd_remove):
    failures.append("Fluidd removal lacks early return")

if failures:
    for failure in failures:
        print("FAIL:", failure)
    sys.exit(1)
print("PASS: {} shell scripts parsed; safety guards and read-only menu checks present".format(len(scripts)))
print("NOTE: Static checks do not validate firmware compatibility or hardware behavior.")
