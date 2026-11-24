"""Read-only live Moonraker service guard."""
import json
import urllib.request
from pathlib import Path

BASE = "http://127.0.0.1:7125"
CONFIG = "/usr/share/moonraker/moonraker.conf"
SERVICE = Path("/etc/init.d/moonraker")

def api(path):
    with urllib.request.urlopen(BASE + path, timeout=10) as r:
        return json.load(r)["result"]

def guard():
    if not SERVICE.is_file() or Path("/etc/rc.d/S56moonraker").resolve() != SERVICE:
        raise RuntimeError("Unexpected startup service")
    processes = []
    for p in Path("/proc").iterdir():
        if not p.name.isdigit():
            continue
        try:
            args = (p / "cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, ProcessLookupError):
            continue
        if b"/usr/share/moonraker/moonraker.py" in args:
            processes.append((p.name, args))
    if len(processes) != 1:
        raise RuntimeError("Expected exactly one Moonraker process")
    pid, args = processes[0]
    if b"-c" not in args or args[args.index(b"-c")+1] != CONFIG.encode():
        raise RuntimeError("Unexpected active configuration")
    info = api("/server/info")
    if not info["klippy_connected"] or info["klippy_state"] != "ready" or info["failed_components"] or "update_manager" in info["components"]:
        raise RuntimeError("Moonraker health or core protection failed")
    state = api("/printer/objects/query?print_stats")["status"]["print_stats"]["state"]
    if state not in ("standby", "complete", "cancelled") or api("/server/job_queue/status")["queued_jobs"]:
        raise RuntimeError("Printer must be idle with empty queue")
    return pid

if __name__ == "__main__":
    print("PASS: Canonical Moonraker service, healthy idle printer, empty queue, native updater disabled; PID", guard())
