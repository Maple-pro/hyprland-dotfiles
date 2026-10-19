#!/usr/bin/env bash
# Coalesce concurrent requests; systemd owns the process and its journal.
set -euo pipefail
exec 9>"${XDG_RUNTIME_DIR:?}/restart-waybar.lock"
flock -n 9 || exit 0
sleep 0.3
systemctl --user is-active --quiet hyprland-session.target || exit 0
systemctl --user restart waybar.service
