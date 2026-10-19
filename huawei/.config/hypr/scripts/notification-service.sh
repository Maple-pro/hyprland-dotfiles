#!/usr/bin/env bash
# Keep the KDE notification provider usable when logging into Plasma.
set -euo pipefail
case ":${XDG_CURRENT_DESKTOP:-}:" in
    *:Hyprland:*) exec systemctl --user start dunst.service ;;
    *:KDE:*|*:Plasma:*) exec /usr/bin/plasma_waitforname org.freedesktop.Notifications ;;
    *) exec systemctl --user start dunst.service ;;
esac
