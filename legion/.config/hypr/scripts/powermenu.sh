#!/usr/bin/env bash
set -euo pipefail

choice="$(
  printf '%s\n' \
    'Lock' \
    'Suspend' \
    'Log out' \
    'Reboot' \
    'Power off' |
    rofi -dmenu -i -p 'Power' -theme-str 'window { width: 22%; }'
)"

case "$choice" in
  Lock)
    loginctl lock-session
    ;;
  Suspend)
    systemctl suspend
    ;;
  'Log out')
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
    ;;
  Reboot)
    systemctl reboot
    ;;
  'Power off')
    systemctl poweroff
    ;;
esac

