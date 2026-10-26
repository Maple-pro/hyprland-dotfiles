#!/usr/bin/env bash
# Shared rofi mode, including X11 clipboard contents and cliphist history.
set -euo pipefail

if [[ -z "${ROFI_RETV:-}" ]]; then
    exec rofi -show clipboard
fi
[[ "$ROFI_RETV" == 0 || "$ROFI_RETV" == 1 ]] || exit 0

runtime_dir="$(mktemp -d)"
trap 'rm -rf -- "$runtime_dir"' EXIT
x11_file="$runtime_dir/x11"

if [[ "$ROFI_RETV" == 0 ]]; then
    printf '\0prompt\x1fClipboard\n\0no-custom\x1ftrue\n'
    if timeout 2 xclip -selection clipboard -o -t image/png >"$x11_file" 2>/dev/null && [[ -s "$x11_file" ]]; then
        x11_size="$(du -h "$x11_file" | cut -f1)"
        printf '[X11 当前] [[ PNG 图片 %s ]]\0info\x1fx11:image/png\n' "$x11_size"
    elif timeout 2 xclip -selection clipboard -o -t UTF8_STRING >"$x11_file" 2>/dev/null && [[ -s "$x11_file" ]]; then
        x11_preview="$(tr '\n\t' '  ' <"$x11_file" | cut -c1-100)"
        printf '[X11 当前] %s\0info\x1fx11:UTF8_STRING\n' "$x11_preview"
    fi
    cliphist list | sed 's/^/[历史] /'
    exit 0
fi

choice="${1:-}"
[[ -n "$choice" ]] || exit 0
if [[ "$choice" == '[X11 当前] '* ]]; then
    case "${ROFI_INFO:-}" in
        x11:image/png) x11_type=image/png ;;
        x11:UTF8_STRING) x11_type=UTF8_STRING ;;
        *) exit 0 ;;
    esac
    if timeout 2 xclip -selection clipboard -o -t "$x11_type" >"$x11_file" 2>/dev/null && [[ -s "$x11_file" ]]; then
        xclip -selection clipboard -t "$x11_type" -i <"$x11_file" >/dev/null 2>&1
    fi
    exit 0
fi
[[ "$choice" == '[历史] '* ]] || exit 0
history_entry="${choice#'[历史] '}"
printf '%s\n' "$history_entry" | cliphist decode >"$runtime_dir/decoded"
mime_type="$(file --brief --mime-type "$runtime_dir/decoded")"
case "$mime_type" in
    image/*) ;;
    *) mime_type='text/plain;charset=utf-8' ;;
esac
xclip -selection clipboard -t "$mime_type" -i <"$runtime_dir/decoded" >/dev/null 2>&1
