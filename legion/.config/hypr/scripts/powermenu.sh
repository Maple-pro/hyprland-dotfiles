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
    hyprlock
    ;;
  Suspend)
    systemctl suspend
    ;;
  'Log out')
    hyprctl dispatch exit
    ;;
  Reboot)
    systemctl reboot
    ;;
  'Power off')
    systemctl poweroff
    ;;
esac

