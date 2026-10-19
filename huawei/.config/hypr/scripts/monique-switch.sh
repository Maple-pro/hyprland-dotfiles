#!/usr/bin/env bash
# The compatibility entry point owns locking, validation and rollback.
set -euo pipefail
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hyprland"
mkdir -p "$state_dir"
log="$state_dir/projection.log"
if [[ -f "$log" ]] && [[ $(stat -c %s "$log") -gt 1048576 ]]; then mv -f "$log" "$log.1"; fi
if output=$(/home/yangfeng/.local/bin/monique --switch-profile "${1:?usage: monique-switch.sh <profile-name>}" 2>&1); then
    printf '[%s] %s\n' "$(date -Is)" "$output" >> "$log"
else
    result=$?
    printf '[%s] FAILED: %s\n' "$(date -Is)" "$output" >> "$log"
    hyprctl notify 3 6000 'rgb(d20f39)' '显示模式切换失败，已尝试恢复。详情见 ~/.local/state/hyprland/projection.log' || true
    exit "$result"
fi
