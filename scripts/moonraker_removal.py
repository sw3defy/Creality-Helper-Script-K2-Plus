"""Plan restoration of explicitly selected installer-owned changes."""
import stat
from pathlib import Path
from moonraker_journal import verify_backup, digest

def restoration_plan(journal, allowed_paths):
    journal = Path(journal)
    if not (journal / "COMMITTED").is_file() or (journal / "PENDING").exists():
        raise RuntimeError("Expected committed installation journal")
    records = verify_backup(journal)
    allowed = {str(p) for p in allowed_paths}
    seen = set()
    changes = []
    for i, record in enumerate(records):
        name = record["path"]
        if name not in allowed or name in seen or record["backup"] != str(i) + ".original":
            raise RuntimeError("Unexpected journal record")
        seen.add(name)
        path = Path(name)
        st = path.lstat()
        if not stat.S_ISREG(st.st_mode):
            raise RuntimeError("Expected regular file")
        if (stat.S_IMODE(st.st_mode), st.st_uid, st.st_gid) != (record["mode"], record["uid"], record["gid"]):
            raise RuntimeError("File metadata changed")
        if digest(path.read_bytes()) != record["candidate"]:
            raise RuntimeError("Installed file changed")
        original = (journal / record["backup"]).read_bytes()
        if digest(original) != record["original"]:
            raise RuntimeError("Backup changed")
        changes.append((path, original))
    if not changes:
        raise RuntimeError("Empty ownership journal")
    return changes

def restore_owned(root, journal, allowed_paths, preflight, restart, verify, recover):
    from moonraker_activation import activate
    changes = restoration_plan(journal, allowed_paths)
    def check():
        preflight()
        if restoration_plan(journal, allowed_paths) != changes:
            raise RuntimeError("Restoration plan changed")
    return activate(root, changes, check, restart, verify, recover)

def removal_preflight(root, registry, allowed_paths):
    from moonraker_ownership import load
    root = Path(root)
    if list(root.glob("moonraker-*/PENDING")):
        raise RuntimeError("Pending transaction; resolve before removal")
    installed = set(Path(registry).read_text().splitlines())
    for dependency, label in (("kamp", "KAMP"), ("moonraker_timelapse", "Moonraker Timelapse")):
        if dependency in installed:
            raise RuntimeError("Remove " + label + " first")
    record, journal = load(root)
    if journal is None:
        return record, []
    return record, restoration_plan(journal, allowed_paths)

def execute_removal(root, registry, allowed_paths, preflight, restart, verify, recover):
    import fcntl
    from moonraker_ownership import load
    root = Path(root)
    with (root / ".moonraker.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        record, changes = removal_preflight(root, registry, allowed_paths)
        preflight()
        if record["kind"] == "adopted":
            print("PASS: Adopted files preserved; no restoration required")
            return None
        _, journal = load(root)
        return restore_owned(root, journal, allowed_paths, preflight,
                             lambda: restart(record["baseline"]),
                             lambda: verify(record["baseline"]), recover)

def unregister_adopted(root, registry, allowed_paths, preflight):
    """Unregister adopted extensions without touching pre-existing files."""
    import fcntl
    from moonraker_transaction import atomic_replace
    root, registry = Path(root), Path(registry)
    with (root / ".moonraker.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        record, changes = removal_preflight(root, registry, allowed_paths)
        if record != {"kind": "adopted"} or changes:
            raise RuntimeError("Owned restoration requires separate validation")
        preflight()
        original = registry.read_bytes()
        candidate = b"".join(line for line in original.splitlines(keepends=True)
                             if line.strip() != b"moonraker_extensions")
        if candidate != original:
            atomic_replace(registry, candidate)
        print("PASS: Adopted extensions unregistered; existing files and ownership preserved")
