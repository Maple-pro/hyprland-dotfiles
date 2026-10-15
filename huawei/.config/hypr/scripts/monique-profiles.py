#!/usr/bin/env python3
"""重建 4 个 monique 投影档案，并给 extend 加上工作区归属规则。

扩展模式：eDP-1（主屏）只留 workspace 1，其余 2-10 全部归 HDMI-A-1。
其它模式不加任何工作区规则，工作区不会被绑到已关闭的屏幕上。
"""

import copy
import json

from monique.detect import detect_backend
from monique.models import PositionMode, Profile, WorkspaceRule
from monique.profile_manager import ProfileManager

INT = "eDP-1"
EXT = "HDMI-A-1"
WS_MAIN = 1          # 主屏保留的工作区
WS_EXT_FIRST = 2     # 外接屏第一个工作区
WS_LAST = 10         # 快捷键能到的最后一个工作区

ipc = detect_backend()
live = {m.name: m for m in ipc.get_monitors()}
missing = [n for n in (INT, EXT) if n not in live]
if missing:
    raise SystemExit(f"missing monitors: {missing} (connected: {list(live)})")


def base(name):
    return copy.deepcopy(live[name])


def build(name, *, int_enabled, ext_enabled, mirror=False, ext_pos=PositionMode.AUTO):
    p = Profile(name=name)
    i = base(INT)
    e = base(EXT)

    i.enabled = int_enabled
    i.mirror_of = ""
    i.focus_at_startup = int_enabled
    if int_enabled:
        i.position_mode = PositionMode.EXPLICIT
        i.x, i.y = 0, 0

    e.enabled = ext_enabled
    e.mirror_of = INT if mirror else ""
    e.focus_at_startup = not int_enabled
    e.position_mode = ext_pos
    if ext_pos is PositionMode.EXPLICIT:
        e.x, e.y = 0, 0

    p.monitors = [i, e]
    return p


profiles = [
    build("pc-only", int_enabled=True, ext_enabled=False),
    build("mirror", int_enabled=True, ext_enabled=True, mirror=True, ext_pos=PositionMode.AUTO),
    build("extend", int_enabled=True, ext_enabled=True, ext_pos=PositionMode.AUTO_LEFT),
    build("external", int_enabled=False, ext_enabled=True, ext_pos=PositionMode.EXPLICIT),
]

# 只有扩展模式需要绑定工作区
extend = next(p for p in profiles if p.name == "extend")
extend.workspace_rules = [WorkspaceRule(workspace=str(WS_MAIN), monitor=INT, default=True)]
extend.workspace_rules += [
    WorkspaceRule(workspace=str(n), monitor=EXT, default=(n == WS_EXT_FIRST))
    for n in range(WS_EXT_FIRST, WS_LAST + 1)
]

mgr = ProfileManager()
for p in profiles:
    path = mgr.save(p)
    print(f"saved {p.name:9s} workspaces={len(p.workspace_rules):>2} -> {path.name}")

print("profiles:", json.dumps(mgr.list_profiles()))
