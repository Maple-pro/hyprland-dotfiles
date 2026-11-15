# Legion 本机配置变更与维护

本目录保存 Legion 的用户配置；运行 `bash legion/tests/run.sh` 检查仓库源文件。
本机面板为 2560×1600@60、缩放 1.25。缓存、日志、认证 cookie、备份和 Monique 应用时间戳不入库。

## buffer region screenshots before replacing the clipboard

Super+S 截取区域并裁掉选区内侧 1px 边框，生产步骤全部成功后才替换剪贴板。保留 XWayland 的 xclip 和共享 Rofi 历史模式；Print 将整屏复制到 Wayland 剪贴板。

## add HiDPI screenshot pins and discoverable shortcuts

Super+Shift+S 区域贴图；Shift+Print 当前屏幕贴图；Super+Alt+V 剪贴板图片贴图；Super+Alt+X 关闭全部贴图。左键拖动、滚轮缩放、中键复制、双击或右键关闭。按实际分数缩放从原图绘制；GTK3 分数缩放仍可能产生少量插值。Super+/ 的 cheatsheet 包含这些条目。

## reconcile monitor layouts without compositor Lua timers

显示事件通过外部 debounce 脚本等待布局稳定；不再注册合成器 Lua timer。保留工作区手动迁移，FALLBACK 恢复有次数上限，内屏恢复仍使用 2560×1600@60、1.25 倍缩放。

## guard session lifetime through the compositor socket

会话监视器检查合成器 socket，并给启动过程留出宽限时间；合成器退出后清理会话服务。

## tile file managers by default

Krusader 与 Dolphin 默认平铺；Super+V 仍可手动切换浮动。

## toggle mute only once per key press

扬声器与麦克风静音键不再长按重复切换；音量调节仍支持重复。

## remove the immediate Super+Escape logout shortcut

移除 Super+Esc 直接退出会话；使用 Super+X 电源菜单退出。

## disable idle auto-lock while retaining explicit locks

关闭空闲自动锁屏；Super+L 手动锁屏与休眠前锁屏继续生效。

## move the active workspace between monitors

Super+Shift+,/. 将整个当前工作区移到上一块或下一块显示器；单屏不操作。

## swap monitor workspaces with Super+Ctrl+S

Super+Ctrl+S 对调两块显示器上的工作区，不占用区域贴图快捷键。

## use the distribution Waybar binary

Waybar 使用 /usr/bin/waybar；保留启动锁与 GTK 隔离，旧本地构建不再被选择，旧下载脚本已移除。

## let window titles use the available Waybar width

窗口标题使用状态模块前的可用宽度，不再固定截断到 45 个字符。

## shorten unknown workspace application labels

未知应用的工作区标签取窗口 class 最后一段，现有手写缩写优先。

## separate workspace numbers from application labels

工作区序号与应用标签之间保留两个空格，便于辨认。

## restore the built-in workspace click handler

移除被当作 shell 命令执行的 on-click=activate，恢复模块内置工作区点击处理。

## strengthen tray popup labels and symbolic icons

托盘展开菜单文字为 14px、600 字重，符号图标随文字着色。

## render NetworkManager menu icons with the bar palette

Wi-Fi 左键菜单图标由 nm-applet 生成内嵌 PNG，因此生产端也使用与 Waybar 一致的 GTK 配色。托盘本体仍随网络状态与信号强度变化，不使用固定图标。切换主题后重新启动 nm-applet 与 Waybar。

## sync the local Fcitx notification preference

同步本机 Fcitx 通知偏好：隐藏列表已清空，Wayland 诊断通知不再被该列表屏蔽。
