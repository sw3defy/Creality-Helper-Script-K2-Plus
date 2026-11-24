#!/usr/bin/env python3
"""Offline, read-only Moonraker configuration migration plan.

Supply a directory of COPIED files:
  moonraker.conf              active user config
  stock_moonraker.conf        /usr/share/moonraker/moonraker.conf
  S56moonraker                service startup script
Optional additional *.conf files must be in this directory.
Never edits or restarts the printer. Exit 2 means manual review required.
"""
import hashlib
import re
import sys
from pathlib import Path

INCLUDE = re.compile(r"^\s*\[include\s+([^\]]+)\]\s*(?:[#;].*)?$", re.I)
SECTION = re.compile(r"^\s*\[([^\]]+)\]\s*(?:[#;].*)?$")
CONF = re.compile(r"(?m)^\s*CONF\s*=\s*['\"]?([^\s'\"#]+)")
LIVE = ("/mnt/UDISK", "/usr/share", "/etc", "/rom", "/opt")
MAX_SIZE = 1024 * 1024

def safe_read(path, base):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_SIZE:
        raise ValueError("Missing, linked or oversized offline file: " + path.name)
    if not path.resolve().is_relative_to(base):
        raise ValueError("File escapes offline directory: " + path.name)
    raw = path.read_bytes()
    return raw.decode("utf-8", "replace"), hashlib.sha256(raw).hexdigest()

def sections_and_includes(text):
    sections, includes = [], []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith(("#", ";")):
            continue
        match = INCLUDE.match(line)
        if match:
            includes.append(match.group(1).strip())
            continue
        match = SECTION.match(line)
        if match:
            sections.append(match.group(1).strip().lower())
    return sections, includes

def main(folder):
    original = Path(folder)
    base = original.resolve()
    if original.is_symlink() or not base.is_dir() or any(
        str(base) == prefix or str(base).startswith(prefix + "/") for prefix in LIVE
    ):
        raise ValueError("Refusing live printer paths; use an offline copy")
    print("READ-ONLY MOONRAKER MIGRATION PLAN — NO WRITES")
    paths = {
        "user": base / "moonraker.conf",
        "stock": base / "stock_moonraker.conf",
        "service": base / "S56moonraker",
    }
    data = {}
    for key, path in paths.items():
        value, digest = safe_read(path, base)
        data[key] = value
        print("{}: SHA256={}".format(path.name, digest))
    service = CONF.search(data["service"])
    if not service:
        print("BLOCKED: Cannot identify service CONF path")
        return 2
    conf_path = service.group(1)
    print("Service CONF:", conf_path)
    if conf_path != "/mnt/UDISK/printer_data/config/moonraker.conf":
        print("BLOCKED: Service does not point to the verified user configuration")
        return 2
    sections = {}
    includes = {}
    for key in ("user", "stock"):
        sections[key], includes[key] = sections_and_includes(data[key])
        print("{} sections: {}".format(key, ", ".join(sections[key]) or "(none)"))
        print("{} includes: {}".format(key, ", ".join(includes[key]) or "(none)"))
    user_path = "/mnt/UDISK/printer_data/config/moonraker.conf"
    stock_path = "/usr/share/moonraker/moonraker.conf"
    if stock_path in includes["user"] and user_path in includes["stock"]:
        print("BLOCKED: Recursive stock/user includes")
        return 2
    if stock_path in includes["user"]:
        print("BLOCKED: User config includes stock; review include topology")
        return 2
    if len(sections["user"]) != len(set(sections["user"])):
        print("BLOCKED: Duplicate sections in user config")
        return 2
    if len(sections["stock"]) != len(set(sections["stock"])):
        print("BLOCKED: Duplicate sections in stock config")
        return 2
    for section in ("file_manager", "timelapse"):
        print("{}: {}".format(section, "present — preserve" if section in sections["user"] else "absent — do not assume"))
    managers = [s for s in sections["user"] if s == "update_manager" or s.startswith("update_manager ")]
    print("Update Manager sections: {}".format(", ".join(managers) or "(none)"))
    if user_path not in includes["stock"]:
        print("REVIEW: Stock config does not directly include user config")
    print("PLAN: Preserve active user config, stock config, and service without edits.")
    print("PLAN: No reverse includes, no section deletion, no restart, no automatic migration.")
    print("PLAN: Any new Update Manager section requires a separately reviewed minimal diff,")
    print("      a verified ownership record, off-printer backup and tested rollback.")
    return 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: moonraker_migration_plan.py OFFLINE_COPY_DIRECTORY", file=sys.stderr)
        sys.exit(2)
    try:
        sys.exit(main(sys.argv[1]))
    except (OSError, ValueError) as exc:
        print("BLOCKED:", exc, file=sys.stderr)
        sys.exit(2)
