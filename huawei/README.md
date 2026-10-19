# Huawei 本机配置维护与部署

本目录记录 `/home/yangfeng` 这台 Huawei VLT-WX0 的配置，当前验证组合为
**Hyprland 0.56.2、Monique 0.8.3**。配置包含本机用户名、路径和
`eDP-1` / `HDMI-A-1`，不是自动适配任意账号与显示接口的通用模板。

## 用户配置安装

在仓库根目录运行：

```bash
bash huawei/install-hyprland.sh
systemctl --user daemon-reload
```

安装脚本使用 `pacman -Syu --needed` 做完整升级并安装官方仓库依赖，备份被覆盖文件后
复制配置。它不会启停当前桌面、切换登录管理器、修改 `/etc` 或安装第三方软件。
Monique 需要另外安装，且兼容层会检查版本与私有 API；升级后先复核兼容层。

除了原有主题与应用配置，安装范围还包括：

- `.config/systemd/user/` 的 Hyprland 会话 target、服务和 drop-in；
- `.local/bin/monique` / `moniqued`、`.local/lib/monique-hypr56/`；
- Monique GUI desktop entry 和用户级通知 D-Bus 服务入口；
- `.local/bin/et` 的 WPS 表格 XCB/RandR 兼容包装器；
- `.local/bin/Hyprland`、`.zprofile` 和清理过重复输入法变量的 `.xprofile`。

修改前请检查自己已有的 shell 配置；本机安装脚本会备份并覆盖这些明确列出的文件。

`monique/settings.json` 不入库。安装时只在缺失时创建部署策略：Lua 输出、按端口匹配、
不更新登录屏幕、由 Lua 负责工作区迁移。不会复制当前 active/pinned profile，也不会
覆盖已有设置。没有 Monique 软件包时，启动仍有内置显示器兜底，但已有档案的菜单切换
依赖 Monique 包及其 Python 模块，不能只复制几个包装器。

## 系统配置样例

`etc/` 与 `usr/` 是单独维护的系统路径样例，不会被用户配置安装器自动复制。

### 输入法环境

`etc/environment` 中的 GTK、Qt、XIM、SDL 值是输入法变量的唯一来源。请先将其键值
合并进系统 `/etc/environment`，不要覆盖该文件中其他应用需要的配置。
本机 greetd 的 PAM 链包含 `pam_env.so`；新会话会继承这些变量。

GTK 的 `fcitx` 模块有意保留：此前测试过 portal 文件对话框需要它；不要仅因为使用
Wayland 就全局删除它。GLFW 的 `ibus` 值由 Hyprland 会话设置，因为 Fcitx5 提供 IBus
前端。云拼音和剪贴板历史策略属于个人偏好，本次没有改变。

### Greetd 启动链

样例包括：

- `etc/greetd/config.toml`：tuigreet、会话目录与本机默认账号；
- `etc/greetd/wayland-sessions/hyprland.desktop`：指向本机启动器；
- `usr/local/bin/greetd-hyprland-session`：设置 PATH/会话变量并运行 start-hyprland，
  日志保存到 `~/.local/state/greetd/hyprland-session.log`。

这些文件要求系统已安装 greetd 和 tuigreet。部署前备份并比较现有文件，确认路径、
账号和会话目录；不要在正在工作的图形会话中重启或切换登录管理器。启动器必须可执行。
原来的 SDDM/start-hyprland 路径仍可使用用户配置，但要确保 `.local/bin` 优先于系统路径。

### 输入权限与 SSD 维护

Caps Lock 指示只读 `/sys/class/leds/*::capslock/brightness`，无需读取原始键盘事件。
本机已移除 `input` 组成员资格；如果重新部署，先确认没有其他工具依赖该组，再执行：

```bash
sudo gpasswd -d yangfeng input
```

现有桌面和用户管理器仍持有旧补充组，必须完整注销后重新登录；重启可确保旧进程全部退出。
不要将整份 `/etc/group` 或 `/etc/gshadow` 作为 dotfile 保存或覆盖。

本机根盘已确认是支持 discard 的 SSD，因此启用了：

```bash
sudo systemctl enable --now fstrim.timer
```

这是服务状态，不作为启用链接或运行期状态文件入库。对其他磁盘先检查硬件能力。

## 会话服务与使用行为

Hyprland 的启动回调运行 `session-start.sh`，只向 D-Bus/systemd 导入必要变量，随后
启动 `hyprland-session.target`，并拉起 graphical-session.target。会话退出监视器检查
本次 compositor 的 PID 与启动标识，结束后停止桌面服务。不要把各个服务额外全局 enable
来解决自启动；旧的 `moniqued.service` 全局 enable 如不再需要，应单独 disable。

关键服务：Dunst、hyprpolkitagent、hypridle、Waybar、moniqued、XSettings、电池定时器。
Waybar 强制使用 Wayland 后端；重启由 systemd 管理，日志进入 journal。

- 空闲 **600 秒锁屏**，尊重应用抑制请求；没有增加空闲自动休眠。
- 休眠前发出会话锁屏请求，`inhibit_sleep=3` 等待真实锁屏通知。
- 电池在 **20% / 10% / 5%** 跨阈值时通知，同次放电过程去重，不自动休眠。
- 普通顶层应用按默认工作区放置。对话框优先使用原生父窗口归属；隐藏父窗口的补偿
  只针对浮动/modal 对话框和唯一同进程同 class 顶层候选，不按当前焦点猜测多个父候选。
  Lua API 不暴露精确 transient parent，因此不承诺识别所有复杂多文档窗口关系。
- `special:`、`name:` 和正整数工作区使用明确选择器，不将内部负 ID 当作相对编号。
- 扩展模式在进入档案/拓扑变化时应用工作区分配，普通 reload 不撤销手动迁移。
- 显示器恢复等待连续稳定快照并避开 Monique 提交期；持久 FALLBACK 有有界救援。
- Monique 兼容层承担镜像输出重建、验证和失败恢复；状态栏恢复不主动关开显示器。
- 新投影仪不支持档案中的模式时回退到 preferred；切换失败用 Hyprland OSD 提示并记日志。

## 验证

从仓库根目录运行：

```bash
bash huawei/tests/run.sh
```

这些测试读取**仓库内的源文件**，不连接桌面、不切换真实输出、不启动窗口或服务：

- Lua/Shell/Python 语法、JSONC 行为断言、安装清单和可执行权限；
- 7 个显示器/工作区恢复场景；
- 6 个窗口归属与选择器场景；
- 2 个电池阈值与错误处理测试；
- 安装 Monique 0.8.3 时，另运行 5 个兼容层测试；缺失时明确跳过。

2026-10-19 在本机完成过额外的真实桌面验收：

- Dunst 停止后能通过 D-Bus 自动拉起，管理员 GUI 认证成功；
- 真实 GTK 对话框跟随隐藏的 special 工作区父窗口，同 class 独立窗口留在默认工作区；
- 原生窗口 resize 确实改变临时窗口尺寸；
- 仅内屏→复制→扩展→仅外屏切换，每个独立输出只有一条 Waybar，没有原有窗口消失，
  最后恢复测试前的外屏档案；
- Rofi window 模式能创建真实 Wayland 图层，Foot 配置检查通过；
- 关键服务 active、没有 failed 单元、Hyprland configerrors 为空。

没有自动执行真实休眠/唤醒、物理拔线或注销冷启动；这些仍需在无未保存工作的时段验收。

本机 Rofi 2.0.0 的 `-rasi-validate` 在最小主题上也会于 `display_cleanup` 崩溃；这与
日常菜单路径不同。正常配置/主题解析与菜单已经实测，可用以下方式检查解析路径：

```bash
rofi -config "$HOME/.config/rofi/config.rasi" -dump-config >/dev/null
rofi -config "$HOME/.config/rofi/config.rasi" -dump-theme >/dev/null
```

这绕过了有缺陷的校验子命令，不表示系统 Rofi 程序内部缺陷已修复。

## 日志与不入库的状态

```bash
journalctl --user -u dunst.service -u hypridle.service -u waybar.service
journalctl --user -u moniqued.service -u hyprpolkitagent.service
hyprctl configerrors
```

手动档案切换日志在 `~/.local/state/hyprland/projection.log`。

不要同步 `monitors.lua`、`monique/settings.json`、缓存、备份、Python 字节码、活动服务
启用链接、日志或编译后的 drm-free。四个作者档案保持入库，但仅 `last_applied_time`
变化无需同步。当前独立显示模式与显示器指纹同样属于运行期状态。
