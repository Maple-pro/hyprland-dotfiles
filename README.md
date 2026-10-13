# Hyprland Dotfiles

This repository contains Hyprland-related configuration for two Arch Linux
machines:

| Directory | Machine |
| --- | --- |
| `huawei/` | Huawei machine configuration |
| `legion/` | Legion machine configuration |

## Contents

```text
huawei/.config/hypr/                 Hyprland, Hyprpaper, Hypridle, Hyprlock, scripts, wallpaper
huawei/.config/waybar/               Waybar status bar
huawei/.config/rofi/                 Rofi application launcher and window switcher
huawei/.config/foot/                 Foot terminal
huawei/.config/dunst/                Dunst notifications
huawei/.config/udiskie/              udiskie removable-drive tray indicator and automount
huawei/.config/fcitx5/               Fcitx5 input method (pinyin, Catppuccin Latte classic UI)
huawei/.local/share/fcitx5/themes/   Fcitx5 user theme "catppuccin-latte-purple"
huawei/.config/gtk-3.0/              GTK3 Breeze-Light colours, decorations, window-button assets
huawei/.config/gtk-4.0/              GTK4 settings (gtk.css symlinked into the system Breeze theme)
huawei/.config/xsettingsd/           xsettingsd GTK/XSETTINGS daemon settings
huawei/.config/nwg-look/             nwg-look export preferences (produced the GTK files above)
huawei/.config/kdeglobals            KDE/Qt colour scheme and icon theme (Breeze Light)
huawei/.config/gtkrc, gtkrc-2.0      KDE-generated GTK2 settings
legion/.config/hypr/                 Hyprland, Hyprpaper, Hypridle, Hyprlock, scripts, wallpaper
legion/.config/waybar/               Waybar status bar
legion/.config/rofi/                 Rofi application launcher and window switcher
legion/.config/foot/                 Foot terminal
legion/.config/dunst/                Dunst notifications
huawei/install-hyprland.sh           Huawei package + configuration installer
huawei/setup-mx150.sh                GeForce MX150 (580xx legacy) driver setup
legion/install-hyprland.sh           Legion package + configuration installer
Hyprland_Guide.md                    Basic usage guide
```

The two profiles are maintained independently, so each one carries its own
installer: the machines need different packages and different files.

## Install

Each profile ships its own installer, because the two machines need different
packages and different files. Run the one that matches the machine:

```bash
bash huawei/install-hyprland.sh     # on the Huawei machine
bash legion/install-hyprland.sh     # on the Legion machine
```

The installer:

1. installs that profile's packages from the official repositories
2. copies its configuration into `~/.config` — and, on Huawei, the Fcitx5 user
   theme into `~/.local/share/fcitx5/themes`

Anything it would overwrite is copied to `~/.dotfiles-backup-<timestamp>/`
first, and pacman runs with `--needed`, so re-running is safe. Packages that are
not in the official repositories are printed at the end rather than installed,
so no AUR helper is required. Running the script as your normal user is
preferred: it escalates with `sudo` only for pacman.

After copying or editing the Hyprland config, reload it with:

```bash
hyprctl reload
```

### Manual installation

The Huawei script is equivalent to:

```bash
cp -a huawei/.config/hypr ~/.config/
cp -a huawei/.config/waybar ~/.config/
cp -a huawei/.config/rofi ~/.config/
cp -a huawei/.config/foot ~/.config/
cp -a huawei/.config/dunst ~/.config/
cp -a huawei/.config/udiskie ~/.config/
cp -a huawei/.config/fcitx5 ~/.config/
cp -a huawei/.config/gtk-3.0 ~/.config/
cp -a huawei/.config/gtk-4.0 ~/.config/
cp -a huawei/.config/xsettingsd ~/.config/
cp -a huawei/.config/nwg-look ~/.config/
cp -a huawei/.config/kdeglobals ~/.config/
cp -a huawei/.config/gtkrc huawei/.config/gtkrc-2.0 ~/.config/

# Fcitx5 user theme (plain `catppuccin-latte-purple` is not shipped by fcitx5)
mkdir -p ~/.local/share/fcitx5/themes
cp -a huawei/.local/share/fcitx5/themes/catppuccin-latte-purple \
      ~/.local/share/fcitx5/themes/
```

The Legion script is equivalent to:

```bash
cp -a legion/.config/hypr ~/.config/
cp -a legion/.config/waybar ~/.config/
cp -a legion/.config/rofi ~/.config/
cp -a legion/.config/foot ~/.config/
cp -a legion/.config/dunst ~/.config/
```

The manual copies merge into existing directories rather than replacing them, so
files that a profile has since dropped are left behind. The installers behave
the same way; only the backup protects you there.

## Huawei theme layer

The Huawei profile is on a light theme. Three palettes are in play, and mixing
them up is the usual source of "why is this window still dark":

| Components | Palette |
| --- | --- |
| Hyprland borders, Waybar, Fcitx5 classic UI, Dunst, Rofi | Catppuccin Latte (light) |
| GTK3/GTK4, Qt/KDE apps, icons, cursors | Breeze Light + Papirus-Light |
| Hyprlock, Foot | Catppuccin Mocha (dark, not yet converted) |

Points to keep in mind:

- Two settings live in dconf rather than in a file, so restore them by hand on
  a fresh install:

  ```bash
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  ```

- The GTK files are produced by nwg-look via KDE's `kde-gtk-config`
  (`gtkconfig.so`). Changing colours or icons in KDE regenerates
  `gtk-3.0/settings.ini` and `gtk-3.0/colors.css`, overwriting these copies.
- `gtk-4.0/gtk.css` and `gtk-4.0/gtk-dark.css` are absolute symlinks into
  `/usr/share/themes/Breeze/`. They dangle if that system theme is missing.
- `gtk-4.0/assets/` is empty on the machine. Git cannot track empty
  directories, and it is harmless: `gtk-4.0/gtk.css` is the Breeze symlink, so
  `gtk-4.0/colors.css` and `gtk-4.0/window_decorations.css` are not imported.
- `fcitx5/conf/cached_layouts` (a regenerated keyboard-layout cache) and
  `fcitx5/conf/classicui.conf.bak` (a stale backup) are deliberately untracked.
- `~/.gtkrc-2.0` sits outside `~/.config/` and is managed by nwg-look, so it is
  not part of this profile. On the Huawei machine it still says
  `gtk-icon-theme-name="Papirus-Dark"`, left over from the dark theme.

## Huawei GPU: GeForce MX150

`huawei/setup-mx150.sh` records the fix for this machine's discrete GPU, which
is not covered by `install-hyprland.sh` because it needs packages from the
third-party **archlinuxcn** repository rather than the official ones.

The MX150 (Pascal / GP108) is a legacy part: the unified 615 branch no longer
drives it, so it needs the 580xx legacy branch. Before the fix the card had no
kernel module at all — `nvidia-utils` had blacklisted `nouveau` while no NVIDIA
module was ever installed, so `/sys/bus/pci/devices/0000:01:00.0/driver` did not
exist and `nvidia-smi` failed outright.

```bash
sudo bash huawei/setup-mx150.sh
```

It installs `nvidia-580xx-dkms` / `nvidia-580xx-utils` (replacing the 615
`nvidia-utils`), `dkms`, `linux-headers`, `nvidia-prime`, `envycontrol` and
`nvtop`, rebuilds the initramfs, then self-checks and prints verification,
troubleshooting and rollback steps.

Status on the Huawei machine: applied and verified on 2026-10-12. DKMS reports
`nvidia/580.178.04 installed`, `nvidia`, `nvidia_drm`, `nvidia_modeset` and
`nvidia_uvm` are all loaded, and the bound driver version is `580.178.04`.
Requires the archlinuxcn repository in `/etc/pacman.conf`:

```ini
[archlinuxcn]
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
```

