#!/usr/bin/env python3
"""Safely stage a web UI release without touching nginx, Moonraker or cameras.

Usage: python3 scripts/web_ui_release.py fluidd|mainsail
The caller must explicitly confirm the selected release. This script only
changes /usr/share/{fluidd,mainsail}; no service restarts are performed.
"""
import json
import re
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile
import urllib.request
import zipfile

PROJECTS = {
    "fluidd": ("fluidd-core/fluidd", "fluidd.zip"),
    "mainsail": ("mainsail-crew/mainsail", "mainsail.zip"),
}
MAX_ZIP = 80 * 1024 * 1024
MAX_UNPACKED = 200 * 1024 * 1024

def get_json(url):
    request = urllib.request.Request(url, headers={
        "User-Agent": "K2Plus-Helper-Release-Installer",
        "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)

# Camera customizations are maintained by the existing camera installer.
# Preserve its exact script, not a guessed replacement. Reject ambiguous cases.
CAMERA_FUNCTIONS = ("enableCamera", "enableMainsailCams")
CAMERA_BLOCK = re.compile(r"<script\b[^>]*>[\s\S]*?</script\s*>", re.I)

def extract_camera_scripts(index_path):
    if index_path.is_symlink():
        raise RuntimeError("Refusing symlinked web UI index")
    if not index_path.is_file():
        return []
    content = index_path.read_text(encoding="utf-8", errors="replace")
    scripts = []
    for block in CAMERA_BLOCK.findall(content):
        if any(re.search(r"\bfunction\s+" + name + r"\s*\(", block)
               for name in CAMERA_FUNCTIONS):
            scripts.append(block)
    for name in CAMERA_FUNCTIONS:
        if re.search(r"\bfunction\s+" + name + r"\s*\(", content) and not any(
            re.search(r"\bfunction\s+" + name + r"\s*\(", block) for block in scripts
        ):
            raise RuntimeError("Cannot isolate camera customization: " + name)
    if len(scripts) > 1:
        raise RuntimeError("Multiple camera scripts require manual review")
    # A partially installed or mixed-generation camera injection is not safe
    # to transplant automatically: retain the working UI for manual review.
    if "go2rtc_keepalive" in content or "var cameraReady" in content:
        frames = re.findall(r"<iframe\b[^>]*>[\s\S]*?</iframe\s*>", content, re.I)
        frames = [f for f in frames if re.search(r'\bid="go2rtc_keepalive"', f)]
        if len(frames) != 1 or len(scripts) != 1:
            raise RuntimeError("Ambiguous legacy camera integration")
        if not all(t in scripts[0] for t in ("var cameraReady", "function enableCamera", "function checkAndReload", "/go2rtc/api/streams")):
            raise RuntimeError("Unknown legacy camera integration")
        combined = frames[0] + scripts[0]
        if content.count(combined) != 1:
            raise RuntimeError("Legacy camera block is not contiguous")
        return [combined]
    if len(scripts) == 1:
        script = scripts[0]
        for name in CAMERA_FUNCTIONS:
            if len(re.findall(r"\bfunction\s+" + name + r"\s*\(", content)) > 1:
                raise RuntimeError("Duplicate camera function requires manual review")
        if not any(re.search(r"\bfunction\s+" + name + r"\s*\(", script)
                   for name in CAMERA_FUNCTIONS):
            raise RuntimeError("Camera script cannot be isolated")
    return scripts

def has_camera_customization(index_path):
    return bool(extract_camera_scripts(index_path))

def preserve_camera_scripts(source_index, staged_index):
    scripts = extract_camera_scripts(source_index)
    if not scripts:
        return False
    if staged_index.is_symlink() or not staged_index.is_file():
        raise RuntimeError("Missing or symlinked staged UI index")
    content = staged_index.read_text(encoding="utf-8")
    if any(re.search(r"\bfunction\s+" + name + r"\s*\(", content)
           for name in CAMERA_FUNCTIONS):
        raise RuntimeError("Staged UI already has camera customization; manual review required")
    if content.lower().count("</body>") != 1:
        raise RuntimeError("Staged UI has no unique closing body tag")
    content = re.sub(r"</body>", lambda match: "\n".join(scripts) + "\n" + match.group(),
                     content, count=1, flags=re.I)
    staged_index.write_text(content, encoding="utf-8")
    return True

def validate_release_archive(archive):
    """Reject unsafe ZIP members before extraction to a disposable directory."""
    with zipfile.ZipFile(str(archive)) as z:
        members = z.infolist()
        total = 0
        seen = set()
        files = set()
        directories = set()
        if len(members) > 20000:
            raise RuntimeError("Release contains too many entries")
        for member in members:
            raw = member.filename
            path = Path(raw)
            mode = member.external_attr >> 16
            kind = stat.S_IFMT(mode)
            parts = path.parts
            if (not raw or "\x00" in raw or "\\" in raw or
                path.is_absolute() or ".." in parts or
                any(part in ("", ".") for part in parts) or
                stat.S_ISLNK(mode) or
                kind not in (0, stat.S_IFREG, stat.S_IFDIR)):
                raise RuntimeError("Unsafe release archive entry")
            canonical = raw.rstrip("/")
            if canonical in seen:
                raise RuntimeError("Duplicate release archive entry")
            seen.add(canonical)
            is_dir = member.is_dir()
            if is_dir and kind == stat.S_IFREG:
                raise RuntimeError("Directory entry declared as regular file")
            if not is_dir and kind == stat.S_IFDIR:
                raise RuntimeError("File entry declared as directory")
            if is_dir:
                directories.add(canonical)
            else:
                files.add(canonical)
            total += member.file_size
            if total > MAX_UNPACKED:
                raise RuntimeError("Expanded release exceeds size limit")
        for path in files | directories:
            parents = Path(path).parents
            if any(str(parent) in files for parent in parents if str(parent) != "."):
                raise RuntimeError("Archive file conflicts with nested path")
        if "index.html" not in files:
            raise RuntimeError("Release missing regular index.html")
        return members


def promote_staged_ui(stage, target, backup):
    """Promote prepared UI; retain or restore original on failure."""
    if backup.exists() or backup.is_symlink():
        raise RuntimeError("Previous rollback backup exists: " + str(backup))
    if target.is_symlink() or stage.is_symlink():
        raise RuntimeError("Refusing symlinked UI directory")
    swapped = False
    if target.exists():
        target.rename(backup)
        swapped = True
    try:
        stage.rename(target)
    except Exception as install_error:
        if swapped:
            try:
                backup.rename(target)
            except Exception as rollback_error:
                raise RuntimeError(
                    "UI promotion AND automatic rollback failed. Original UI at {}. "
                    "Install error: {}. Rollback error: {}".format(
                        backup, install_error, rollback_error)
                ) from install_error
        raise
    return swapped


def require_idle():
    base = "http://127.0.0.1:7125"
    info = get_json(base + "/server/info")["result"]
    if not info["klippy_connected"] or info["klippy_state"] != "ready" or info["failed_components"] or "update_manager" in info["components"]:
        raise RuntimeError("Printer health or core update protection check failed")
    state = get_json(base + "/printer/objects/query?print_stats")["result"]["status"]["print_stats"]["state"]
    queue = get_json(base + "/server/job_queue/status")["result"]
    if state not in ("standby", "complete", "cancelled") or queue["queued_jobs"]:
        raise RuntimeError("Printer must be idle with an empty queue")

def verify_http(name, target):
    require_idle()
    port = {"fluidd": 4408, "mainsail": 4409}[name]
    base = "http://127.0.0.1:{}".format(port)
    with urllib.request.urlopen(base + "/", timeout=15) as response:
        if response.read() != (target / "index.html").read_bytes():
            raise RuntimeError("Served index does not match installed index")
    with urllib.request.urlopen(base + "/go2rtc/api/frame.jpeg?src=k2plus", timeout=20) as response:
        if response.read(2) != b"\xff\xd8":
            raise RuntimeError("Camera snapshot is not JPEG")

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in PROJECTS:
        raise SystemExit("Usage: web_ui_release.py fluidd|mainsail")
    require_idle()
    name = sys.argv[1]
    repo, asset_name = PROJECTS[name]
    target = Path("/usr/share") / name
    if target.is_symlink():
        raise RuntimeError("Refusing symlinked target")
    # Inspect the existing camera injection without changing live files.
    # Copy the exact existing script into the validated staging directory
    # before swapping the web UI. Unknown injections fail closed.
    camera_index = target / "index.html"
    extract_camera_scripts(camera_index)
    release = get_json("https://api.github.com/repos/{}/releases/latest".format(repo))
    assets = [a for a in release.get("assets", []) if a.get("name") == asset_name]
    if len(assets) != 1:
        raise RuntimeError("Official release archive not found; no changes made")
    asset = assets[0]
    if asset.get("size", 0) > MAX_ZIP:
        raise RuntimeError("Release archive exceeds size limit")
    url = asset["browser_download_url"]
    if not url.startswith("https://github.com/{}/releases/download/".format(repo)):
        raise RuntimeError("Unexpected release download host/path")
    version = release.get("tag_name", "unknown")
    approved = {"fluidd": "v1.38.1", "mainsail": "v2.19.0"}
    if version != approved[name]:
        raise RuntimeError("Release not approved for live compatibility testing")
    print("Selected official {} release: {}".format(name, version))
    print("Target: {}".format(target))
    if input("Type INSTALL to stage and replace this web UI only: ").strip() != "INSTALL":
        print("Cancelled; no changes made")
        raise SystemExit(2)

    # Download to UDISK; only the final promotion tree needs the target filesystem.
    if not os.path.ismount("/mnt/UDISK"):
        raise RuntimeError("UDISK is not mounted; refusing to stage on system storage")
    work = Path(tempfile.mkdtemp(prefix="helper-ui-" + name + "-", dir="/mnt/UDISK"))
    promotion = None
    backup = target.with_name(target.name + ".previous-helper")
    swapped = False
    try:
        archive = work / "release.zip"
        request = urllib.request.Request(url, headers={"User-Agent": "K2Plus-Helper-Release-Installer"})
        with urllib.request.urlopen(request, timeout=40) as response, archive.open("wb") as out:
            total = 0
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                total += len(block)
                if total > MAX_ZIP:
                    raise RuntimeError("Archive exceeded size limit")
                out.write(block)
        stage = work / "files"
        stage.mkdir()
        members = validate_release_archive(archive)
        expanded = sum(m.file_size for m in members)
        if shutil.disk_usage("/usr/share").free < expanded + 32 * 1024 * 1024:
            raise RuntimeError("Insufficient overlay space for safe promotion")
        with zipfile.ZipFile(str(archive)) as z:
            z.extractall(str(stage))
        if not (stage / "index.html").is_file():
            raise RuntimeError("Release missing index.html; original installation untouched")
        preserved_camera = preserve_camera_scripts(camera_index, stage / "index.html")
        if preserved_camera:
            print("Preserved existing camera UI script in staged {} release".format(name))
        if backup.exists() or backup.is_symlink():
            raise RuntimeError("Previous rollback backup exists: " + str(backup))
        # Write metadata in the staging tree, before any live directory swap.
        # A failure here must leave the existing UI and camera untouched.
        (stage / ".helper-release-version").write_text(version + "\n")
        promotion = Path(tempfile.mkdtemp(prefix="." + name + "-promote-", dir="/usr/share"))
        local_stage = promotion / "files"
        shutil.copytree(stage, local_stage)
        if extract_camera_scripts(local_stage / "index.html") != extract_camera_scripts(camera_index):
            raise RuntimeError("Camera preservation verification failed")
        require_idle()
        verify_http(name, target)
        swapped = promote_staged_ui(local_stage, target, backup)
        try:
            verify_http(name, target)
        except Exception:
            if swapped:
                target.rename(local_stage)
                backup.rename(target)
                verify_http(name, target)
                print("Original UI restored after failed health check")
            raise
        print("Installed {} {}. Rollback directory: {}".format(name, version, backup if swapped else "none"))
        print("No nginx, Moonraker, Klipper or camera services were restarted.")
    finally:
        if promotion is not None:
            shutil.rmtree(str(promotion), ignore_errors=True)
        shutil.rmtree(str(work), ignore_errors=True)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        sys.stderr.write("ERROR: {}\n".format(exc))
        sys.exit(1)
