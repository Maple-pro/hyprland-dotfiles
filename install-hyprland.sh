#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "This installer needs root. Run it with:"
  echo "  sudo bash $0"
  exit 1
fi

PACKAGES=(
  hyprland
  hyprpaper
  hypridle
  hyprlock
  hyprpolkitagent
  hyprpicker
  xdg-desktop-portal-hyprland
  waybar
  rofi
  foot
  dunst
  grim
  slurp
  wl-clipboard
  pamixer
  brightnessctl
  playerctl
  network-manager-applet
  blueman
  qt5-wayland
  qt6-wayland
  ttf-nerd-fonts-symbols
  noto-fonts-emoji
)

echo "==> Syncing repositories and installing Hyprland packages..."
pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

echo "==> Refreshing font cache..."
fc-cache -f

echo
echo "Hyprland packages installed."
echo "Copy the huawei/ or legion/ profile into ~/.config as described in README.md."
echo "Log out of KDE and choose the Hyprland session from SDDM, or run: start-hyprland"
