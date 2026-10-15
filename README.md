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
huawei/.config/monique/profiles/     The four projection profiles (the real monique config)
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
legion/.config/rofi/                 Rofi launcher, keybind cheatsheet and projection menu
legion/.config/monique/profiles/     Legion projection profiles
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
cp -a huawei/.config/monique ~/.config/
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

## Legion shortcuts and projection modes

- **Super+/** opens the Rofi cheatsheet, reading the current Lua configuration
  (including loop-generated bindings). It replaces the old HotKeyHub command.
- **Super+A** opens FSearch as a floating search window.
- **Super+P** opens the four-mode projection menu; pseudo-tiling moves to
  **Super+Shift+P**. Ctrl+Tab inside Rofi also reaches the projection menu.
- New app windows default to WeChat workspace 1, Krusader 2, Chrome 3,
  WPS spreadsheets 4, WPS Writer/PDF 5. Later windows of the same class follow
  an existing window, preferring the active workspace; this includes dialogs
  and additional main windows. Existing windows are not relocated on reload.

The Legion panel stays at **2560×1600@60, scale 1.25**. Projection profiles
use the external display's preferred mode at scale 1. In extend mode the
external display is to the left, with workspaces 2–10; workspace 1 stays on
the panel. The initial profile is `pc-only`.

Install Monique from the AUR (`yay -S monique`) or from its official source.
On this machine Monique is installed through `yay` and managed by pacman;
helpers use the system `python3` and `monique` commands.

`hypr/scripts/monique-profiles.py --ensure` builds the four profiles when the
menu opens or a mode is selected, using actual monitor identities. A new
external display causes the generated profiles to be rebuilt; edits are kept
when the hardware identity is unchanged. Run without `--ensure` to explicitly
rebuild. With no external display connected, the definitions contain an
HDMI placeholder using its preferred mode; the switch wrapper refuses all
modes except `pc-only` until a real external display is detected. The fallback
Lua module starts in internal-only mode on a fresh installation.

Switching sets Monique to Lua output and disables login-screen updates, so it
needs no administrator authentication. Monique GUI also uses these saved
preferences. The hotplug daemon is not required for the menu and is not
automatically enabled. Waybar recovery calls Legion's `start-waybar.sh` to
preserve its GTK isolation, and releases the restart lock before launching it.

`hypr/monitors.lua` and `monique/settings.json` are generated state and ignored;
only profile definitions are tracked. Monique changes `last_applied_time` in
those profiles; timestamp-only differences do not need syncing. Back up local
profiles before deploying the repository copies again.

## Huawei projection modes (Super+P)

The Huawei machine has a Windows-style display switcher on **Super+P**, plus a
`Projection` mode reachable with **Ctrl+Tab** inside any rofi window. Four
profiles are defined:

| Profile | Laptop panel (eDP-1) | External screen (HDMI-A-1) |
| --- | --- | --- |
| `pc-only` | on | off |
| `mirror` | on | mirrors eDP-1 |
| `extend` | on, workspace 1 | on, to the left, workspaces 2–10 |
| `external` | off | on |

How the pieces fit together:

- `huawei/.config/monique/profiles/` holds the four profile definitions — the
  real configuration (see `.gitignore` for what is deliberately left out).
  [monique](https://github.com/ToRvaLDz/monique) is an AUR/third-party tool, so
  `install-hyprland.sh` only prints it as a hint rather than installing it.
- `hyprland.lua` loads `monitors.lua` when monique has written one, and falls
  back to `scripts/project-mode.lua` (port-name rules, no profiles) when it has
  not. It never applies both: Hyprland honours only the first matching rule per
  output, so the two sets must not be emitted together.
- `scripts/monique-switch.sh` writes monique's *pinned* profile **before**
  switching. Without that ordering, `moniqued` reacts to the monitor hotplug
  that the switch itself causes, reads the stale pin, and replays the previous
  profile — which shuffles windows and workspaces between screens.
- `scripts/restart-waybar.sh` serialises waybar restarts with `flock` and waits
  for the old process to exit. Several triggers (layout hook, mirror recovery)
  can fire within the same second, and concurrent `pkill; waybar` pairs leave
  two bar instances stacked on every screen.
- Monitor changes are handled in `hyprland.lua`: it corrects workspace
  ownership, rescues workspaces stranded on a mirror, and disables-then-enables
  an output that just left mirror mode (Hyprland does not always rebuild its
  `wl_output`, so waybar would never draw a bar there). Cross-reload state goes
  through `~/.cache/hypr/monitor-state`.
- `scripts/project-mode-menu.sh` is the rofi script mode (registered as
  `project:` in `rofi/config.rasi`), and it marks the active profile with `●`.
- `scripts/monique-profiles.py` rebuilds all four profiles from the currently
  detected monitors, and gives `extend` its workspace rules.

Runtime state is kept out of git (see `.gitignore`):

- `hypr/monitors.lua` and `monique/settings.json` are rewritten by monique on
  every Apply and profile switch, so they are ignored and are **not** part of a
  clone. `hyprland.lua` reads `monitors.lua` when monique has written one and
  falls back to `scripts/project-mode.lua` when it has not, so a fresh clone
  starts correctly before the first Apply; only the profiles themselves need to
  exist for the menu to work.
- `hypr/monitors.conf` and `hypr/workspaces.conf` are left over on the machine
  and are not tracked. The first is a stale Hyprlang artefact from before
  monique was switched to the Lua config format (it still says the external
  screen is disabled, while the running session follows `monitors.lua`); the
  second is empty.
- The profile JSONs *are* tracked, but each carries a `last_applied_time` that
  monique rewrites on Apply. Applying a profile can therefore leave a one-line
  diff in that profile's file — when that is the only change, there is nothing
  worth syncing.

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

