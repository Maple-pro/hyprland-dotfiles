#!/usr/bin/env bash
# Shared rofi mode; direct invocation keeps the Super+X entry point.
set -euo pipefail

if [[ -z "${ROFI_RETV:-}" ]]; then
    exec rofi -show power
fi

case "$ROFI_RETV" in
    0)
        printf '\0prompt\x1fPower\n\0no-custom\x1ftrue\n'
        printf '%s\n' 'Lock' 'Suspend' 'Log out' 'Reboot' 'Power off'
        ;;
    1)
        # Detach actions so rofi can close without waiting on their output.
        case "${1:-}" in
            Lock) setsid loginctl lock-session >/dev/null 2>&1 & ;;
            Suspend) setsid systemctl suspend >/dev/null 2>&1 & ;;
            'Log out') setsid hyprctl eval 'hl.dispatch(hl.dsp.exit())' >/dev/null 2>&1 & ;;
            Reboot) setsid systemctl reboot >/dev/null 2>&1 & ;;
            'Power off') setsid systemctl poweroff >/dev/null 2>&1 & ;;
        esac
        ;;
esac
