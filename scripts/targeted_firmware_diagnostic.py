#!/usr/bin/env python3
"""Read-only targeted diagnostic for K2 Plus macro and Moonraker topology."""
from pathlib import Path
import re
import sys

ROOT = Path("/mnt/UDISK/printer_data/config")
MACROS = {"M106", "M107", "AUTOTUNE_SHAPERS"}
SENSITIVE = re.compile(r"password|passwd|secret|token|api[_-]?key|credential|ssid|wifi|wpa|authorization|private|https?://", re.I)
HEADER = re.compile(r"^\s*\[([^]]+)\]\s*(?:[#;].*)?$")
INCLUDE = re.compile(r"^\s*\[include\s+([^]]+)\]", re.I)
MAX_BYTES = 1024 * 1024

def safe_lines(path):
    try:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
            return []
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []

def redact(line):
    if SENSITIVE.search(line):
        return "[REDACTED: possible secret or URL]"
    return line[:240]

def macro_report():
    print("### Targeted macro definitions")
    for name in ("printer.cfg", "gcode_macro.cfg", "fans_control.cfg", "shapers_calibration.cfg"):
        path = ROOT / name
        print("\nFILE:", path, "FOUND" if path.is_file() else "MISSING")
        lines = safe_lines(path)
        if not lines:
            continue
        for i, line in enumerate(lines):
            m = HEADER.match(line)
            if not m or not m.group(1).lower().startswith("gcode_macro "):
                continue
            macro = m.group(1)[12:].strip().upper()
            if macro not in MACROS:
                continue
            print("MACRO:", macro, "line", i + 1)
            end = next((j for j in range(i + 1, len(lines)) if HEADER.match(lines[j])), len(lines))
            for j in range(i, min(end, i + 100)):
                print("{:04d}: {}".format(j + 1, redact(lines[j])))
            if end - i > 100:
                print("[TRUNCATED SECTION]")

def moonraker_report():
    print("\n### Moonraker startup references (read-only)")
    paths = [
        Path("/etc/rc.d/S56moonraker"),
        Path("/etc/init.d/S56moonraker"),
        Path("/usr/share/moonraker/moonraker.conf"),
        ROOT / "moonraker.conf",
    ]
    for path in paths:
        lines = safe_lines(path)
        print("\nFILE:", path, "FOUND" if path.is_file() else "MISSING")
        for i, line in enumerate(lines):
            if re.search(r"moonraker\.conf|moonraker\.py|CONF=|\[include\s|\[file_manager\]|\[timelapse\]|\[update_manager", line, re.I):
                print("{:04d}: {}".format(i + 1, redact(line)))
    print("\nRuntime process command lines are intentionally not collected.")
    print("Startup configuration cannot be conclusively established from these references alone.")

if __name__ == "__main__":
    print("K2 Plus targeted diagnostic — READ ONLY; Python", sys.version.split()[0])
    print("Review output for sensitive information before sharing.")
    macro_report()
    moonraker_report()
    print("\nEND")
