# Legion 本机配置变更与维护

本目录保存 Legion 的用户配置；运行 `bash legion/tests/run.sh` 检查仓库源文件。
本机面板为 2560×1600@60、缩放 1.25。缓存、日志、认证 cookie、备份和 Monique 应用时间戳不入库。

## buffer region screenshots before replacing the clipboard

Super+S 截取区域并裁掉选区内侧 1px 边框，生产步骤全部成功后才替换剪贴板。保留 XWayland 的 xclip 和共享 Rofi 历史模式；Print 将整屏复制到 Wayland 剪贴板。
