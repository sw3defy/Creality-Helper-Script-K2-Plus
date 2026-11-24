"""Integrate verified Moonraker extension primitives; adoption test only."""
from pathlib import Path
import subprocess
from moonraker_candidates import prepare_config, prepare_module
from moonraker_service_guard import guard, api

CONFIG = Path("/usr/share/moonraker/moonraker.conf")
MODULE = Path("/usr/share/moonraker-env/lib/python3.9/site-packages/preprocess_cancellation.py")
ROOT = Path("/mnt/UDISK/helper-backups")

def preflight():
    guard()
    if list(ROOT.glob("moonraker-*/PENDING")):
        raise RuntimeError("Pending recovery journal; resolve before installation")
    changes = [(MODULE, prepare_module(MODULE.read_bytes())),
               (CONFIG, prepare_config(CONFIG.read_bytes()))]
    required = {"EXCLUDE_OBJECT_DEFINE", "EXCLUDE_OBJECT_START", "EXCLUDE_OBJECT_END"}
    if not required.issubset(api("/printer/gcode/help")):
        raise RuntimeError("Klipper object commands missing")
    return changes

def adoption_test():
    changes = preflight()
    if any(p.read_bytes() != data for p, data in changes):
        raise RuntimeError("Fresh activation not yet enabled")
    if api("/server/config")["config"]["file_manager"]["enable_object_processing"] is not True:
        raise RuntimeError("Effective object processing disabled")
    print("PASS: Existing correction eligible for adoption")
    print("PASS: No pending recovery journals")
    print("PASS: No file replacement or restart required")
    print("Existing changes remain user-owned; removal must not revert them")

if __name__ == "__main__":
    adoption_test()
