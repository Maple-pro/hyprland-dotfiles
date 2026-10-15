#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# monique-switch.sh —— 切换 monique 档案（供 Super+P 调用）
#
# 为什么不能直接 `monique --switch-profile X`：
#   moniqued 在收到显示器增删事件时会去读 settings.json 里的 pinned_profile。
#   而切换档案本身就会触发这些事件（关/开外接屏），此刻 monique 还没来得及把
#   pin 更新成目标档案，于是守护进程会按"上一次的 pin"把旧档案再应用一遍，
#   实测会连播 external → pc-only → mirror 好几个档案，每播一次都把工作区、
#   窗口在两块屏之间搬一次 —— 表现就是"切过去之后工作区丢了/调不出来"。
#
#   所以这里先把 pin 写目标档案，再执行切换：切换过程中守护进程无论什么时候
#   读 pin，得到的都是我们想要的那一个，重复应用也是幂等的。
#
# 用法：monique-switch.sh <档案名>
# -----------------------------------------------------------------------------
set -euo pipefail

name=${1:?usage: monique-switch.sh <profile-name>}

PYTHON=python3
"$PYTHON" "$HOME/.config/hypr/scripts/monique-profiles.py" --ensure

"$PYTHON" - "$name" <<'PY'
import sys

from monique.detect import detect_backend
from monique.utils import save_pinned_profile, load_app_settings, save_app_settings

name = sys.argv[1]
ipc = detect_backend()
# 用 monitors all：被禁用的输出也算，这样 pin 的指纹在 pc-only/extend/mirror
# 之间保持一致，不会因为某块屏此刻是关的而对不上。
monitors = ipc.get_monitors()
if name != "pc-only" and not any(not m.name.startswith(("eDP-", "LVDS-")) for m in monitors):
    import subprocess
    subprocess.run(["notify-send", "投影模式", "请先连接外接显示器"], check=False)
    raise SystemExit("No external display connected; keeping the laptop panel enabled")
connected = sorted(m.description for m in monitors if m.description)
# Projection switching manages the user session, not privileged login screens.
settings = load_app_settings()
settings.update(hypr_config_format="lua", update_sddm=False, update_greetd=False)
save_app_settings(settings)
save_pinned_profile(name, connected)
PY

exec monique --switch-profile "$name"
