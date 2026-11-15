#!/usr/bin/env bash
# pin-shot.sh — 截一块区域，然后把它"贴"在屏幕上（flameshot 贴图的对应物）
#
# 流程：slurp 选区 → grim 抓图 → pin-image.py 用 layer-shell overlay 置顶显示
# 贴图交互：左键拖动 / 滚轮缩放 / 中键复制 / 右键关闭
#
# 参数：
#   无参数      区域截图（slurp 选区）
#   --full      当前显示器整屏贴图
#   --clip      把剪贴板里的图片贴出来（wl-paste）
#   --file FILE 贴一张已有的图片（居中也行，给坐标也行）
set -uo pipefail

self=$(readlink -f "$0")
here=$(dirname "$self")
pin="$here/pin-image.py"
dir="${HYPR_PIN_DIR:-${XDG_RUNTIME_DIR:-/tmp}/hypr-pins}"

newimg() {
	mkdir -p "$dir" || exit 1
	echo "$dir/pin-$(date +%Y%m%d-%H%M%S)-$$.png"
}

# 只保留最近 30 张，避免 tmpfs 里越攒越多
prune() {
	local keep=30
	mapfile -t olds < <(ls -1t "$dir"/pin-*.png 2>/dev/null | tail -n +$((keep + 1)))
	((${#olds[@]})) && rm -f -- "${olds[@]}"
}

# exec：贴图进程直接继承这条快捷键的进程，关掉的就是它自己
launch() { exec python3 "$pin" "$@"; }

focused_monitor() {
	hyprctl -j monitors 2>/dev/null | python3 -c '
import json, sys
try:
    mons = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
m = next((x for x in mons if x.get("focused")), mons[0] if mons else None)
print(m["name"], m["x"], m["y"]) if m else sys.exit(1)
' 2>/dev/null
}

case "${1:-}" in
--full)
	# 拿不到 hyprctl 信息就退回整layout截图 + 居中，不影响主流程
	if read -r mon_name mon_x mon_y < <(focused_monitor) && [[ -n ${mon_name:-} ]]; then
		img=$(newimg)
		grim -o "$mon_name" - | magick png:- png32:"$img" || exit 1
		prune
		launch "$img" "$mon_x" "$mon_y"
	fi
	img=$(newimg)
	grim - | magick png:- png32:"$img" || exit 1
	prune
	launch "$img"
	;;
--clip)
	img=$(newimg)
	if ! wl-paste --type image/png >"$img" 2>/dev/null || [[ ! -s $img ]]; then
		rm -f "$img"
		hyprctl notify -1 3000 "0xffa0a0" "剪贴板里没有图片" >/dev/null 2>&1
		exit 1
	fi
	prune
	launch "$img"
	;;
--file)
	[[ -f ${2:-} ]] || exit 1
	launch "$(readlink -f "$2")" "${3:-}" "${4:-}"
	;;
esac

# 默认：区域截图
geo=$(slurp -w 2 -f '%wx%h+%x+%y') || exit 0
[[ -n $geo ]] || exit 0

if [[ $geo =~ ^([0-9]+)x([0-9]+)\+(-?[0-9]+)\+(-?[0-9]+)$ ]]; then
	w=${BASH_REMATCH[1]}
	h=${BASH_REMATCH[2]}
	x=${BASH_REMATCH[3]}
	y=${BASH_REMATCH[4]}
else
	exit 0
fi

img=$(newimg)

# grim 只认 "X,Y WxH" 这种几何写法（slurp 的 +偏移 写法它不认），所以重新拼一份
grim_geo="$x,$y ${w}x${h}"

# slurp 的边框压在内侧 1px；和 SUPER+S 一样 shave 1x1，所以贴图位置要 +1
if ((w > 2 && h > 2)); then
	grim -g "$grim_geo" - | magick png:- -shave 1x1 png32:"$img" || exit 1
	((x += 1, y += 1))
else
	grim -g "$grim_geo" "$img" || exit 1
fi

[[ -s $img ]] || exit 1
prune
launch "$img" "$x" "$y"
