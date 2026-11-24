#!/usr/bin/env python3
"""Offline candidate preparation for the verified K2 Moonraker correction."""
import hashlib
import re
import sys
from pathlib import Path

ORIGINAL = "7b6234ad164043d443aae64cfef911ed8dcdbaceab6331ac1417fc0d3d5c6f61"
CORRECTED = "ef07606aafc7d2188cda29a207d4950cd582fa56679c6eec666e616450dab4e4"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def prepare_module(data):
    if digest(data) == CORRECTED:
        return data
    if digest(data) != ORIGINAL:
        raise RuntimeError("Unknown preprocessor revision; refusing modification")
    for old, new, count in (
        (b"DEFINE_OBJECT", b"EXCLUDE_OBJECT_DEFINE", 2),
        (b"START_CURRENT_OBJECT", b"EXCLUDE_OBJECT_START", 1),
        (b"END_CURRENT_OBJECT", b"EXCLUDE_OBJECT_END", 1),
    ):
        data, actual = re.subn(rb"\b" + old + rb"\b", new, data)
        if actual != count:
            raise RuntimeError("Unexpected replacement count")
    if digest(data) != CORRECTED:
        raise RuntimeError("Candidate fingerprint mismatch")
    compile(data, "preprocess_cancellation.py", "exec")
    return data

def prepare_config(data):
    section = None
    matches = []
    lines = data.splitlines(keepends=True)
    for i, line in enumerate(lines):
        header = re.match(rb"^\s*\[([^\]]+)\]", line)
        if header:
            section = header.group(1)
        if section == b"file_manager" and re.match(rb"^\s*enable_object_processing\s*:", line):
            matches.append(i)
    if len(matches) != 1:
        raise RuntimeError("Expected exactly one active file_manager setting")
    i = matches[0]
    line = lines[i]
    if re.fullmatch(rb"[ \t]*enable_object_processing[ \t]*:[ \t]*True[ \t]*(?:\r?\n)?", line):
        return data
    if not re.fullmatch(rb"[ \t]*enable_object_processing[ \t]*:[ \t]*False[ \t]*(?:\r?\n)?", line):
        raise RuntimeError("Unknown setting format")
    lines[i] = line.replace(b"False", b"True", 1)
    return b"".join(lines)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: moonraker_candidates.py CONFIG MODULE")
    config, module = (Path(p).read_bytes() for p in sys.argv[1:])
    c, m = prepare_config(config), prepare_module(module)
    print("PASS: Config candidate", digest(c))
    print("PASS: Module candidate", digest(m))
    print("No files changed")
