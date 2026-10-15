#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# restart-waybar.sh —— 重启 waybar，保证任何时刻只有一个实例
#
# 为什么需要它：waybar 只在启动时按当时的输出建 bar，所以布局变化后要重启它。
# 但触发点不止一处（hyprland.lua 里的布局钩子、离开镜像模式后的自愈命令），
# 它们可能在同一秒内各跑一次 "pkill waybar; sleep; waybar"：
#   - 两次 pkill 都发生在对方启动之前 → 谁也没杀掉谁 → 屏幕上两条 bar 叠在一起
# 实测就是这样出现两个 waybar 进程、每块屏两条 bar 的。
#
# 这里做两件事：
#   1) flock 串行化：同一时刻只允许一个重启流程在跑（后来的排队等，不会并发）
#   2) 杀完之后等进程真的消失再启动，避免新旧实例并存
# -----------------------------------------------------------------------------
set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/.restart-waybar.lock"
flock 9

pkill -x waybar 2>/dev/null || true
for _ in $(seq 1 30); do
	pgrep -x waybar >/dev/null 2>&1 || break
	sleep 0.1
done
# 还不走就强杀，宁可多等一会也不要留下两个实例
if pgrep -x waybar >/dev/null 2>&1; then
	pkill -9 -x waybar 2>/dev/null || true
	sleep 0.2
fi

setsid "$HOME/.config/hypr/scripts/start-waybar.sh" 9>&- >/dev/null 2>&1 &
disown 2>/dev/null || true
