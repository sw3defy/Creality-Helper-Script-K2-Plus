"""Fresh activation orchestration with injected service checks for testing."""
from moonraker_journal import prepare_backup, verify_backup, finish_backup, digest
from moonraker_transaction import atomic_replace
from moonraker_recovery import recover_pending

def activate(root, changes, preflight, restart, verify, restore_service):
    changes = [(p, data) for p, data in changes if p.read_bytes() != data]
    preflight()
    if not changes:
        verify()
        return None
    journal = prepare_backup(root, changes)
    records = verify_backup(journal)
    try:
        preflight()
        for (path, candidate), record in zip(changes, records):
            if digest(path.read_bytes()) != record["original"]:
                raise RuntimeError("Source changed after backup")
            if digest(candidate) != record["candidate"]:
                raise RuntimeError("Candidate changed after backup")
        for path, candidate in changes:
            atomic_replace(path, candidate)
        restart()
        verify()
        for (path, candidate), record in zip(changes, records):
            if digest(path.read_bytes()) != record["candidate"]:
                raise RuntimeError("Installed fingerprint mismatch")
        finish_backup(journal)
    except Exception:
        if (journal / "PENDING").exists():
            recover_pending(journal, [p for p, _ in changes], restore_service)
        raise
    return journal
