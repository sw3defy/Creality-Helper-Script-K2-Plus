#!/usr/bin/env python3
"""Safely stage a web UI release without touching nginx, Moonraker or cameras.

Usage: python3 scripts/web_ui_release.py fluidd|mainsail
The caller must explicitly confirm the selected release. This script only
changes /usr/share/{fluidd,mainsail}; no service restarts are performed.
"""
import json
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

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in PROJECTS:
        raise SystemExit("Usage: web_ui_release.py fluidd|mainsail")
    name = sys.argv[1]
    repo, asset_name = PROJECTS[name]
    target = Path("/usr/share") / name
    if target.is_symlink():
        raise RuntimeError("Refusing symlinked target")
    # The existing camera fix injects UI-specific JavaScript into index.html.
    # Replacing web assets would silently erase that working integration.
    # Keep the camera untouched and refuse this unrelated update instead.
    current_index = target / "index.html"
    if current_index.is_symlink():
        raise RuntimeError("Refusing symlinked web UI index")
    if current_index.is_file():
        current_text = current_index.read_text(encoding="utf-8", errors="replace")
        camera_markers = ("enableCamera()", "enableMainsailCams()",
                          "go2rtc_keepalive", "var cameraReady")
        if any(marker in current_text for marker in camera_markers):
            raise RuntimeError(
                "Existing camera UI customization detected; web UI update postponed "
                "to avoid removing the working camera fix. No changes made."
            )
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
    print("Selected official {} release: {}".format(name, version))
    print("Target: {}".format(target))
    if input("Type INSTALL to stage and replace this web UI only: ").strip() != "INSTALL":
        print("Cancelled; no changes made")
        return

    # Use a temporary directory on the same filesystem for atomic rename.
    work = Path(tempfile.mkdtemp(prefix="." + name + "-stage-", dir="/usr/share"))
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
        with zipfile.ZipFile(str(archive)) as z:
            total = 0
            members = z.infolist()
            for member in members:
                path = Path(member.filename)
                mode = (member.external_attr >> 16)
                if (path.is_absolute() or ".." in path.parts or
                    stat.S_ISLNK(mode) or
                    (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))):
                    raise RuntimeError("Unsafe archive entry")
                total += member.file_size
                if total > MAX_UNPACKED:
                    raise RuntimeError("Expanded release exceeds size limit")
            z.extractall(str(stage))
        if not (stage / "index.html").is_file():
            raise RuntimeError("Release missing index.html; original installation untouched")
        if backup.exists() or backup.is_symlink():
            raise RuntimeError("Previous rollback backup exists: " + str(backup))
        if target.exists():
            target.rename(backup)
            swapped = True
        try:
            stage.rename(target)
        except Exception:
            if swapped:
                backup.rename(target)
            raise
        (target / ".helper-release-version").write_text(version + "\n")
        print("Installed {} {}. Rollback directory: {}".format(name, version, backup if swapped else "none"))
        print("No nginx, Moonraker, Klipper or camera services were restarted.")
    finally:
        shutil.rmtree(str(work), ignore_errors=True)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        sys.stderr.write("ERROR: {}\n".format(exc))
        sys.exit(1)
