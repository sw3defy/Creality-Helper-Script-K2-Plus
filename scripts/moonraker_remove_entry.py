"""Production removal entrypoint for adopted installations only."""
from pathlib import Path
from moonraker_install import ROOT, CONFIG, MODULE
from moonraker_service_guard import guard, api
from moonraker_removal import unregister_adopted, active_dependency_guard

def preflight():
    guard()
    active_dependency_guard(api)

if __name__ == "__main__":
    unregister_adopted(ROOT, Path("/mnt/UDISK/helper-script/.installed"),
                       [CONFIG, MODULE], preflight)
