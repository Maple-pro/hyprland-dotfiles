# Hyprland Basic Usage Guide

This document matches the Hyprland setup installed on this Arch Linux machine. KDE Plasma remains installed, so you can choose either session from SDDM.

## 1. Start Hyprland

From SDDM (the login screen):

1. Select your user.
2. In the session picker, choose **Hyprland**.
3. Enter your password and log in.

From a text console (TTY):

```bash
start-hyprland
```

The compositor reads its main configuration from:

```text
~/.config/hypr/hyprland.lua
```

After editing the config, reload it without logging out:

```bash
hyprctl reload
```

If a configuration error prevents startup, fix the file from a TTY or another terminal before starting Hyprland again.

## 2. The most important shortcut

The main modifier is **Super**, usually the Windows/Command key.

| Keys | Action |
| --- | --- |
| `Super + D` | Open application launcher (Rofi) |
| `Super + Return` | Open terminal (Foot) |
| `Super + B` | Open Google Chrome |
| `Super + E` | Open Dolphin file manager |
| `Super + K` | Open Kate editor |

If you forget a shortcut, use `Super + D` and type the name of the application you want.

## 3. Window management

Hyprland is a dynamic tiling compositor. New windows are placed automatically; you can still float them when needed.

| Keys | Action |
| --- | --- |
| `Super + Q` | Close focused window |
| `Super + F` | Toggle fullscreen |
| `Super + V` | Toggle floating mode |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split direction |
| `Super + arrow keys` | Move focus between windows |
| `Super + Shift + arrow keys` | Move focused window |
| `Super + Ctrl + arrow keys` | Resize focused window |
| Hold `Super` + drag left mouse | Move a floating window |
| Hold `Super` + drag right mouse | Resize a floating window |

## 4. Workspaces

| Keys | Action |
| --- | --- |
| `Super + 1` through `Super + 0` | Switch to workspaces 1 through 10 |
| `Super + Shift + 1` through `Super + Shift + 0` | Move focused window to that workspace |
| `Super + [` / `Super + ]` | Previous / next workspace |
| `Super + Backspace` | Switch back to the previous workspace |

## 5. Launcher and switcher

| Keys | Action |
| --- | --- |
| `Super + D` | Launch applications with Rofi |
| `Super + Tab` | Switch between open windows with Rofi |

Inside Rofi, type to filter, press `Enter` to open, and press `Esc` to cancel.

## 6. Screenshots, clipboard, color picker

| Keys | Action |
| --- | --- |
| `Super + S` | Select an area, capture it, and copy it to the clipboard |
| `Print` | Capture the full screen and copy it to the clipboard |
| `Super + C` | Pick a color from the screen with Hyprpicker |
| `Super + Shift + V` | Open the clipboard history picker with Cliphist + Rofi |

`Super + S` and `Print` do **not** save image files by default. They send the image directly to the Wayland clipboard.

To view an image that is currently on the clipboard:

```bash
wl-paste > /tmp/clipboard.png
gwenview /tmp/clipboard.png
```

The clipboard works through `wl-clipboard`. Use these commands in a terminal when needed:

```bash
wl-copy "some text"
wl-paste
grim - | wl-copy
grim -g "$(slurp)" - | wl-copy
```

For persistent clipboard history, `cliphist` is configured. Make sure it is installed:

```bash
sudo pacman -S --needed cliphist
```

Then press `Super + Shift + V`, select an entry with Rofi, and it will be copied back to the current clipboard.

## 7. Session controls

| Keys | Action |
| --- | --- |
| `Super + X` | Open the power menu: lock, suspend, log out, reboot, or power off |
| `Super + L` | Lock screen immediately |
| `Super + Escape` | Exit Hyprland |

## 8. Status bar and notifications

The top bar is **Waybar**. It shows workspaces, the focused window title, clock, network, audio, backlight, battery, memory, CPU, and tray icons.

Common bar interactions:

- Click a workspace number to switch to it.
- Scroll on the workspace module to cycle workspaces.
- Click the network module to open NetworkManager connection settings.
- The percentage next to the WiFi icon is the WiFi signal strength.
- Click the audio module to open Pavucontrol.
- Right-click the audio module to mute/unmute with Pamixer.
- Scroll on the backlight module to adjust brightness.
- Right-click the clock to toggle between short and full time formats.
- Press `Super + M` to reload Waybar after changing its style or config.

Notifications are handled by **Dunst**. They appear in the top-right corner.

## 9. Wallpaper and appearance

The wallpaper is managed by **Hyprpaper**:

```text
~/.config/hypr/hyprpaper.conf
```

Current wallpaper:

```text
~/.config/hypr/wallpapers/pastel-hills.jpg
```

To use a different image, replace the path in `hyprpaper.conf` and run:

```bash
hyprctl hyprpaper unload all
hyprctl hyprpaper preload /path/to/image.jpg
hyprctl hyprpaper wallpaper ",/path/to/image.jpg"
```

Main appearance files:

```text
~/.config/hypr/hyprland.lua    # gaps, borders, blur, animations, keybindings
~/.config/waybar/style.css     # bar colors and layout
~/.config/rofi/theme.rasi      # launcher appearance
~/.config/foot/foot.ini        # terminal appearance
~/.config/dunst/dunstrc        # notification appearance
```

## 10. Useful Hyprland commands

```bash
# Reload configuration
hyprctl reload

# List connected monitors
hyprctl monitors

# List active workspaces
hyprctl workspaces

# List open windows
hyprctl clients

# Change the active window to floating mode
hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'

# Switch to workspace 3
hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'

# Move the active window to workspace 4 and follow it
hyprctl dispatch 'hl.dsp.window.move({ workspace = 4, follow = true })'

# Close the active window
hyprctl dispatch 'hl.dsp.window.close()'

# Open the launcher from the command line
rofi -show drun

# Exit the compositor
hyprctl dispatch 'hl.dsp.exit()'
```

Note: because this setup uses the Lua configuration format, legacy `hyprctl dispatch togglefloating`, `workspace`, `movetoworkspace`, `killactive`, and `exit` commands do not work. Use the `hl.dsp.*` forms above instead.

## 11. Troubleshooting

### Hyprland is not shown at SDDM

Reinstall the `hyprland` package and check that this file exists:

```bash
ls -l /usr/share/wayland-sessions/hyprland.desktop
```

### Applications look blurry or use wrong scaling

Adjust the `hl.monitor` block in `~/.config/hypr/hyprland.lua`. The current setting is:

```lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
```

For a specific monitor and scale, use a line such as:

```lua
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
```

Run `hyprctl monitors` to find your monitor name.

### No notifications

Confirm Dunst is running:

```bash
pgrep -a dunst
```

If it is not running, start it with:

```bash
dunst &
```

### Lock screen does not appear after idle

Confirm Hypridle is running:

```bash
pgrep -a hypridle
```

If not, start it with:

```bash
hypridle &
```
