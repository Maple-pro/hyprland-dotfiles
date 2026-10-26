#!/usr/bin/env bash
set -euo pipefail

# Keep the lock for the lifetime of Waybar, including concurrent autostarts.
exec 8>"${XDG_RUNTIME_DIR:-/tmp}/.waybar-${UID}.lock"
flock -n 8 || exit 0

# Match tray icon variants to the single CSS theme selector.
theme=dark
if grep -Eq '^[[:space:]]*@import[[:space:]]+"themes/light[.]css"' "$HOME/.config/waybar/style.css"; then
    theme=light
fi
export XDG_CONFIG_HOME="${HOME}/.config/waybar/gtk-only/${theme}"
export XDG_DATA_DIRS="${HOME}/.config/waybar/gtk-only/${theme}/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_BACKEND=keyfile
export GDK_BACKEND=wayland
exec "$HOME/.local/bin/waybar" -c "${HOME}/.config/waybar/config.jsonc" -s "${HOME}/.config/waybar/style.css"
