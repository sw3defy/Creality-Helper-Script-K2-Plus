# Creality K2 Plus - Helper Script

A menu-driven helper script for the **Creality K2 Plus** and **K2 Plus Combo (with CFS)**.

Forked and adapted from the excellent [Guilouz Creality Helper Script](https://github.com/Guilouz/Creality-Helper-Script) - rebuilt from the ground up for the K2 Plus architecture.

## Wiki & Documentation

**[https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus/](https://sw3defy.github.io/Creality-Helper-Script-Wiki-K2-Plus/)**

## Installation

Connect to your K2 Plus via SSH, then run:

```sh
python3 -c "import urllib.request; urllib.request.urlretrieve('https://github.com/sw3defy/Creality-Helper-Script-K2-Plus/archive/refs/heads/main.zip', '/tmp/helper.zip')"
python3 -c "import shutil; shutil.unpack_archive('/tmp/helper.zip', '/tmp/')"
cp -r /tmp/Creality-Helper-Script-K2-Plus-main/* /mnt/UDISK/helper-script/
chmod +x /mnt/UDISK/helper-script/helper.sh
sh /mnt/UDISK/helper-script/helper.sh
```

## Features

| Option | Feature |
|--------|---------|
| 1 | Moonraker Extensions & Update Manager |
| 2 | Fans Control Macros |
| 3 | Useful Macros (START_PRINT / END_PRINT) |
| 4 | Save Z-Offset Macros |
| 5 | M600 Filament Change Support |
| 6 | KAMP (Klipper Adaptive Meshing & Purging) |
| 7 | Improved Shapers Calibrations |
| 8 | Fluidd (install/update/repair - port 4408) |
| 9 | Mainsail (install/update/repair - port 4409) |
| 10 | Moonraker Timelapse |
| 11 | Camera Support for Fluidd (WebRTC via go2rtc) |
| 12 | HelixScreen (modern touchscreen UI) |
| 13 | OctoEverywhere (coming soon) |
| 14 | Mobileraker Companion (coming soon) |
| 15 | Git Backup (coming soon) |

## Requirements

- Creality K2 Plus or K2 Plus Combo
- Root SSH access enabled
- SSH client (e.g. PuTTY on Windows)

## Discussions & Support

[Join the discussion](https://github.com/sw3defy/Creality-Helper-Script-Wiki-K2-Plus/discussions)

## Support the Project

<a href="https://buymeacoffee.com/sw3defy"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="60"></a>

<a href="https://ko-fi.com/sw3defy"><img src="https://ko-fi.com/img/githubbutton_sm.svg" height="80"></a>

## Credits

- [Guilouz](https://github.com/Guilouz) - Original Creality Helper Script for K1 Series
- [DnG-Crafts](https://github.com/DnG-Crafts/K2-Camera) - K2 camera WebRTC discovery
- [AlexxIT/go2rtc](https://github.com/AlexxIT/go2rtc) - Stream conversion software
- [prestonbrown/HelixScreen](https://github.com/prestonbrown/helixscreen) - Modern touchscreen UI for Klipper
- [Klipper](https://www.klipper3d.org) - 3D printer firmware
- [Moonraker](https://moonraker.readthedocs.io) - API server
- [Fluidd](https://docs.fluidd.xyz) - Web interface
- [Mainsail](https://docs.mainsail.xyz) - Web interface
- [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) - Adaptive meshing
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) - Wiki theme
