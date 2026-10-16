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
# 这里做四件事：
#   1) flock 串行化：同一时刻只允许一个重启流程在跑（后来的排队等，不会并发）
#   2) 杀完之后等进程真的消失再启动，避免新旧实例并存
#   3) 启动 waybar 时用 9>&- 关掉锁 fd，否则 waybar 会继承这把 flock 一直握着锁，
#      下一次重启会永远卡在 flock 上（见文件末尾的说明）
#   4) 起完再数一遍进程数，发现 >1 就补杀重来
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

# 9>&- ：把锁 fd 从 waybar 里关掉。bash 的重定向 fd 默认不带 CLOEXEC，
# waybar 会继承 fd 9，于是它活着的时候就一直替脚本"握着"这把 flock；
# 之后再有人调本脚本就会永远卡在 flock 9 上（换了显示器/切了档案 bar 不重建、
# 或者旧 bar 一直留着，就是这么来的）。
setsid waybar >/dev/null 2>&1 9>&- &
disown 2>/dev/null || true

# 起完再确认一次：此刻应当只有一个 waybar（本脚本持有锁，别人插不进来）。
# 万一有漏网的（比如手工启动的旧实例在锁外残留），补杀一轮，宁可多等也别留两个。
for _ in $(seq 1 20); do
	pgrep -x waybar >/dev/null 2>&1 && break
	sleep 0.1
done
running=$(pgrep -x waybar 2>/dev/null | wc -l)
if [ "$running" -gt 1 ]; then
	pkill -x waybar 2>/dev/null || true
	for _ in $(seq 1 30); do
		pgrep -x waybar >/dev/null 2>&1 || break
		sleep 0.1
	done
	setsid waybar >/dev/null 2>&1 9>&- &
	disown 2>/dev/null || true
fi
