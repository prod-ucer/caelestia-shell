#!/usr/bin/env python3

import json
import fcntl
import os
import random
import sys
from pathlib import Path


IMAGE_EXTENSIONS = {
    ".avif", ".bmp", ".gif", ".heic", ".heif", ".jpeg", ".jpg",
    ".jxl", ".png", ".svg", ".tif", ".tiff", ".webp",
}


def main() -> int:
    if len(sys.argv) != 3:
        return 2

    wallpaper_dir = Path(sys.argv[1]).expanduser()
    state_path = Path(sys.argv[2]).expanduser()
    boot_id = Path("/proc/sys/kernel/random/boot_id").read_text().strip()

    # Hyprland starts the selector early while Wallpapers.qml retains a
    # fallback for manual shell starts. Serialise both paths so only one can
    # advance the boot queue.
    state_path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = state_path.with_suffix(state_path.suffix + ".lock").open("w")
    fcntl.flock(lock_file, fcntl.LOCK_EX)

    state = {}
    try:
        state = json.loads(state_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        pass

    # A shell restart during the same OS boot must not advance the queue.
    if state.get("bootId") == boot_id:
        return 0

    wallpapers = sorted(
        str(path.resolve())
        for path in wallpaper_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )
    if not wallpapers:
        return 0

    existing = set(wallpapers)
    history = [path for path in state.get("history", []) if path in existing]
    lookback = min(6, len(wallpapers) - 1)
    recent = set(history[-lookback:]) if lookback else set()
    candidates = [path for path in wallpapers if path not in recent]
    selected = random.SystemRandom().choice(candidates or wallpapers)

    history.append(selected)
    temporary = state_path.with_suffix(state_path.suffix + ".tmp")
    temporary.write_text(json.dumps({"bootId": boot_id, "history": history[-6:]}, indent=2) + "\n")
    os.replace(temporary, state_path)
    print(selected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
