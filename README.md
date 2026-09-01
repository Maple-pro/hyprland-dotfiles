# Hyprland Dotfiles

This repository contains the Hyprland-related configuration for the current Arch Linux system.

## Contents

```text
.config/hypr/       Hyprland, Hyprpaper, Hypridle, Hyprlock, scripts, wallpaper
.config/waybar/     Waybar status bar
.config/rofi/       Rofi application launcher and window switcher
.config/foot/       Foot terminal
.config/dunst/      Dunst notifications
Hyprland_Guide.md   Basic usage guide
install-hyprland.sh Package installer for the companion applications
```

## Install configuration files

The files in `.config/` are meant to be placed under `~/.config/`:

```bash
cp -a .config/hypr ~/.config/
cp -a .config/waybar ~/.config/
cp -a .config/rofi ~/.config/
cp -a .config/foot ~/.config/
cp -a .config/dunst ~/.config/
```

After copying or editing the Hyprland config, reload it with:

```bash
hyprctl reload
```

