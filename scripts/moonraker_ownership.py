"""Explicit ownership records; never infer ownership from old backups."""
import json
from pathlib import Path
from moonraker_journal import durable_write, digest

def register(root, journal=None, baseline=None):
    root = Path(root)
    target = root / "moonraker-ownership.json"
    if target.exists():
        raise RuntimeError("Ownership already registered")
    record = {"kind": "adopted"}
    if journal is not None:
        journal = Path(journal)
        if journal.parent != root or not journal.name.startswith("moonraker-") or not (journal / "COMMITTED").is_file() or (journal / "PENDING").exists():
            raise RuntimeError("Invalid ownership journal")
        if type(baseline) is not bool:
            raise RuntimeError("Missing original processing state")
        record = {"kind": "owned", "journal": journal.name, "baseline": baseline,
                  "manifest": digest((journal / "manifest.json").read_bytes())}
    durable_write(target, json.dumps(record).encode())
    return record

def load(root):
    root = Path(root)
    record = json.loads((root / "moonraker-ownership.json").read_text())
    if record == {"kind": "adopted"}:
        return record, None
    if record.get("kind") != "owned" or type(record.get("baseline")) is not bool:
        raise RuntimeError("Invalid ownership record")
    name = record["journal"]
    if Path(name).name != name or not name.startswith("moonraker-"):
        raise RuntimeError("Invalid journal name")
    journal = root / name
    if not (journal / "COMMITTED").is_file() or (journal / "PENDING").exists():
        raise RuntimeError("Invalid journal state")
    if digest((journal / "manifest.json").read_bytes()) != record["manifest"]:
        raise RuntimeError("Ownership manifest changed")
    return record, journal

def verify_retirement(root, removal, allowed_paths):
    from moonraker_journal import verify_backup
    record, installation = load(root)
    removal = Path(removal)
    if installation is None or removal.parent != Path(root) or removal == installation:
        raise RuntimeError("Invalid retirement transaction")
    if not (removal / "COMMITTED").is_file() or (removal / "PENDING").exists():
        raise RuntimeError("Removal not committed")
    installed = verify_backup(installation)
    restored = verify_backup(removal)
    expected = {r["path"]: (r["candidate"], r["original"]) for r in installed}
    actual = {r["path"]: (r["original"], r["candidate"]) for r in restored}
    if expected != actual or not set(expected).issubset({str(p) for p in allowed_paths}):
        raise RuntimeError("Removal journal does not reverse installation")
    for name, (_, original) in expected.items():
        if digest(Path(name).read_bytes()) != original:
            raise RuntimeError("Original file not restored")
    return installation
