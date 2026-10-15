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
# 切换统一走 monique-switch.sh：先写 pin 再切（避免 moniqued 按过期 pin 重放旧档案），
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

collect() {
    # Create/update the four profiles when a different external display is connected.
    "$HOME_DIR/.config/hypr/scripts/monique-profiles.py" --ensure >&2 || true
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
		entries+=("$marker ${LABELS[$i]}")
		names+=("$name")
	done

	# 没有任何 monique 档案时退回内置的端口名规则（project-mode.lua）
	if [ ${#entries[@]} -eq 0 ]; then
		builtin_only=1
		for i in "${!BUILTIN[@]}"; do
			marker="○"
			[ "${BUILTIN[$i]}" = "$active" ] && marker="●"
			entries+=("$marker ${LABELS[$i]}")
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
