#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# project-mode-menu.sh —— 投影模式菜单（Super+P，以及 rofi 里按 Ctrl+Tab）
#
# 两种用法：
#
#  1) 作为 rofi 的 script modus（主用法）
#     已在 ~/.config/rofi/config.rasi 里注册：
#         modi: "drun,run,window,keybinds:...,project:<本脚本路径>";
#         display-project: "Projection";
#     之后：
#         Super+P                    → rofi -show project，直接打开这个菜单
#         任意 rofi 里按 Ctrl+Tab    → 切到 "Projection"
#                                      （rofi 默认 kb-mode-next = Shift+Right,Control+Tab）
#         Ctrl+Shift+Tab             → 往回切
#     协议（rofi-script(5)）：ROFI_RETV=0 时输出列表；ROFI_RETV=1 时 $1 是选中的
#     条目。处理完不输出任何东西，rofi 会自动关闭。
#
#  2) 直接运行（终端里用，或者没注册 modi 时）
#         project-mode-menu.sh            自己弹一个 rofi -dmenu
#         project-mode-menu.sh --list     只打印列表（调试）
#
# 切换统一走 monique-switch.sh：串行完成应用和状态提交（避免与 moniqued 交错），
# 离开镜像模式后的 wl_output 重建 / waybar 补建由 hyprland.lua 里的钩子负责。
# -----------------------------------------------------------------------------
set -uo pipefail

HOME_DIR=${HOME:-/root}
PROFILE_DIR="$HOME_DIR/.config/monique/profiles"
SETTINGS="$HOME_DIR/.config/monique/settings.json"
SWITCH="$HOME_DIR/.config/hypr/scripts/monique-switch.sh"
MODE_LUA="$HOME_DIR/.config/hypr/scripts/project-mode.lua"

# monique 档案名 / 内置模式名 / 显示文案（顺序与 hyprland.lua 里的循环一致）
MODES=(pc-only mirror extend external)
BUILTIN=(internal mirror extend external)
LABELS=(
	"仅电脑屏幕 PC screen only"
	"复制 Duplicate"
	"扩展 Extend"
	"仅投影仪 Second screen only"
)

entries=()
names=()
builtin_only=0

# 有没有"外接（非内屏）的真实输出"？内屏按端口名前缀判断（eDP/LVDS/DSI），
# FALLBACK 是 Hyprland 在所有真实输出关掉时造的虚拟输出，不算数。
# 注意用 monitors all：被关闭的输出也算"接着"（否则从 pc-only 回不去扩展）。
EXTERNAL_PRESENT=0
detect_external() {
	if hyprctl -j monitors all 2>/dev/null | python3 -c '
import json, re, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for m in monitors:
    name = (m.get("name") or "")
    if not name or name == "FALLBACK":
        continue
    if re.match(r"^(eDP|EDP|LVDS|DSI)", name):
        continue
    sys.exit(0)   # 找到外接屏
sys.exit(1)       # 只有内屏
'
	then
		EXTERNAL_PRESENT=1
	else
		EXTERNAL_PRESENT=0
	fi
}

# 需要外接屏的模式：没有外接屏时不允许切（避免把唯一的内屏切没 / 切了也没意义）
mode_allowed() {
	case "$1" in
		pc-only | internal) return 0 ;;
		*) [ "$EXTERNAL_PRESENT" = "1" ] ;;
	esac
}

# 没有外接屏时，在外接屏相关条目后面加个提示
hint_suffix() {
	# 只有"需要外接屏"的模式才加提示
	if mode_allowed "$1"; then
		printf ''
	else
		printf ' （未接外接屏）'
	fi
}

collect() {
	detect_external

	local active=""
	if [ -r "$SETTINGS" ]; then
		active=$(sed -n 's/.*"active_profile"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SETTINGS" | head -1)
	fi

	local i name marker
	for i in "${!MODES[@]}"; do
		name=${MODES[$i]}
		[ -r "$PROFILE_DIR/$name.json" ] || continue
		marker="○"
		[ "$name" = "$active" ] && marker="●"
		entries+=("$marker ${LABELS[$i]}$(hint_suffix "$name")")
		names+=("$name")
	done

	# 没有任何 monique 档案时退回内置的端口名规则（project-mode.lua）
	if [ ${#entries[@]} -eq 0 ]; then
		builtin_only=1
		for i in "${!BUILTIN[@]}"; do
			marker="○"
			[ "${BUILTIN[$i]}" = "$active" ] && marker="●"
			entries+=("$marker ${LABELS[$i]}$(hint_suffix "${BUILTIN[$i]}")")
			names+=("${BUILTIN[$i]}")
		done
	fi
}

# rofi script modus 的列表输出：\0 开头的是给 rofi 的元信息，后面才是条目
render() {
	printf '\0prompt\x1f投影模式\n'
	printf '\0no-custom\x1ftrue\n'
	printf '%s\n' "${entries[@]}"
}

apply() {
	local choice=$1 i
	for i in "${!entries[@]}"; do
		if [ "${entries[$i]}" = "$choice" ]; then
			if ! mode_allowed "${names[$i]}"; then
				# 用 Hyprland 原生 OSD 提示：不依赖通知守护进程是否在跑
				# （org.freedesktop.Notifications 由 dunst / KDE plasma 提供，
				# 未必一直可用），样式也与 project-mode.lua 的投影浮层一致
				hyprctl notify 3 4000 "rgb(d20f39)" \
					"未检测到外接显示器，已取消切换（复制/扩展/仅投影仪需要外接屏）" >/dev/null 2>&1
				return 1
			fi
			if [ "$builtin_only" = 1 ]; then
				setsid hyprctl eval "dofile(\"$MODE_LUA\").set(\"${names[$i]}\")" >/dev/null 2>&1 &
			else
				setsid "$SWITCH" "${names[$i]}" >/dev/null 2>&1 &
			fi
			disown 2>/dev/null || true
			return 0
		fi
	done
	return 1
}

collect

if [ "${1:-}" = "--list" ]; then
	printf '%s\n' "${entries[@]}"
	exit 0
fi

if [ -n "${ROFI_RETV:-}" ]; then
	# ---- 被 rofi 当作 script modus 调用 ----
	if [ "${ROFI_RETV}" = "0" ]; then
		render
	else
		# 选中某条：切换后不输出任何东西 → rofi 关闭
		apply "${1:-}" || true
	fi
	exit 0
fi

# ---- 直接运行：自己弹一个 rofi -dmenu ----
choice=$(render | rofi -dmenu -i -p "投影模式")
[ -n "${choice:-}" ] || exit 0
apply "$choice" || true
