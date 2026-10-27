-- -----------------------------------------------------------------------------
-- Hyprland 0.55+ Lua configuration
-- Theme: soft Catppuccin Latte-inspired palette (light)
-- -----------------------------------------------------------------------------

local terminal = "foot"
local fileManager = "doublecmd"
local menu = "rofi -show drun"
local browser = "google-chrome-stable"
local editor = "kate"
local fileSearch = "fsearch"
local powerMenu = "/home/yangfeng/.config/hypr/scripts/powermenu.sh"
local keybindsHelp = "/home/yangfeng/.config/hypr/scripts/keybinds.lua"
local projectMode = "/home/yangfeng/.config/hypr/scripts/project-mode.lua"
-- Waybar is owned by systemd; this helper coalesces layout-triggered restarts.
local waybarRestart = "/home/yangfeng/.config/hypr/scripts/restart-waybar.sh"
local mainMod = "SUPER"

-- -----------------------------------------------------------------------------
-- Environment
-- -----------------------------------------------------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Fcitx GTK/Qt/XIM/SDL values have one source: /etc/environment (pam_env).
-- Keep GTK's fcitx module for the portal dialogs previously tested on this machine.
-- GLFW uses fcitx5's IBus frontend rather than a non-existent fcitx GLFW module.
hl.env("GLFW_IM_MODULE", "ibus")

-- -----------------------------------------------------------------------------
-- Monitors / 投影模式（Super+P 循环，等价于 Windows 的 Win+P）
-- -----------------------------------------------------------------------------
-- 显示器规则的来源，二选一（Hyprland 对同一个输出只采用第一条匹配的规则，
-- 所以两套规则绝不能同时发出去）：
--   1) monique 生成的 ~/.config/hypr/monitors.lua —— GUI 点 Apply 或
--      `monique --switch-profile <档案>` 写入，档案在 ~/.config/monique/profiles/
--      （pc-only / mirror / extend / external，按显示器描述匹配）
--   2) 内置兜底：scripts/project-mode.lua（monique 没装或还没建档案时按端口名配）
local monitorsLua = "/home/yangfeng/.config/hypr/monitors.lua"

-- Read saved rules through the startup guard before submitting monitor changes.
local workspaceRules = {}
local function load_monique_config()
	local ok, rules = dofile("/home/yangfeng/.config/hypr/scripts/projection-startup.lua").load(hl, monitorsLua)
	workspaceRules = rules
	return ok
end

local okProjectMode, ProjectMode = pcall(dofile, projectMode)

if load_monique_config() then
	-- monique 接管显示器规则
elseif okProjectMode and type(ProjectMode) == "table" and ProjectMode.attach then
	-- attach 把本文件环境里的 hl 交给模块
	ProjectMode.attach(hl).apply(ProjectMode.read(), { save = false })
else
	okProjectMode = false
	-- 回退：模块加载失败时，至少保证笔记本内屏可用 + 外接屏复制
	hl.monitor({
		output = "eDP-1",
		mode = "preferred",
		position = "0x0",
		scale = 1,
		disabled = false,
		mirror = "",
	})
	hl.monitor({
		output = "HDMI-A-1",
		mode = "1920x1080@60",
		position = "auto",
		scale = 1,
		disabled = false,
		mirror = "eDP-1",
	})
end

-- Unknown outputs stay usable even when the internal display is disabled.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "" })
dofile("/home/yangfeng/.config/hypr/scripts/projection-state.lua").setup(hl, workspaceRules, waybarRestart)

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("/home/yangfeng/.config/hypr/scripts/session-start.sh")
	hl.exec_cmd("hyprpaper")
	-- Environment import and systemd session services are ordered by session-start.sh.
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("blueman-applet")
	-- 移动硬盘 / U 盘：托盘指示器 + 自动挂载 + 挂载/卸载菜单
	hl.exec_cmd("udiskie")
	hl.exec_cmd("fcitx5 -d --replace")
	-- 开机自启的 foot 放进 special workspace（scratchpad），而不是挤在 1 号工作区。
	-- silent：只把窗口送过去，不切换当前视图；用 SUPER + ` 随时呼出 / 收起。
	hl.exec_cmd("[workspace special:scratchpad silent] foot")
	-- hl.exec_cmd("/usr/bin/flclash")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- -----------------------------------------------------------------------------
-- Permissions used by common utilities
-- -----------------------------------------------------------------------------
hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprpicker", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/slurp", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")

-- -----------------------------------------------------------------------------
-- Input
-- -----------------------------------------------------------------------------
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			drag_lock = true,
		},
	},
})

-- -----------------------------------------------------------------------------
-- Look and feel
-- -----------------------------------------------------------------------------
hl.config({
	general = {
		-- gaps_in     = 5,
		-- gaps_out    = { top = 5, right = 8, bottom = 8, left = 8 },
		-- border_size = 2,

		gaps_in = 0,
		gaps_out = { top = 0, right = 0, bottom = 0, left = 0 },
		border_size = 0,

		col = {
			active_border = {
				colors = { "rgba(8839efee)", "rgba(ea76cbee)" },
				-- angle  = 45,
			},
			inactive_border = "rgba(acb0becc)",
		},

		resize_on_border = true,
		hover_icon_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	cursor = {
		inactive_timeout = 4,
		no_hardware_cursors = false,
	},

	decoration = {
		-- 注释掉 = 没有设置 = 用默认值，而 shadow / blur 的默认值都是开。
		-- 想关必须显式写 false（这就是之前“drop shadow/blur”没生效的原因）。
		rounding = 0,
		shadow = { enabled = false },
		blur = { enabled = false },
	},

	animations = {
		enabled = true,
	},
})

-- Curves and animation tree
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- -----------------------------------------------------------------------------
-- Layouts
-- -----------------------------------------------------------------------------
hl.config({
	dwindle = {
		preserve_split = true,
		force_split = 0,
		smart_split = false,
	},

	master = {
		new_status = "master",
		new_on_top = true,
		mfact = 0.55,
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- -----------------------------------------------------------------------------
-- Misc
-- -----------------------------------------------------------------------------
hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		vrr = 1,
	},
})

-- -----------------------------------------------------------------------------
-- Window rules
-- -----------------------------------------------------------------------------

-- Fixed workspaces for daily-use apps.
-- The "silent" suffix moves the window to its workspace without dragging the
-- current view along, so launching an app never steals your focus.
--
-- 这张表是"应用默认工作区"的唯一来源，两处用它：
--   1) 下面的 window_rule 按 class 把窗口放到默认工作区；
--   2) scripts/dialog-workspace.lua 在新窗口打开后，把它挪到该应用已有窗口所在的工作区。
-- 规则故意不区分主窗口/弹窗：弹窗和主窗口同 class，靠第 2 步纠正。这样就不依赖
-- Hyprland 能否把弹窗识别成 floating / modal —— 很多应用的弹窗两个都不是，
-- 一旦规则把它们算进来，就会直接落到默认工作区（这就是之前的老问题）。
-- classes 里写应用真实的窗口 class（`hyprctl clients` 里的 class 字段），
-- 匹配用的正则由它生成；加应用/改 class 只动这张表。
local fixedWorkspaceApps = {
	{ name = "ws-wechat", workspace = 1, classes = { "wechat", "WeChat" } },
	{ name = "ws-doublecmd", workspace = 2, classes = { "doublecmd", "doublecmd-qt6", "doublecmd-qt", "Double Commander" } },
	{ name = "ws-chrome", workspace = 3, classes = { "google-chrome", "Google-chrome" } },
	-- WPS 表格 (Spreadsheets)
	{ name = "ws-spreadsheet", workspace = 4, classes = { "et" } },
	-- WPS 文字 (Writer) 与 WPS PDF（运行时窗口类是 "pdf"）
	{ name = "ws-word", workspace = 5, classes = { "wps" } },
	{ name = "ws-pdf", workspace = 5, classes = { "pdf", "wpspdf" } },
}


-- Escape regex metacharacters before joining application classes.
local function class_regex(classes)
	local parts = {}
	for _, class in ipairs(classes) do
		parts[#parts + 1] = (class:gsub("([%^%$%(%)%.%[%]%*%+%-%?%{%}%|%/])", "\\%1"))
	end
	if #parts == 1 then
		return "^" .. parts[1] .. "$"
	end
	return "^(" .. table.concat(parts, "|") .. ")$"
end

for _, app in ipairs(fixedWorkspaceApps) do
	hl.window_rule({
		name = app.name,
		match = { class = class_regex(app.classes) },
		workspace = app.workspace .. " silent",
	})
end

-- 弹窗跟随：规则先把窗口放到默认工作区，这里再按"应用已有窗口在哪"纠正一次
-- （不判断 floating/modal，只看 class + 哪个窗口是刚被聚焦的那个）。
dofile("/home/yangfeng/.config/hypr/scripts/dialog-workspace.lua").setup(hl, fixedWorkspaceApps)

-- FSearch: floating search palette instead of a tiled window.
hl.window_rule({
	name = "float-fsearch",
	match = { class = "^(fsearch|io\\.github\\.cboxdoerfer\\.FSearch)$" },
	float = true,
	size = { "(monitor_w*0.6)", "(monitor_h*0.6)" },
	center = true,
})

hl.window_rule({
	name = "float-file-manager",
	match = { class = "^(doublecmd|doublecmd-qt6|doublecmd-qt|Double Commander)$" },
	float = true,
	size = { "(monitor_w*0.75)", "(monitor_h*0.75)" },
	center = true,
})

hl.window_rule({
	name = "float-pavucontrol",
	match = { class = "^pavucontrol$" },
	float = true,
})

hl.window_rule({
	name = "float-blueman-manager",
	match = { class = "^blueman-manager$" },
	float = true,
})

hl.window_rule({
	name = "float-network-manager",
	match = { class = "^(nm-connection-editor|nm-applet)$" },
	float = true,
	center = true,
})

hl.window_rule({
	name = "float-picture-in-picture",
	match = { title = "^Picture-in-Picture$" },
	float = true,
	pin = true,
})

hl.window_rule({
	name = "flameshot-pin",
	match = { class = "^flameshot$", title = "^flameshot-pin$" },
	float = true,
	pin = true,
	no_focus = true,
	no_anim = true,
	no_shadow = true,
	no_blur = true,
	border_size = 0,
	rounding = 0,
})

-- hl.window_rule({
-- 	name = "fix-wechat",
-- 	match = { class = "wechat", title = "wechat" },
-- 	no_blur = true,
-- 	no_shadow = true,
-- 	border_size = 0,
-- })
--
-- hl.window_rule({
-- 	name = "fix-wps",
-- 	match = { class = "wps" },
-- 	no_blur = true,
-- 	no_shadow = true,
-- 	border_size = 0,
-- })

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- -----------------------------------------------------------------------------
-- Keybindings
-- -----------------------------------------------------------------------------

-- Launch applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(fileSearch), { description = "File search (FSearch)" })

-- Window control
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- 伪平铺原来在 Super+P，让位给「投影模式」后改到 Super+Shift+P
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tiling (was Super+P)" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- 投影模式：Super+P 弹 rofi 菜单直接选（仅电脑屏幕 / 复制 / 扩展 / 仅投影仪），
-- 当前模式在菜单里用 ● 标出。切换走 scripts/monique-switch.sh（加锁后完成应用与状态提交），
-- 离开镜像模式后的 wl_output 重建 / waybar 补建由上面的显示器钩子负责。
-- 想回到"按一下切下一个"的循环方式，把下面换成：
--   hl.dsp.exec_cmd("hyprctl eval 'dofile(\"" .. projectMode .. "\").cycle()'")
-- rofi -show project 用的是 config.rasi 里注册的 project 这个 modus；
-- 它同时也是 rofi 里的 Ctrl+Tab（kb-mode-next）能切到的那个 "Projection"。
hl.bind(
	mainMod .. " + P",
	hl.dsp.exec_cmd("rofi -show project"),
	{ description = "Projection mode menu (also Ctrl+Tab inside rofi)" }
)

-- Utilities
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(
	mainMod .. " + SHIFT + V",
	hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy")
)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(powerMenu))
hl.bind(
	mainMod .. " + SLASH",
	hl.dsp.exec_cmd(keybindsHelp),
	{ description = "Show keybind cheatsheet" }
)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("systemctl --user kill --kill-whom=main --signal=SIGUSR1 waybar.service"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exit())

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move active window
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Resize active window
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

-- Workspaces
for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + BRACKETLEFT", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + BRACKETRIGHT", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.focus({ workspace = "previous" }))

-- Scratchpad
hl.bind(mainMod .. " + GRAVE", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Mouse manipulation
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
