#!/usr/bin/env bash
# NetworkManager serializes menu icons as PNGs before Waybar receives them.
# Match the producer's GTK palette to the bar, not just Waybar's own theme.
set -euo pipefail
theme=dark
if grep -Eq '^[[:space:]]*@import[[:space:]]+"themes/light[.]css"' "$HOME/.config/waybar/style.css"; then
    theme=light
fi
export XDG_CONFIG_HOME="$HOME/.config/waybar/gtk-only/$theme"
export XDG_DATA_DIRS="$HOME/.config/waybar/gtk-only/$theme/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_BACKEND=keyfile
export GDK_BACKEND=wayland
if [[ $theme == dark ]]; then
    export GTK_THEME=Breeze:dark
else
    export GTK_THEME=Breeze
fi
exec nm-applet
