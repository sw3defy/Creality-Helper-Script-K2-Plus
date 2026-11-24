"""Transactional file replacement primitives for Moonraker extensions."""
import os
import stat
import tempfile
from pathlib import Path

def atomic_replace(path, data):
    path = Path(path)
    st = path.lstat()
    if not stat.S_ISREG(st.st_mode):
        raise RuntimeError("Expected regular file: " + str(path))
    fd, name = tempfile.mkstemp(prefix=".helper-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            os.fchown(f.fileno(), st.st_uid, st.st_gid)
            os.fchmod(f.fileno(), stat.S_IMODE(st.st_mode))
            f.flush()
            os.fsync(f.fileno())
        os.replace(name, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(name):
            os.unlink(name)

def sync_directory(path):
    fd = os.open(str(path), os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)

def transaction(changes, verify, replace=atomic_replace):
    originals = [(Path(p), Path(p).read_bytes(), data) for p, data in changes]
    attempted = []
    try:
        for path, original, candidate in originals:
            if path.read_bytes() != original:
                raise RuntimeError("Concurrent modification: " + str(path))
            if original != candidate:
                attempted.append((path, original))
                replace(path, candidate)
        verify()
    except Exception as error:
        failures = []
        for path, original in reversed(attempted):
            try:
                atomic_replace(path, original)
            except Exception as rollback_error:
                failures.append(str(rollback_error))
        if failures:
            raise RuntimeError("Rollback failed: " + "; ".join(failures)) from error
        raise
