"""Recover a pending transaction only when all files have known fingerprints."""
import os
import stat
from pathlib import Path
from moonraker_journal import verify_backup, digest
from moonraker_transaction import atomic_replace, sync_directory

def recover_pending(journal, allowed_paths, verify):
    journal = Path(journal)
    if not (journal / "PENDING").is_file() or (journal / "COMMITTED").exists():
        raise RuntimeError("Not a pending transaction")
    records = verify_backup(journal)
    allowed = {str(Path(p)) for p in allowed_paths}
    if len(records) != len(allowed) or {r["path"] for r in records} != allowed:
        raise RuntimeError("Unexpected recovery paths")
    for r in records:
        p = Path(r["path"])
        s = p.lstat()
        if not stat.S_ISREG(s.st_mode):
            raise RuntimeError("Unexpected file type")
        if (stat.S_IMODE(s.st_mode), s.st_uid, s.st_gid) != (r["mode"], r["uid"], r["gid"]):
            raise RuntimeError("Unexpected file metadata")
        if digest(p.read_bytes()) not in (r["original"], r["candidate"]):
            raise RuntimeError("Independent modification: " + str(p))
    for r in reversed(records):
        p = Path(r["path"])
        current = digest(p.read_bytes())
        if current == r["original"]:
            continue
        if current != r["candidate"]:
            raise RuntimeError("Concurrent modification")
        atomic_replace(p, (journal / r["backup"]).read_bytes())
    for r in records:
        if digest(Path(r["path"]).read_bytes()) != r["original"]:
            raise RuntimeError("Recovery fingerprint mismatch")
    verify()
    os.replace(str(journal / "PENDING"), str(journal / "ROLLED_BACK"))
    sync_directory(journal)
