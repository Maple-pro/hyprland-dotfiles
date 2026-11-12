#!/usr/bin/env python3
"""pin-image.py — 把一张图片"钉"在 Hyprland 屏幕上（类似 flameshot 的贴图）。

实现方式是 Wayland layer-shell 的 overlay 层，所以：
  * 永远盖在所有窗口之上（包括全屏窗口），不参与平铺 / 浮动规则；
  * 不进窗口列表，不抢键盘焦点（KeyboardMode.NONE）；
  * 位置精确落在截图时选中的那块区域上。

交互（鼠标事件走 GtkEventBox 的原生信号，不用 GtkGesture —— 后者在这些
layer surface 上收不到事件）：
  左键拖动   移动贴图
  左键双击   关闭
  滚轮       等比缩放
  中键       把这张图重新放进剪贴板
  右键       关闭

调试：PIN_DEBUG=1 时把收到的鼠标事件写进 $TMPDIR/pin-debug.log

用法：
  pin-image.py IMAGE [X Y]
  X Y 是全局布局坐标（逻辑像素，也就是 slurp 给出的坐标），省略则居中显示。
"""

import os

# 躲开只读的 /run/user/*/dconf，避免一串 dconf-CRITICAL 噪音
os.environ.setdefault("GSETTINGS_BACKEND", "memory")

import json
import signal
import socket
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GdkPixbuf, GLib, Gtk  # noqa: E402
from gi.repository import GtkLayerShell as LS  # noqa: E402

# 半透明蓝紫渐变细边框（dunst 那种 2px 描边、直角）
PAD = 2

CSS = """
#pinwin { background-color: transparent; }
#pinframe {
    background-image: linear-gradient(135deg,
        rgba(129, 106, 255, 0.85) 0%,
        rgba(178, 130, 255, 0.72) 55%,
        rgba(236, 120, 220, 0.58) 100%);
}
"""

ZOOM_STEP = 0.12
ZOOM_MIN = 0.15
ZOOM_MAX = 4.0
DRAG_INTERVAL_MS = 16

DEBUG = bool(os.environ.get("PIN_DEBUG"))
DEBUG_LOG = os.path.join(os.environ.get("TMPDIR", "/tmp"), "pin-debug.log")


def debug(msg):
    if not DEBUG:
        return
    try:
        with open(DEBUG_LOG, "a") as fh:
            fh.write(msg + "\n")
    except OSError:
        pass


class HyprCursor:
    """通过 Hyprland 命令 socket 读全局光标位置。

    Wayland 不给客户端全局指针坐标（GDK 的 x_root 在 Wayland 上等于窗口内坐标），
    所以拖动只能问合成器要位置。
    """

    def __init__(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or ""
        runtime = os.environ.get("XDG_RUNTIME_DIR") or ""
        self.path = os.path.join(runtime, "hypr", sig, ".socket.sock") if sig and runtime else ""

    def pos(self):
        if not self.path:
            return None
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.settimeout(0.4)
                sock.connect(self.path)
                sock.sendall(b"j/cursorpos")
                buf = b""
                while True:
                    chunk = sock.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
            data = json.loads(buf.decode("utf-8", "replace").strip())
            return int(data["x"]), int(data["y"])
        except (OSError, ValueError, KeyError):
            return None


class Pin:
    def __init__(self, path, x=None, y=None):
        self.path = path
        self.pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
        self.cursor = HyprCursor()

        display = Gdk.Display.get_default()
        monitor, gx, gy, gw, gh, reserved = self._target_monitor(display, x, y)
        self.scale = monitor.get_scale_factor() or 1

        # Hyprland 里 layer surface 的 margin 是相对"可用工作区"算的（会被 waybar 的
        # exclusive zone 顶下来一条），所以要么减掉 reserved，要么位置会整体偏移。
        rl, rt, rr, rb = reserved
        self.work_w = max(1, round(gw - rl - rr))
        self.work_h = max(1, round(gh - rt - rb))

        # 逻辑尺寸 = 物理像素 / 缩放
        self.base_w = max(1, round(self.pixbuf.get_width() / self.scale))
        self.base_h = max(1, round(self.pixbuf.get_height() / self.scale))
        self.zoom = 1.0
        self.cur_w = self.base_w
        self.cur_h = self.base_h

        # 位置存的是整个窗口（含渐变外框）的左上角
        if x is None or y is None:
            self.win_x = max(0, (self.work_w - self._win_w()) // 2)
            self.win_y = max(0, (self.work_h - self._win_h()) // 2)
        else:
            self.win_x = x - gx - rl - PAD
            self.win_y = y - gy - rt - PAD

        self.win = Gtk.Window(name="pinwin")
        self.win.set_decorated(False)
        self.win.set_resizable(False)
        self.win.set_skip_taskbar_hint(True)
        self.win.set_accept_focus(False)
        self.win.set_app_paintable(True)
        visual = self.win.get_screen().get_rgba_visual()
        if visual is not None:
            self.win.set_visual(visual)

        LS.init_for_window(self.win)
        LS.set_namespace(self.win, "hypr-pin")
        LS.set_layer(self.win, LS.Layer.OVERLAY)
        LS.set_monitor(self.win, monitor)
        # NONE：贴图永远不抢键盘输入，打字不会被它截走
        LS.set_keyboard_mode(self.win, LS.KeyboardMode.NONE)
        LS.set_exclusive_zone(self.win, 0)
        for edge in (LS.Edge.LEFT, LS.Edge.TOP):
            LS.set_anchor(self.win, edge, True)

        # 渐变外框：EventBox 负责画背景，也负责收鼠标事件（有独立 GdkWindow）
        self.frame = Gtk.EventBox(name="pinframe")
        self.frame.set_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.ENTER_NOTIFY_MASK
            | Gdk.EventMask.SCROLL_MASK
            | Gdk.EventMask.SMOOTH_SCROLL_MASK
        )
        self.image = Gtk.Image()
        self.image.set_margin_top(PAD)
        self.image.set_margin_bottom(PAD)
        self.image.set_margin_start(PAD)
        self.image.set_margin_end(PAD)
        self.frame.add(self.image)
        self.win.add(self.frame)

        self._drag_source = 0
        self._drag_last = None
        self._dragging = False

        self.win.connect("realize", self._on_realize)
        self.win.connect("destroy", Gtk.main_quit)
        self.frame.connect("button-press-event", self._on_press)
        self.frame.connect("button-release-event", self._on_release)
        self.frame.connect("scroll-event", self._on_scroll)

        self._apply_geometry()
        self.win.show_all()
        self._apply_geometry()

    # -- 显示器信息 -------------------------------------------------------
    @staticmethod
    def _gdk_at(display, gx, gy):
        for i in range(display.get_n_monitors()):
            mon = display.get_monitor(i)
            g = mon.get_geometry()
            if g.x == gx and g.y == gy:
                return mon
        return None

    @staticmethod
    def _gdk_containing(display, x, y):
        for i in range(display.get_n_monitors()):
            mon = display.get_monitor(i)
            g = mon.get_geometry()
            if g.x <= x < g.x + g.width and g.y <= y < g.y + g.height:
                return mon
        return None

    @staticmethod
    def _hypr_monitor(x, y):
        """找到 Hyprland 的显示器条目：给了坐标按坐标命中，否则用当前聚焦的那块。"""
        try:
            out = subprocess.run(
                ["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=2
            )
            mons = json.loads(out.stdout or "[]")
        except (OSError, ValueError, subprocess.SubprocessError):
            return None

        if x is not None and y is not None:
            for m in mons:
                s = m.get("scale") or 1
                gw, gh = m["width"] / s, m["height"] / s
                if m["x"] <= x < m["x"] + gw and m["y"] <= y < m["y"] + gh:
                    return m
            return None
        return next((m for m in mons if m.get("focused")), mons[0] if mons else None)

    def _target_monitor(self, display, x, y):
        """返回 (GdkMonitor, gx, gy, gw, gh, (left, top, right, bottom))。"""
        entry = self._hypr_monitor(x, y)
        if entry:
            s = entry.get("scale") or 1
            gx, gy = entry["x"], entry["y"]
            gw, gh = entry["width"] / s, entry["height"] / s
            res = list(entry.get("reserved") or [0, 0, 0, 0])[:4]
            res += [0] * (4 - len(res))
            mon = self._gdk_at(display, gx, gy)
            if mon is None and x is not None and y is not None:
                mon = self._gdk_containing(display, x, y)
            mon = mon or display.get_primary_monitor() or display.get_monitor(0)
            return (mon, gx, gy, gw, gh, tuple(res))

        mon = display.get_primary_monitor() or display.get_monitor(0)
        if x is not None and y is not None:
            mon = self._gdk_containing(display, x, y) or mon
        g = mon.get_geometry()
        return (mon, g.x, g.y, g.width, g.height, (0, 0, 0, 0))

    # -- 尺寸 / 定位 ------------------------------------------------------
    def _on_realize(self, *_):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            self.win.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _win_w(self):
        return self.cur_w + 2 * PAD

    def _win_h(self):
        return self.cur_h + 2 * PAD

    def _apply_geometry(self):
        self.cur_w = max(1, round(self.base_w * self.zoom))
        self.cur_h = max(1, round(self.base_h * self.zoom))
        # 每次从原图重新缩放，反复滚轮也不会累积失真
        scaled = self.pixbuf.scale_simple(
            max(1, round(self.cur_w * self.scale)),
            max(1, round(self.cur_h * self.scale)),
            GdkPixbuf.InterpType.BILINEAR,
        )
        self.image.set_from_pixbuf(scaled)
        self._clamp()
        self.win.resize(self._win_w(), self._win_h())
        self._push_position()

    def _clamp(self):
        self.win_x = min(max(0, self.win_x), max(0, self.work_w - self._win_w()))
        self.win_y = min(max(0, self.win_y), max(0, self.work_h - self._win_h()))

    def _push_position(self):
        LS.set_margin(self.win, LS.Edge.LEFT, self.win_x)
        LS.set_margin(self.win, LS.Edge.TOP, self.win_y)
        # layer-shell 的 margin 改动要靠一次尺寸协商才会 commit 出去
        self.win.queue_resize()

    def _move_by(self, dx, dy):
        if not dx and not dy:
            return
        self.win_x += dx
        self.win_y += dy
        self._clamp()
        self._push_position()
        debug(f"move -> {self.win_x},{self.win_y}")

    # -- 鼠标 -------------------------------------------------------------
    def _on_press(self, widget, event):
        debug(f"press btn={event.button} type={int(event.type)}")
        if event.button == 1:
            if event.type == Gdk.EventType._2BUTTON_PRESS:
                self.win.close()
                return True
            self._start_drag()
            return True
        if event.button == 2:
            self._copy()
            return True
        if event.button == 3:
            self.win.close()
            return True
        return False

    def _on_release(self, widget, event):
        debug(f"release btn={event.button}")
        if event.button == 1:
            self._stop_drag()
        return True

    def _start_drag(self):
        self._stop_drag()
        self._dragging = True
        self._drag_last = self.cursor.pos()
        if self._drag_last is None:
            debug("drag: no cursor socket, dragging disabled")
            return
        self._drag_source = GLib.timeout_add(DRAG_INTERVAL_MS, self._drag_tick)

    def _stop_drag(self):
        self._dragging = False
        if self._drag_source:
            GLib.source_remove(self._drag_source)
            self._drag_source = 0

    def _drag_tick(self):
        if not self._dragging:
            return False
        pos = self.cursor.pos()
        if pos is None:
            return True
        last = self._drag_last
        self._drag_last = pos
        if last is not None:
            self._move_by(pos[0] - last[0], pos[1] - last[1])
        return True

    def _on_scroll(self, widget, event):
        debug(f"scroll dir={int(event.direction)}")
        if event.direction == Gdk.ScrollDirection.SMOOTH:
            dy = event.delta_y
        elif event.direction == Gdk.ScrollDirection.UP:
            dy = -1.0
        else:
            dy = 1.0
        self.zoom = min(ZOOM_MAX, max(ZOOM_MIN, self.zoom * (1 - ZOOM_STEP * dy)))
        self._apply_geometry()
        return True

    def _copy(self):
        try:
            with open(self.path, "rb") as fh:
                subprocess.run(["wl-copy", "--type", "image/png"], stdin=fh, check=False)
        except (OSError, subprocess.SubprocessError):
            pass


def main():
    argv = [a for a in sys.argv[1:] if a]
    if not argv:
        print("usage: pin-image.py IMAGE [X Y]", file=sys.stderr)
        return 2
    path = os.path.abspath(argv[0])
    x = int(argv[1]) if len(argv) > 2 else None
    y = int(argv[2]) if len(argv) > 2 else None

    if DEBUG:
        debug(f"--- start pid={os.getpid()} img={path} at={x},{y}")

    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
    Pin(path, x, y)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
