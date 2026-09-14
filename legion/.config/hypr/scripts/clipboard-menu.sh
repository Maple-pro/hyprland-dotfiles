#!/usr/bin/env bash

set -u

runtime_dir="$(mktemp -d)"
trap 'rm -rf -- "$runtime_dir"' EXIT

history_file="$runtime_dir/history"
x11_file="$runtime_dir/x11"
menu_file="$runtime_dir/menu"

cliphist list >"$history_file"
: >"$menu_file"

x11_type=""
if timeout 2 xclip -selection clipboard -o -t image/png >"$x11_file" 2>/dev/null && [[ -s "$x11_file" ]]; then
	x11_type="image/png"
	x11_size="$(du -h "$x11_file" | cut -f1)"
	printf '[X11 当前] [[ PNG 图片 %s ]]\n' "$x11_size" >>"$menu_file"
elif timeout 2 xclip -selection clipboard -o -t UTF8_STRING >"$x11_file" 2>/dev/null && [[ -s "$x11_file" ]]; then
	x11_type="text/plain;charset=utf-8"
	x11_preview="$(tr '\n\t' '  ' <"$x11_file" | cut -c1-100)"
	printf '[X11 当前] %s\n' "$x11_preview" >>"$menu_file"
fi

sed 's/^/[历史] /' "$history_file" >>"$menu_file"

choice="$(rofi -dmenu -i -p Clipboard <"$menu_file")" || exit 0
[[ -n "$choice" ]] || exit 0

if [[ "$choice" == '[X11 当前] '* ]]; then
	[[ -n "$x11_type" ]] || exit 1
	xclip -selection clipboard -t "$x11_type" -i <"$x11_file"
	exit 0
fi

history_entry="${choice#'[历史] '}"
printf '%s\n' "$history_entry" | cliphist decode >"$runtime_dir/decoded"

mime_type="$(file --brief --mime-type "$runtime_dir/decoded")"
case "$mime_type" in
	image/*)
		xclip -selection clipboard -t "$mime_type" -i <"$runtime_dir/decoded"
		;;
	*)
		xclip -selection clipboard -t 'text/plain;charset=utf-8' -i <"$runtime_dir/decoded"
		;;
esac
