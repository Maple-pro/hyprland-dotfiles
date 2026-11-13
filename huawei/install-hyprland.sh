#!/usr/bin/env bash
# =============================================================================
# huawei/install-hyprland.sh
#
# Installs the HUAWEI profile: official-repository packages + configuration.
#
# Target machine: HUAWEI VLT-WX0 (Intel i7-8550U, UHD 620 + GeForce MX150),
# Arch Linux, Hyprland 0.56 Lua configuration format, Catppuccin Latte (light)
# palette on Breeze Light / Papirus-Light.
#
# Usage
#   bash huawei/install-hyprland.sh        # recommended; escalates only for pacman
#   sudo bash huawei/install-hyprland.sh   # also works, installs into $SUDO_USER
#
# Existing configuration is copied to ~/.dotfiles-backup-<timestamp>/ before it
# is overwritten, and pacman runs with --needed, so re-running is safe.
#
# Packages that are not in the official repositories are printed at the end
# rather than installed, so this script never needs an AUR helper.
#
# See ../README.md for the profile layout, the theme-layer notes, and the two
# dconf settings that cannot be shipped in this repository.
# =============================================================================
set -euo pipefail

PROFILE="huawei"

if [[ -t 1 ]]; then
	BOLD=$'\033[1m'
	BLUE=$'\033[1;34m'
	YELLOW=$'\033[1;33m'
	RESET=$'\033[0m'
else
	BOLD=""
	BLUE=""
	YELLOW=""
	RESET=""
fi

say() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }

# -----------------------------------------------------------------------------
# Where we are, and whose home we are installing into
# -----------------------------------------------------------------------------
PROFILE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$PROFILE_DIR/.config/hypr" ]]; then
	echo "Run this from inside the '$PROFILE' profile directory." >&2
	exit 1
fi

if [[ ${EUID} -eq 0 ]]; then
	TARGET_USER="${SUDO_USER:-}"
	if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
		cat >&2 <<'EOF'
Cannot tell which user's ~/.config to install into.

Run it as your normal user (it calls sudo for pacman itself), or through sudo
from that user:

    bash huawei/install-hyprland.sh
    sudo bash huawei/install-hyprland.sh
EOF
		exit 1
	fi
	SUDO=()
else
	TARGET_USER="${USER}"
	if ! command -v sudo >/dev/null 2>&1; then
		echo "sudo is required to install packages, or run this script as root." >&2
		exit 1
	fi
	SUDO=(sudo)
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
	echo "Cannot resolve the home directory of user '$TARGET_USER'." >&2
	exit 1
fi
TARGET_GROUP="$(id -gn "$TARGET_USER")"

# -----------------------------------------------------------------------------
# Packages from the official repositories
# -----------------------------------------------------------------------------
PACKAGES=(
	# Hyprland stack
	hyprland
	hyprpaper
	hypridle
	hyprlock
	hyprpolkitagent
	hyprpicker
	xdg-desktop-portal-hyprland

	# bar, launcher, terminal, notifications
	waybar
	rofi
	foot
	dunst
	libnotify

	# screenshots and clipboard history
	grim
	slurp
	wl-clipboard
	cliphist

	# audio, backlight, media keys.
	# The volume keys call wpctl, which comes from wireplumber; pamixer and
	# pavucontrol are used by the waybar pulseaudio module.
	wireplumber
	pamixer
	pavucontrol
	brightnessctl
	playerctl

	# input method
	fcitx5
	fcitx5-chinese-addons
	fcitx5-configtool
	fcitx5-gtk
	fcitx5-qt

	# removable drives — udiskie is autostarted by hyprland.lua
	udiskie

	# GTK / Qt theming: Breeze Light + Papirus-Light, plus the tools that
	# write gtk-3.0/settings.ini and the gtk-4.0 symlinks
	breeze
	breeze-gtk
	papirus-icon-theme
	xsettingsd
	nwg-look

	# Qt Wayland platform plugins
	qt5-wayland
	qt6-wayland

	# interpreter for hypr/scripts/keybinds.lua (the SUPER + / cheatsheet)
	lua

	# status-notifier trays
	network-manager-applet
	blueman

	# fonts used by waybar, rofi and foot
	ttf-hack-nerd
	ttf-nerd-fonts-symbols
	noto-fonts-emoji

	# applications the default keybindings launch
	doublecmd-qt6
	fsearch
	kate

	# Python helpers provide session lifetime tracking, battery/LED state and
	# Monique compatibility. flock is supplied by the base util-linux package.
	python
)

# Deliberately not in PACKAGES: not available in the official repositories.
UNAVAILABLE=(
	"google-chrome    AUR — SUPER + B launches google-chrome-stable"
	"flclash          AUR — optional; its autostart line in hyprland.lua is commented out"
	"monique          AUR / third-party — the monitor-profile tool behind Super+P."
	"                 Without it hyprland.lua falls back to the built-in rules in"
	"                 scripts/project-mode.lua (port names, no profiles)."
)

# -----------------------------------------------------------------------------
# Configuration entries, relative to the profile directory. Each one is copied
# to the same relative path under the target user's home.
# -----------------------------------------------------------------------------
ENTRIES=(
	.config/hypr
	.config/waybar
	.config/rofi
	.config/monique
	.config/foot
	.config/dunst
	.config/udiskie
	.config/fcitx5
	.config/gtk-3.0
	.config/gtk-4.0
	.config/xsettingsd
	.config/nwg-look
	.config/systemd/user
	.config/kdeglobals
	.config/gtkrc
	.config/gtkrc-2.0
	# the Fcitx5 user theme that classicui.conf refers to
	.local/share/fcitx5/themes/catppuccin-latte-purple
	.local/share/dbus-1/services/org.freedesktop.Notifications.service
	.local/share/applications/com.github.monique.desktop
	.local/lib/monique-hypr56
	.local/bin/monique
	.local/bin/moniqued
	.local/bin/Hyprland
	.local/bin/et
	.zprofile
	.xprofile
)

# -----------------------------------------------------------------------------
# Install packages
# -----------------------------------------------------------------------------
say "Installing packages from the official repositories"
"${SUDO[@]}" pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

say "Refreshing the font cache"
if [[ ${EUID} -eq 0 ]]; then
	sudo -u "$TARGET_USER" fc-cache -f >/dev/null
else
	fc-cache -f >/dev/null
fi

# -----------------------------------------------------------------------------
# Install configuration
# -----------------------------------------------------------------------------
BACKUP_DIR="$TARGET_HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
installed=0
skipped=0

install_entry() {
	local rel="$1"
	local src="$PROFILE_DIR/$rel"
	local dest="$TARGET_HOME/$rel"

	if [[ ! -e "$src" && ! -L "$src" ]]; then
		warn "listed in this script but absent from the profile, skipping: $rel"
		skipped=$((skipped + 1))
		return 0
	fi

	if [[ -e "$dest" || -L "$dest" ]]; then
		mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
		cp -a "$dest" "$BACKUP_DIR/$(dirname "$rel")/"
		note "backed up  ~/$rel"
	fi

	mkdir -p "$(dirname "$dest")"
	# -T keeps an existing directory as the merge target instead of turning it
	# into dest/<basename>, which is what plain `cp -a` would do.
	cp -aT "$src" "$dest"

	if [[ ${EUID} -eq 0 ]]; then
		chown -R "$TARGET_USER:$TARGET_GROUP" "$dest"
	fi

	note "installed  ~/$rel"
	installed=$((installed + 1))
}

say "Installing the '$PROFILE' configuration into $TARGET_HOME"
for rel in "${ENTRIES[@]}"; do
	install_entry "$rel"
done

# Generated preferences are not tracked. Seed only deployment policy, never
# copy this machine's active/pinned profile or overwrite an existing choice.
MONIQUE_SETTINGS="$TARGET_HOME/.config/monique/settings.json"
if [[ ! -e "$MONIQUE_SETTINGS" ]]; then
	cat >"$MONIQUE_SETTINGS" <<'EOF'
{
  "hypr_config_format": "lua",
  "use_port_names": true,
  "update_sddm": false,
  "update_greetd": false,
  "migrate_workspaces": false
}
EOF
	chmod 600 "$MONIQUE_SETTINGS"
	if [[ ${EUID} -eq 0 ]]; then
		chown "$TARGET_USER:$TARGET_GROUP" "$MONIQUE_SETTINGS"
	fi
	note "created Monique deployment defaults (no saved active profile)"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo
say "$installed configuration entries installed"
if ((skipped == 1)); then
	warn "1 entry listed in this script was missing from the profile."
elif ((skipped > 1)); then
	warn "$skipped entries listed in this script were missing from the profile."
fi
if [[ -d "$BACKUP_DIR" ]]; then
	note "anything overwritten was saved under $BACKUP_DIR"
fi

if ((${#UNAVAILABLE[@]} > 0)); then
	echo
	say "Not in the official repositories — install manually if you want them"
	for item in "${UNAVAILABLE[@]}"; do
		note "$item"
	done
fi

cat <<EOF

${BOLD}Next steps${RESET}
  * Run: systemctl --user daemon-reload
    Then log out and select Hyprland in your login manager, or start-hyprland.
    The next session imports its environment and starts hyprland-session.target.

  * Read huawei/README.md before deploying the separate etc/ and usr/ snapshots.
    GTK/QT/XIM/SDL input-method values must be merged into /etc/environment.
    They are inherited through PAM; the user installer does not modify /etc.

  * Two settings live in dconf, so restore them by hand:
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'

  * gtk-3.0/settings.ini and gtk-3.0/colors.css are generated by KDE's
    kde-gtk-config; changing colours or icons in KDE overwrites them.

  * Hyprlock and Foot still use the dark Catppuccin Mocha palette while the
    rest of the profile is on Latte.

  * Super+P opens the projection-mode menu (pc-only / mirror / extend /
    external), also reachable as Ctrl+Tab inside rofi. It needs the monique
    0.8.3 package for the bundled compatibility layer. No third-party package
    is installed automatically. Without Monique, startup has built-in output
    rules; saved Monique profiles alone do not make the switch menu usable.

  * Review an old standalone 'systemctl --user enable moniqued.service' setup:
    disable that enablement if Monique should run only under this Hyprland target.
    Do not enable the individual graphical services globally just to autostart.

  * The Caps Lock module reads sysfs LEDs. The input group is not needed.
    Review other uses before removing that group; log out after a membership change.

  * Low-battery warnings trigger at 20/10/5 percent. Idle locks after ten minutes;
    before-sleep locking waits for the compositor's actual lock notification.

  * hypr/monitors.lua and .config/monique/settings.json are monique runtime
    state and are git-ignored, so they are not part of this profile. That is
    harmless: hyprland.lua falls back to scripts/project-mode.lua until monique
    writes a monitors.lua of its own. hypr/monitors.conf and
    hypr/workspaces.conf are stale leftovers on the machine, also untracked.

  * The GeForce MX150 is not covered here: it needs the 580xx legacy branch
    from the archlinuxcn repository. See setup-mx150.sh next to this script.

  * Reload after editing the Hyprland config:  hyprctl reload
EOF
