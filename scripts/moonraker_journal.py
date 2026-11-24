"""Durable backup journal for Moonraker extension transactions."""
import os
import json
import hashlib
import stat
import tempfile
from pathlib import Path
from moonraker_transaction import sync_directory

def digest(data):
    return hashlib.sha256(data).hexdigest()

def durable_write(path, data):
    with path.open("xb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    sync_directory(path.parent)

def prepare_backup(root, changes):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    journal = Path(tempfile.mkdtemp(prefix="moonraker-", dir=str(root)))
    sync_directory(root)
    records = []
    for i, (path, candidate) in enumerate(changes):
        path = Path(path)
        st = path.lstat()
        if not stat.S_ISREG(st.st_mode):
            raise RuntimeError("Not a regular file")
        original = path.read_bytes()
        name = str(i) + ".original"
        durable_write(journal / name, original)
        records.append(dict(path=str(path), backup=name, original=digest(original),
                            candidate=digest(candidate), mode=stat.S_IMODE(st.st_mode),
                            uid=st.st_uid, gid=st.st_gid))
    durable_write(journal / "manifest.json", json.dumps(records, indent=2).encode())
    durable_write(journal / "PENDING", b"Prepared before modification\n")
    return journal

def verify_backup(journal):
    journal = Path(journal)
    records = json.loads((journal / "manifest.json").read_text())
    for record in records:
        if digest((journal / record["backup"]).read_bytes()) != record["original"]:
            raise RuntimeError("Backup fingerprint mismatch")
    return records

def finish_backup(journal):
    journal = Path(journal)
    verify_backup(journal)
    os.replace(str(journal / "PENDING"), str(journal / "COMMITTED"))
    sync_directory(journal)
