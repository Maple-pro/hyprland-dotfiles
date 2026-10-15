#!/usr/bin/env bash
set -euo pipefail

# Keep the lock for the lifetime of Waybar, including concurrent autostarts.
exec 8>"${XDG_RUNTIME_DIR:-/tmp}/.waybar-${UID}.lock"
flock -n 8 || exit 0

export XDG_CONFIG_HOME="${HOME}/.config/waybar/gtk-only"
export GSETTINGS_BACKEND=keyfile
export GDK_BACKEND=wayland
exec waybar -c "${HOME}/.config/waybar/config.jsonc" -s "${HOME}/.config/waybar/style.css"
