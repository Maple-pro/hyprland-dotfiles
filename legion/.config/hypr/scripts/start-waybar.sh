#!/usr/bin/env bash
set -euo pipefail

export XDG_CONFIG_HOME="${HOME}/.config/waybar/gtk-only"
export GSETTINGS_BACKEND=keyfile
exec waybar -c "${HOME}/.config/waybar/config.jsonc" -s "${HOME}/.config/waybar/style.css"
