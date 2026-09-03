# Hyprland Dotfiles

This repository contains Hyprland-related configuration for two Arch Linux
machines:

| Directory | Machine |
| --- | --- |
| `huawei/` | Huawei machine configuration |
| `legion/` | Legion machine configuration |

## Contents

```text
huawei/.config/hypr/       Hyprland, Hyprpaper, Hypridle, Hyprlock, scripts, wallpaper
huawei/.config/waybar/     Waybar status bar
huawei/.config/rofi/       Rofi application launcher and window switcher
huawei/.config/foot/       Foot terminal
huawei/.config/dunst/      Dunst notifications
legion/.config/hypr/       Hyprland, Hyprpaper, Hypridle, Hyprlock, scripts, wallpaper
legion/.config/waybar/     Waybar status bar
legion/.config/rofi/       Rofi application launcher and window switcher
legion/.config/foot/       Foot terminal
legion/.config/dunst/      Dunst notifications
Hyprland_Guide.md   Basic usage guide
install-hyprland.sh Package installer for the companion applications
```

## Install configuration files

Both profiles are meant to be placed under `~/.config/`. Install the Huawei
machine configuration with:

```bash
cp -a huawei/.config/hypr ~/.config/
cp -a huawei/.config/waybar ~/.config/
cp -a huawei/.config/rofi ~/.config/
cp -a huawei/.config/foot ~/.config/
cp -a huawei/.config/dunst ~/.config/
```

Or install the Legion machine configuration with:

```bash
cp -a legion/.config/hypr ~/.config/
cp -a legion/.config/waybar ~/.config/
cp -a legion/.config/rofi ~/.config/
cp -a legion/.config/foot ~/.config/
cp -a legion/.config/dunst ~/.config/
```

After copying or editing the Hyprland config, reload it with:

```bash
hyprctl reload
```
