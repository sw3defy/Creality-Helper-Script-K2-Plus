"""Controlled restart using the existing Creality service."""
import subprocess
import time
from moonraker_service_guard import guard, api, SERVICE

def restart_verified():
    old = guard()
    subprocess.run([str(SERVICE), "restart"], check=True, timeout=60)
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        try:
            new = guard()
            if new != old and api("/server/config")["config"]["file_manager"]["enable_object_processing"] is True:
                print("PASS: Moonraker restarted, PID {} -> {}".format(old, new))
                return new
        except Exception:
            pass
        time.sleep(2)
    raise RuntimeError("Service recovery not verified; stop and inspect logs")

if __name__ == "__main__":
    restart_verified()
