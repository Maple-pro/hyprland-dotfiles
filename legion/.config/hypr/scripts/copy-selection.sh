#!/usr/bin/env bash
set -euo pipefail

# Buffer binary output until every producer has succeeded.
result=$(mktemp "${XDG_RUNTIME_DIR:?}/hypr-copy.XXXXXXXX")
trap 'rm -f -- "$result"' EXIT

case "${1:-}" in
  region)
    geometry=$(slurp) || exit 0
    [[ -n $geometry ]] || exit 0
    grim -g "$geometry" - | magick png:- -shave 1x1 png32:"$result"
    ;;
  history)
    exec "$(dirname -- "$(readlink -f "$0")")/clipboard-menu.sh"
    ;;
  *) exit 2 ;;
esac

[[ -s $result ]] || exit 1
xclip -selection clipboard -t image/png -i < "$result"
