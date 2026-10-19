#!/usr/bin/env bash
# Run after the compositor has exported its actual Wayland socket.
set -euo pipefail
exec 9>"${XDG_RUNTIME_DIR:?}/hyprland-session-start.lock"
flock 9
dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_SESSION_ID XDG_RUNTIME_DIR PATH \
    XMODIFIERS GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE GLFW_IM_MODULE \
    QT_QPA_PLATFORM QT_SCALE_FACTOR QT_AUTO_SCREEN_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY \
    GDK_BACKEND GDK_SCALE GDK_DPI_SCALE XFT_DPI XCURSOR_SIZE HYPRCURSOR_SIZE
systemctl --user start hyprland-session.target
