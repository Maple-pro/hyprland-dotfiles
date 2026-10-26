#!/usr/bin/env bash
# Install a Lua-IPC-compatible Waybar build for the Huawei profile.
#
# Hyprland 0.55+ with the Lua config provider accepts only hl.dsp.* IPC
# dispatches, while packaged Waybar 0.15.0 still sends "dispatch workspace N";
# clicking a hyprland/workspaces button therefore does nothing. The profile's
# ~/.local/bin/waybar wrapper prefers the build installed here and falls back
# to /usr/bin/waybar when it is absent.
#
# The pinned package is the waybar-git build verified on this machine
# (Waybar v0.15.0-1091-gc15ec02ed). It is unpacked under ~/.local/lib, NOT
# installed through pacman, so the packaged waybar stays untouched.
#
# Usage:
#   bash huawei/update-waybar-git.sh             # fetch the pinned build
#   bash huawei/update-waybar-git.sh PKG.tar.zst # use a local package file
#   bash huawei/update-waybar-git.sh URL         # fetch a custom package
#
# WAYBAR_GIT_URL and WAYBAR_GIT_DEST override the default URL and install path.
# A custom URL skips the pinned checksum, so review the printed SHA-256 first.
#
# Remove the override once the official waybar package contains the fix:
# delete ~/.local/lib/waybar-git/ and the systemd drop-in
# 20-local-waybar-git.conf, then rerun huawei/install-hyprland.sh.
set -euo pipefail

pkg_version="0.15.0.r1091.gc15ec02-1"
pkg_sha256="395aadf4d4f66df50df3068f63db68ba749a0e633e26dcb0d988298e48dc44e3"
pkg_url="${WAYBAR_GIT_URL:-https://mirrors.ustc.edu.cn/archlinuxcn/x86_64/waybar-git-${pkg_version}-x86_64.pkg.tar.zst}"
dest="${WAYBAR_GIT_DEST:-$HOME/.local/lib/waybar-git/waybar}"

usage() {
	cat <<'EOF'
Usage: update-waybar-git.sh [PACKAGE.tar.zst | URL]

Without an argument, downloads the pinned archlinuxcn waybar-git package and
verifies its SHA-256. A local package path or URL is also accepted; a custom
URL skips the pinned checksum. The binary is installed to
~/.local/lib/waybar-git/waybar by default (WAYBAR_GIT_DEST overrides).
EOF
}

case "${1:-}" in
	-h | --help)
		usage
		exit 0
		;;
esac

need() {
	command -v "$1" >/dev/null 2>&1 || {
		printf 'error: %s is required\n' "$1" >&2
		exit 1
	}
}

need bsdtar
need install

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

arg="${1:-}"
if [[ -z "$arg" ]]; then
	need curl
	pkg="$workdir/waybar-git.pkg.tar.zst"
	printf 'Downloading %s\n' "$pkg_url"
	curl -fL --retry 3 --connect-timeout 10 -o "$pkg" "$pkg_url"
	if [[ -n "${WAYBAR_GIT_URL:-}" ]]; then
		sha256sum "$pkg"
	else
		printf '%s  %s\n' "$pkg_sha256" "$pkg" | sha256sum -c -
	fi
elif [[ "$arg" == http://* || "$arg" == https://* ]]; then
	need curl
	pkg="$workdir/waybar-git.pkg.tar.zst"
	printf 'Downloading %s\n' "$arg"
	curl -fL --retry 3 --connect-timeout 10 -o "$pkg" "$arg"
	sha256sum "$pkg"
else
	pkg="$arg"
fi

[[ -f "$pkg" ]] || {
	printf 'error: package not found: %s\n' "$pkg" >&2
	exit 1
}

bin="$workdir/waybar"
bsdtar -xOf "$pkg" usr/bin/waybar >"$bin" || {
	printf 'error: %s does not contain usr/bin/waybar\n' "$pkg" >&2
	exit 1
}

if [[ "$(head -c 4 "$bin" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]]; then
	printf 'error: extracted usr/bin/waybar is not an ELF binary\n' >&2
	exit 1
fi

if ! grep -aq 'Lua-based dispatch protocol' "$bin"; then
	printf 'error: %s lacks the Lua IPC adaptation; refusing to install\n' "$pkg" >&2
	exit 1
fi

install -Dm755 "$bin" "$dest"
printf 'Installed %s\n' "$dest"
"$dest" --version 2>&1 | sed -n '/^Waybar v/p'

cat <<'EOF'

Reload the user service to pick it up:
  systemctl --user daemon-reload
  systemctl --user restart waybar.service
EOF
