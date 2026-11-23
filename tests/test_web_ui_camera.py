#!/usr/bin/env python3
"""Test camera-preservation detection using disposable offline HTML."""
import importlib.util
import tempfile
from pathlib import Path

script = Path(__file__).resolve().parents[1] / "scripts" / "web_ui_release.py"
spec = importlib.util.spec_from_file_location("web_ui_release", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    index = root / "index.html"
    assert module.has_camera_customization(index) is False
    index.write_text("<html><body>stock UI</body></html>")
    assert module.has_camera_customization(index) is False
    for marker in ("function enableCamera() {", "function enableMainsailCams() {",
                   "go2rtc_keepalive", "var cameraReady"):
        index.write_text("<html><script>" + marker + "</script></html>")
        before = index.read_bytes()
        assert module.has_camera_customization(index) is True, marker
        assert index.read_bytes() == before
    index.unlink()
    index.symlink_to(root / "missing.html")
    try:
        module.has_camera_customization(index)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Symlinked UI index must be rejected")
print("PASS: offline camera-preservation checks; no UI files modified")
