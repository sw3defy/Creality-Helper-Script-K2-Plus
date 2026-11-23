#!/usr/bin/env python3
"""Read-only K2 Plus firmware inspector. Output goes to stdout only.

Run from SSH: python3 /mnt/UDISK/helper-script/scripts/firmware_inspector.py > /tmp/k2-inspection.txt
Inspect the output before sharing. No secrets, network calls, or printer writes.
"""
import hashlib
import os
from pathlib import Path
import re
import sys

STOCK = Path("/rom/usr/share/klipper/config")
ACTIVE = Path("/mnt/UDISK/printer_data/config")
SHARE = Path("/usr/share/klipper/config")
MAX_BYTES = 2 * 1024 * 1024
CONFIG_EXTENSIONS = {".cfg", ".conf"}
SAFE_NAME = re.compile(r"^[a-zA-Z0-9_.-]+$")
SENSITIVE = re.compile(r"password|passwd|secret|token|api[_-]?key|credential|ssid|wifi|wpa|authorization|private", re.I)
SECTION = re.compile(r"^\s*\[([^\]]+)\]\s*(?:[#;].*)?$")
INCLUDE = re.compile(r"^\s*\[include\s+([^\]]+)\]", re.I)

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            block = handle.read(65536)
            if not block:
                break
            h.update(block)
    return h.hexdigest()[:16]

def inventory(base, title):
    print("\n### " + title)
    if not base.is_dir():
        print("NOT FOUND:", base)
        return {}
    result = {}
    for directory, dirs, files in os.walk(str(base), followlinks=False):
        dirs[:] = sorted(d for d in dirs if not (Path(directory) / d).is_symlink())
        for name in sorted(files):
            path = Path(directory) / name
            relative = path.relative_to(base)
            if path.is_symlink() or path.suffix.lower() not in CONFIG_EXTENSIONS:
                continue
            if any(not SAFE_NAME.fullmatch(part) for part in relative.parts):
                continue
            if SENSITIVE.search(str(relative)):
                continue
            try:
                if path.stat().st_size > MAX_BYTES:
                    print("SKIP large file:", relative)
                    continue
                data = path.read_text(encoding="utf-8", errors="replace")
                sections = []
                includes = []
                for line in data.splitlines():
                    match = SECTION.match(line)
                    if match:
                        value = match.group(1)
                        if SENSITIVE.search(value):
                            continue
                        if value.lower().startswith("include "):
                            includes.append(value[8:].strip())
                        elif value.lower().startswith(("gcode_macro ", "delayed_gcode ", "file_manager", "update_manager", "timelapse")):
                            sections.append(value)
                result[str(relative)] = (digest(path), sections, includes)
                print("{} sha256[:16]={}".format(relative, result[str(relative)][0]))
                for section in sections:
                    print("  SECTION:", section)
                for inc in includes:
                    if not SENSITIVE.search(inc):
                        print("  INCLUDE:", inc)
            except (OSError, ValueError) as exc:
                print("SKIP unreadable:", relative, type(exc).__name__)
    return result

def main():
    print("K2 PLUS FIRMWARE INSPECTOR — READ ONLY")
    print("Python:", sys.version.split()[0])
    print("No file contents, credentials, or IP addresses are collected.")
    stock = inventory(STOCK, "Stock ROM Klipper config")
    share = inventory(SHARE, "Installed share Klipper config")
    active = inventory(ACTIVE, "Active UDISK config")
    print("\n### Same-relative-path comparisons (active vs ROM)")
    for name in sorted(set(active) & set(stock)):
        print("{}: {}".format(name, "IDENTICAL" if active[name][0] == stock[name][0] else "DIFFERENT"))
    print("\n### Same-relative-path comparisons (active vs share)")
    for name in sorted(set(active) & set(share)):
        print("{}: {}".format(name, "IDENTICAL" if active[name][0] == share[name][0] else "DIFFERENT"))
    print("\nEND — inspect this report before sharing.")

if __name__ == "__main__":
    main()
