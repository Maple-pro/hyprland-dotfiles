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
