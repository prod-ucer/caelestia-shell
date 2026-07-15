#!/usr/bin/env fish

set -l config "$HOME/.config/caelestia/shell.json"
set -l root "$HOME/.config/quickshell/caelestia"
set -l state "$HOME/.local/state/caelestia/wallpaper/boot-shuffle.json"
set -l walls "$HOME/Pictures/Wallpapers"

if not test -r "$config"; or not jq -e '.background.randomWallpaperOnBoot == true' "$config" >/dev/null 2>&1
    exit 0
end

set -l wallpaper ($root/scripts/random-wallpaper-on-boot.py "$walls" "$state")
if test -n "$wallpaper"
    # Start colour extraction at the beginning of the Hyprland session. The
    # wallpaper service's boot-id guard prevents Quickshell from repeating it.
    exec ionice -c 2 -n 0 caelestia wallpaper -f "$wallpaper"
end
