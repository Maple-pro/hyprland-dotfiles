#!/usr/bin/env bash
# =============================================================================
# legion/install-hyprland.sh
#
# Installs the LEGION profile: official-repository packages + configuration.
#
# Target machine: Lenovo Legion laptop, Arch Linux, Hyprland 0.56 Lua
# configuration format, Catppuccin Mocha (dark) palette on Papirus-Dark.
#
# Usage
#   bash legion/install-hyprland.sh        # recommended; escalates only for pacman
#   sudo bash legion/install-hyprland.sh   # also works, installs into $SUDO_USER
#
# Existing configuration is copied to ~/.dotfiles-backup-<timestamp>/ before it
# is overwritten, and pacman runs with --needed, so re-running is safe.
#
# Packages that are not in the official repositories are printed at the end
# rather than installed, so this script never needs an AUR helper.
#
# See ../README.md for the profile layout.
# =============================================================================
set -euo pipefail

PROFILE="legion"

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

    bash legion/install-hyprland.sh
    sudo bash legion/install-hyprland.sh
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

	# screenshots and clipboard history.
	# legion pipes grim into xclip (huawei uses wl-copy instead), and the
	# clipboard menu script reads cliphist.
	grim
	slurp
	xclip
	wl-clipboard
	cliphist

	# audio, backlight, media keys.
	# legion uses pamixer and pactl, not wpctl, so libpulse is needed too.
	pamixer
	pavucontrol
	libpulse
	brightnessctl
	playerctl

	# input method
	fcitx5
	fcitx5-chinese-addons
	fcitx5-configtool
	fcitx5-gtk
	fcitx5-qt

	# removable drives — udiskie --smart-tray is autostarted by hyprland.lua
	udiskie

	# icons used by gtk-only/gtk-3.0/settings.ini (Papirus-Dark)
	papirus-icon-theme

	# Qt Wayland platform plugins
	qt5-wayland
	qt6-wayland

	# hypr/scripts/apply-rounding.sh rewrites the waybar CSS with perl
	perl

	# hyprland.lua runs /usr/lib/pam_kwallet_init at startup
	kwallet-pam

	# apply-rounding.sh reports through notify-send, and hyprland.lua merges
	# ~/.Xresources with xrdb
	libnotify
	xorg-xrdb

	# status-notifier trays
	network-manager-applet
	blueman

	# fonts used by waybar, rofi and foot
	ttf-hack-nerd
	ttf-nerd-fonts-symbols
	noto-fonts-emoji

	# applications the default keybindings launch
	krusader
	kate
)

# Deliberately not in PACKAGES: not available in the official repositories.
UNAVAILABLE=(
	"google-chrome    AUR — SUPER + B launches google-chrome-stable"
	"mihomo-party     AUR / third-party — the waybar 'clash' module, its on-click,"
	"                 the clash-party.sh script and an autostart line all expect"
	"                 mihomo-party, with a copy under /opt/clash-party"
)

# -----------------------------------------------------------------------------
# Configuration entries, relative to the profile directory. Each one is copied
# to the same relative path under the target user's home.
#
# waybar/ carries the gtk-only/gtk-3.0 settings and scripts/ used by
# start-waybar.sh, so installing it covers those as well.
# -----------------------------------------------------------------------------
ENTRIES=(
	.config/hypr
	.config/waybar
	.config/rofi
	.config/foot
	.config/dunst
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

if [[ ! -f "$TARGET_HOME/.Xresources" ]]; then
	echo
	warn "~/.Xresources is missing, but hyprland.lua runs"
	warn "'xrdb -merge ~/.Xresources' at every startup."
	warn "That file is not part of this repository — recreate it if you rely"
	warn "on X resource settings."
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
  * Log out and pick the Hyprland session in SDDM, or run: start-hyprland

  * Waybar is started through hypr/scripts/start-waybar.sh, which points
    XDG_CONFIG_HOME at waybar/gtk-only and uses the keyfile GSettings backend.

  * hypr/scripts/apply-rounding.sh rewrites style.css in place; keep the
    repository copy as the source of truth and re-install after editing.

  * Reload after editing the Hyprland config:  hyprctl reload
EOF
