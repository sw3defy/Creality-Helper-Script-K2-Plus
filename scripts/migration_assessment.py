#!/usr/bin/env python3
"""Offline, read-only migration assessment. Never changes printer files.

Usage: python3 scripts/migration_assessment.py /path/to/copied/config
Only pass a directory containing copies, not the live printer config.
"""
from pathlib import Path
import hashlib
import re
import sys

REQUIRED = ("printer.cfg", "gcode_macro.cfg", "fans_control.cfg", "shapers_calibration.cfg", "moonraker.conf")
HEADER = re.compile(r"^\s*\[([^]]+)\]", re.I)
INCLUDE = re.compile(r"^\s*\[include\s+([^]]+)\]", re.I)
SENSITIVE = re.compile(r"password|secret|token|api[_-]?key|ssid|credential", re.I)

def scan(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1024 * 1024:
        return None
    data = path.read_bytes()
    sections, includes = set(), set()
    for line in data.decode("utf-8", "replace").splitlines():
        m = HEADER.match(line)
        if m:
            name = m.group(1).strip()
            if name.lower().startswith("include "):
                includes.add(name[8:].strip())
            elif not SENSITIVE.search(name):
                sections.add(name.upper())
    return hashlib.sha256(data).hexdigest(), sections, includes

def main(directory):
    base = Path(directory).resolve()
    if str(base).startswith("/mnt/UDISK") or str(base).startswith("/usr/share") or str(base).startswith("/rom"):
        raise ValueError("Refusing live printer paths; use an offline copy")
    if not base.is_dir():
        raise ValueError("Offline directory not found")
    print("OFFLINE MIGRATION ASSESSMENT — NO WRITES")
    files = {}
    for name in REQUIRED:
        p = base / name
        try:
            info = scan(p)
        except (OSError, ValueError):
            info = None
        files[name] = info
        print("{}: {}".format(name, "MISSING/UNREADABLE" if info is None else "SHA256=" + info[0]))
    printer = files["printer.cfg"]
    if not printer:
        print("BLOCKED: printer.cfg unavailable; cannot assess active includes")
        return 2
    active = printer[2]
    for name in ("fans_control.cfg", "shapers_calibration.cfg"):
        info = files[name]
        if name not in active:
            print("NOT DIRECTLY INCLUDED:", name, "(nested includes not evaluated)")
        elif not info:
            print("BLOCKED: included config missing:", name)
        else:
            stock = files["gcode_macro.cfg"]
            if not stock:
                print("BLOCKED: cannot compare stock macro names")
                continue
            collisions = sorted(stock[1] & info[1])
            for macro in collisions:
                if macro.startswith("GCODE_MACRO "):
                    print("COLLISION:", macro, "gcode_macro.cfg", name)
    moon = files["moonraker.conf"]
    if moon and "/usr/share/moonraker/moonraker.conf" in moon[2]:
        print("BLOCKED: user moonraker.conf includes stock; verify reverse include before migration")
    print("PLAN: no automatic edits, restarts, removals or migrations authorized.")
    print("PLAN: back up exact originals; verify ownership and runtime config; propose minimal changes for review.")
    return 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: migration_assessment.py OFFLINE_CONFIG_DIRECTORY", file=sys.stderr)
        sys.exit(2)
    try:
        sys.exit(main(sys.argv[1]))
    except (OSError, ValueError) as exc:
        print("BLOCKED:", exc, file=sys.stderr)
        sys.exit(2)
