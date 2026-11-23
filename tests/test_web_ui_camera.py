#!/usr/bin/env python3
"""Offline tests: preserve original camera JS when replacing web UI assets."""
import importlib.util
import tempfile
import zipfile
from pathlib import Path

script = Path(__file__).resolve().parents[1] / "scripts" / "web_ui_release.py"
spec = importlib.util.spec_from_file_location("web_ui_release", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    original = root / "original.html"
    stage = root / "stage.html"
    assert module.has_camera_customization(original) is False
    for name in ("enableCamera", "enableMainsailCams"):
        camera_script = "<script>function " + name + "() { return true; }</script>"
        original.write_text("<html><body>old" + camera_script + "</body></html>")
        stage.write_text("<html><body>new</body></html>")
        before = original.read_bytes()
        assert module.has_camera_customization(original)
        assert module.preserve_camera_scripts(original, stage)
        assert original.read_bytes() == before
        assert camera_script in stage.read_text()
        assert "new" in stage.read_text()
        assert stage.read_text().count(camera_script) == 1
    original.write_text("<html><body>plain</body></html>")
    stage.write_text("<html><body>new</body></html>")
    assert module.preserve_camera_scripts(original, stage) is False
    assert stage.read_text() == "<html><body>new</body></html>"
    original.write_text("<html><body><script>function enableCamera() {}</script></body></html>")
    stage.write_text("<html><body>no closing body</html>")
    try:
        module.preserve_camera_scripts(original, stage)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Missing closing body should fail closed")
    original.write_text("<html><body><script>function enableCamera() {}</script></body></html>")
    stage.write_text("<html><body><script>function enableCamera() {}</script></body></html>")
    try:
        module.preserve_camera_scripts(original, stage)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Existing staged camera function must not be duplicated")
    original.write_text("<html><body>go2rtc_keepalive</body></html>")
    try:
        module.extract_camera_scripts(original)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Unrecognized legacy camera injection must be reviewed")
    original.unlink()
    original.symlink_to(root / "missing.html")
    try:
        module.extract_camera_scripts(original)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Symlinked index must be rejected")
with tempfile.TemporaryDirectory() as directory:
    archive = Path(directory) / "release.zip"

    def check_zip(entries, expected_failure=False):
        with zipfile.ZipFile(archive, "w") as z:
            for name, payload in entries:
                z.writestr(name, payload)
        if expected_failure:
            try:
                module.validate_release_archive(archive)
            except RuntimeError:
                pass
            else:
                raise AssertionError("Unsafe ZIP entry accepted: " + repr(entries))
        else:
            assert len(module.validate_release_archive(archive)) == len(entries)

    check_zip([("index.html", "<html></html>"), ("assets/app.js", "ok")])
    check_zip([("../index.html", "bad"), ("index.html", "ok")], True)
    check_zip([("index.html", "ok"), ("index.html", "duplicate")], True)
    check_zip([("assets/app.js", "no index")], True)
    check_zip([("index.html", "ok"), ("assets\\\\escape.js", "bad")], True)

print("PASS: offline camera JS preserved exactly; original UI unchanged")
