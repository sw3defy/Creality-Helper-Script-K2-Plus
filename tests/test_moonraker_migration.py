#!/usr/bin/env python3
"""Offline Moonraker migration regression tests; no printer access."""
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/moonraker_migration_plan.py"
USER = "[file_manager]\n[update_manager fluidd]\n[timelapse]\n"
STOCK = "[server]\n[include /mnt/UDISK/printer_data/config/moonraker.conf]\n"
SERVICE = "CONF=/mnt/UDISK/printer_data/config/moonraker.conf\n"

def check(user=USER, stock=STOCK, service=SERVICE, expected=0, phrase="PLAN:"):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "moonraker.conf").write_text(user)
        (root / "stock_moonraker.conf").write_text(stock)
        (root / "S56moonraker").write_text(service)
        before = {p.name: p.read_bytes() for p in root.iterdir()}
        result = subprocess.run([sys.executable, str(SCRIPT), str(root)],
                                capture_output=True, text=True)
        after = {p.name: p.read_bytes() for p in root.iterdir()}
        assert result.returncode == expected, (result.stdout, result.stderr)
        assert phrase in result.stdout, (result.stdout, result.stderr)
        assert before == after, "Read-only planner changed a file"

check()
check(user=USER + "[include /usr/share/moonraker/moonraker.conf]\n",
      expected=2, phrase="Recursive")
check(user=USER + "[timelapse]\n", expected=2, phrase="Duplicate")
check(service="CONF=/usr/share/moonraker/moonraker.conf\n",
      expected=2, phrase="Service does not point")
check(user=USER + "[include /usr/share/moonraker/moonraker.conf]\n",
      stock="[server]\n", expected=2, phrase="User config includes stock")
print("PASS: Moonraker planner offline scenarios; no files modified")
