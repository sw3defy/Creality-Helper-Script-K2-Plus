"""Service recovery without requiring a working Moonraker API before restart."""
import subprocess
import time
from pathlib import Path
from moonraker_service_guard import guard, api, SERVICE

def recover_service(expected_processing, expected_service_bytes):
    if SERVICE.read_bytes() != expected_service_bytes:
        raise RuntimeError("Startup service changed; manual recovery required")
    if Path("/etc/rc.d/S56moonraker").resolve() != SERVICE:
        raise RuntimeError("Startup link changed")
    processes = []
    for path in Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            args = (path / "cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, ProcessLookupError):
            continue
        if b"/usr/share/moonraker/moonraker.py" in args:
            processes.append(path.name)
    if len(processes) > 1:
        raise RuntimeError("Multiple Moonraker processes; manual recovery required")
    action = "restart" if processes else "start"
    print("Moonraker service action:", action, flush=True)
    subprocess.run([str(SERVICE), action], check=True, timeout=60)
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        try:
            pid = guard()
            info = api("/server/info")
            if not info["warnings"] and api("/server/config")["config"]["file_manager"]["enable_object_processing"] is expected_processing:
                print("PASS: Service recovered; PID", pid)
                return pid
        except Exception:
            pass
        time.sleep(2)
    raise RuntimeError("Service recovery failed; retain pending journal and inspect logs")
