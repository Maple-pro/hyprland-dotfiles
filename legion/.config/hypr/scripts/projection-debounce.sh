#!/bin/sh
# Coalesce Hyprland monitor/config events, wait for the layout to settle, then ask
# projection-state.lua to reconcile through `hyprctl repl`.
#
# The delay lives here instead of in an hl.timer on purpose: Hyprland 0.57.0
# segfaults in CConfigManager::cleanTimers() if a Lua timer is still registered
# when the config manager is torn down (reload or exit).
set -u

SCRIPT=/home/yangfeng/.config/hypr/scripts/projection-state.lua
HYPRCTL=/usr/bin/hyprctl
runtime=${XDG_RUNTIME_DIR:-/tmp}
base="$runtime/hypr-projection-${HYPRLAND_INSTANCE_SIGNATURE:-unknown}"
pending="$base.pending"

[ -x "$HYPRCTL" ] || exit 0

# Last event wins: a newer helper overwrites the marker and this one bails out.
printf '%s\n' "$$" >"$pending" 2>/dev/null || exit 0

# Let Monique finish applying a profile before sampling (max ~3s).
i=0
while [ "$i" -lt 10 ]; do
    pid=$(cat "$runtime/monique-applying" 2>/dev/null || true)
    case $pid in '' | *[!0-9]*) break ;; esac
    kill -0 "$pid" 2>/dev/null || break
    i=$((i + 1))
    sleep 0.3
done

sleep 0.45
[ "$(cat "$pending" 2>/dev/null)" = "$$" ] || exit 0
"$HYPRCTL" repl "return dofile('$SCRIPT').trigger('sample')" >/dev/null 2>&1 || exit 0

# Second look 350ms later: only reconcile a layout that stopped moving.
sleep 0.35
[ "$(cat "$pending" 2>/dev/null)" = "$$" ] || exit 0
i=0
while [ "$i" -lt 6 ]; do
    out=$("$HYPRCTL" repl "return dofile('$SCRIPT').trigger('settle')" 2>/dev/null | tail -n 1 | tr -d '\r')
    [ "$out" = "busy" ] || exit 0
    i=$((i + 1))
    sleep 0.4
done
exit 0
