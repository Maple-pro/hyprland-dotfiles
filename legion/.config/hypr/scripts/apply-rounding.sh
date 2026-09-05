#!/usr/bin/env bash
set -euo pipefail

HYPR_LUA="${HOME}/.config/hypr/hyprland.lua"
WAYBAR_CONFIG="${HOME}/.config/waybar/config.jsonc"
WAYBAR_STYLE="${HOME}/.config/waybar/style.css"

normalize_mode() {
    case "${1:-}" in
        true|rounded)
            echo "true"
            ;;
        false|square)
            echo "false"
            ;;
        *)
            echo "false"
            ;;
    esac
}

read_mode() {
    awk '/^[[:space:]]*local[[:space:]]+rounded[[:space:]]*=/{ match($0, /true|false/); print substr($0, RSTART, RLENGTH); exit }' "${HYPR_LUA}"
}

write_mode() {
    local new="$1"
    local tmp
    tmp="$(mktemp)"

    awk -v new="${new}" '
        /^[[:space:]]*local[[:space:]]+rounded[[:space:]]*=/ {
            match($0, /^[[:space:]]*local[[:space:]]+rounded[[:space:]]*=[[:space:]]*/)
            prefix = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)
            sub(/^(true|false)/, new, rest)
            $0 = prefix rest
        }
        { print }
    ' "${HYPR_LUA}" > "${tmp}"

    mv "${tmp}" "${HYPR_LUA}"
    chmod 644 "${HYPR_LUA}"
}

apply_waybar() {
    local mode="$1"

    if [[ "${mode}" == "true" ]]; then
        perl -0pi -e 's#^[ \t]*//[ \t]*("(?:margin-top|margin-left|margin-right)":\s*\d+[,]?)\s*$#$1#mg' "${WAYBAR_CONFIG}"
        perl -0pi -e 's#^[ \t]*/\*[ \t]*(border-radius:\s*12px;)[ \t]*\*/[ \t]*$#$1#mg' "${WAYBAR_STYLE}"
    else
        perl -0pi -e 's#^([ \t]*)("(?:margin-top|margin-left|margin-right)":\s*\d+[,]?)\s*$#$1// $2#mg' "${WAYBAR_CONFIG}"
        perl -0pi -e 's#^([ \t]*)(border-radius:\s*12px;)[ \t]*$#$1/* $2 */#mg' "${WAYBAR_STYLE}"
    fi
}

apply_hyprland() {
    local mode="$1"
    local gaps_in gaps_out rounding

    if [[ "${mode}" == "true" ]]; then
        gaps_in=5
        gaps_out="5,8,8,8"
        rounding=12
    else
        gaps_in=0
        gaps_out="0,0,0,0"
        rounding=0
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl --batch "keyword general:gaps_in ${gaps_in} ; keyword general:gaps_out ${gaps_out} ; keyword decoration:rounding ${rounding}" >/dev/null 2>&1 || true
    fi
}

restart_waybar() {
    local marker="${TMPDIR:-/tmp}/waybar-rounding-restart.ts"
    local now last

    now="$(date +%s)"
    if [[ -f "${marker}" ]]; then
        last="$(cat "${marker}" 2>/dev/null || echo 0)"
        if (( now - last < 2 )); then
            return 0
        fi
    fi
    date +%s > "${marker}"

    pkill -x waybar 2>/dev/null || true
    sleep 0.2

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch exec waybar >/dev/null 2>&1 || { nohup waybar >/dev/null 2>&1 & }
    else
        nohup waybar >/dev/null 2>&1 &
    fi
}

notify_mode() {
    local mode="$1"
    local label

    if [[ "${mode}" == "true" ]]; then
        label="圆角 + margin 已开启"
    else
        label="圆角 + margin 已关闭"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Hyprland 外观切换" "${label}" -t 1500 2>/dev/null || true
    fi
}

case "${1:-}" in
    toggle)
        current="$(read_mode)"
        current="$(normalize_mode "${current}")"

        if [[ "${current}" == "true" ]]; then
            next="false"
        else
            next="true"
        fi

        write_mode "${next}"
        apply_waybar "${next}"
        apply_hyprland "${next}"
        restart_waybar
        notify_mode "${next}"
        ;;
    apply)
        mode="$(normalize_mode "${2:-}")"
        apply_waybar "${mode}"
        ;;
    reload)
        mode="$(normalize_mode "$(read_mode)")"
        apply_waybar "${mode}"
        restart_waybar
        notify_mode "${mode}"
        ;;
    *)
        echo "Usage: $0 [apply rounded|square|true|false|toggle|reload]" >&2
        exit 1
        ;;
esac
