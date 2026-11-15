-- -----------------------------------------------------------------------------
-- Hyprland 0.55+ Lua configuration
-- Theme: soft Catppuccin Mocha-inspired palette
-- -----------------------------------------------------------------------------

local terminal = "foot"
local fileManager = "krusader"
local menu = "rofi -show drun"
local browser = "google-chrome-stable"
local editor = "kate"
local powerMenu = "/home/yangfeng/.config/hypr/scripts/powermenu.sh"
local fileSearch = "fsearch"
local keybindsHelp = "/home/yangfeng/.config/hypr/scripts/keybinds.lua"
local projectMode = "/home/yangfeng/.config/hypr/scripts/project-mode.lua"
local waybarRestart = "/home/yangfeng/.config/hypr/scripts/restart-waybar.sh"
local copySelection = "/home/yangfeng/.config/hypr/scripts/copy-selection.sh"
local mainMod = "SUPER"

-- 切换圆角 / margin：true = 圆角 + 外边距，false = 0 圆角 + 0 外边距
local rounded = false

-- -----------------------------------------------------------------------------
-- Environment
-- -----------------------------------------------------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_SCALE_FACTOR", "1.25")
hl.env("QT_SCALE_FACTOR_ROUNDING_POLICY", "RoundPreferFloor")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XFT_DPI", "120")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("ELECTRON_TRAY_IMPL", "statusnotifier")

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
		mode = "2560x1600@60",
		position = "0x0",
		scale = 1.25,
		disabled = false,
		mirror = "",
	})
	hl.monitor({
		output = "HDMI-A-1",
		mode = "preferred",
		position = "auto",
		scale = 1,
		disabled = false,
		mirror = "eDP-1",
	})
end

-- Unknown outputs stay usable even when the internal display is disabled.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "" })
dofile("/home/yangfeng/.config/hypr/scripts/projection-state.lua").setup(hl, workspaceRules, waybarRestart)

hl.config({
	xwayland = {
		force_zero_scaling = true,
		use_nearest_neighbor = true,
	},
})

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("/home/yangfeng/.config/hypr/scripts/session-start.sh")
	hl.exec_cmd("/usr/lib/pam_kwallet_init")
	hl.exec_cmd("xrdb -merge /home/yangfeng/.Xresources")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("/home/yangfeng/.config/hypr/scripts/apply-rounding.sh apply " .. (rounded and "rounded" or "square"))
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("[workspace special:scratchpad silent] foot")
	hl.exec_cmd("sleep 3 && mihomo-party --enable-features-StatusNotifierItem -ozone-platform-hint=auto")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("udiskie --smart-tray")
end)

hl.on("config.reloaded", function()
	hl.exec_cmd("/home/yangfeng/.config/hypr/scripts/apply-rounding.sh reload")
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

		col = {
			active_border = {
				colors = { "rgba(cba6f7ee)", "rgba(f5c2e7ee)" },
				angle = rounded and 45 or 0,
			},
			inactive_border = "rgba(313244cc)",
		},
		gaps_in = rounded and 5 or 0,
		gaps_out = rounded and { top = 5, right = 8, bottom = 8, left = 8 }
			or { top = 0, right = 0, bottom = 0, left = 0 },
		border_size = rounded and 2 or 1,

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
		rounding = rounded and 12 or 0,
		-- active_opacity   = 1.0,
		-- inactive_opacity = 0.94,

		shadow = {
			enabled = rounded,
			range = 18,
			render_power = 3,
			color = 0xaa1a1b26,
		},

		blur = {
			enabled = rounded,
			size = 5,
			passes = 2,
			ignore_opacity = true,
			new_optimizations = true,
			xray = false,
		},
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
--   1) 下面的 window_rule 把新建窗口直接放到默认工作区；
--   2) 再下面的 window.open 监听器负责"弹窗跟随应用"（见那里的注释）。
-- classes 里写应用真实的窗口 class（`hyprctl clients` 里的 class 字段），
-- 匹配用的正则由它生成；加应用/改 class 只动这张表。
local fixedWorkspaceApps = {
	{ name = "ws-wechat", workspace = 1, classes = { "wechat", "WeChat" } },
	{ name = "ws-krusader", workspace = 2, classes = { "org.kde.krusader", "krusader" } },
	{ name = "ws-chrome", workspace = 3, classes = { "google-chrome", "Google-chrome" } },
	-- WPS 表格 (Spreadsheets)
	{ name = "ws-spreadsheet", workspace = 4, classes = { "et" } },
	-- WPS 文字 (Writer) 与 WPS PDF（运行时窗口类是 "pdf"）
	{ name = "ws-word", workspace = 5, classes = { "wps" } },
	{ name = "ws-pdf", workspace = 5, classes = { "pdf", "wpspdf" } },
}

for _, app in ipairs(fixedWorkspaceApps) do
    local parts = {}
    for _, class in ipairs(app.classes) do
        parts[#parts + 1] = (class:gsub("([^%w])", "\\%1"))
    end
    hl.window_rule({name = app.name, match = {class = "^(" .. table.concat(parts, "|") .. ")$"}, workspace = app.workspace .. " silent"})
end
dofile("/home/yangfeng/.config/hypr/scripts/dialog-workspace.lua").setup(hl, fixedWorkspaceApps)

-- FSearch: floating search palette instead of a tiled window.
hl.window_rule({
	name = "float-fsearch",
	match = { class = "^(fsearch|io\\.github\\.cboxdoerfer\\.FSearch)$" },
	float = true,
	size = { "(monitor_w*0.6)", "(monitor_h*0.6)" },
	center = true,
})


-- File managers use normal tiling; Super+V toggles floating when needed.


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
	match = { class = "^flameshot$" },
	float = true,
	pin = true,
	no_anim = true,
	no_shadow = true,
	no_blur = true,
	border_size = 0,
	rounding = 0,
})

-- Wechat, wps XWayland 弹出窗口禁用模糊、阴影和边框
hl.window_rule({
	name = "fix-wechat",
	match = { class = "wechat", title = "wechat" },
	no_blur = true,
	no_shadow = true,
	border_size = 0,
})

hl.window_rule({
	name = "fix-wps",
	match = { class = "wps" },
	no_blur = true,
	no_shadow = true,
	border_size = 0,
})

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
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tiling" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("rofi -show project"), { description = "Projection mode menu" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Utilities
-- slurp 的边框以选区边界为中心描边（默认 -w 2），内侧那 1px 会被 grim -g 原样
-- 截进图片最外圈，看起来像黑边。保留默认边框（选区轮廓更清楚），截完用
-- magick -shave 1x1 把这一圈裁掉；png32 输出强制 8bit RGBA，避免 IM 自行量化成调色板。
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(copySelection .. " region"))
hl.bind("PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))

-- 贴图（flameshot 的 pin 等价物）：截完立刻钉在屏幕上，一圈蓝紫渐变外框区分
-- 于普通窗口；左键拖动 / 左键双击关闭 / 滚轮缩放 / 中键复制 / 右键关闭。
-- 走 layer-shell overlay，所以不抢焦点、不参与平铺。
-- 实现见 scripts/pin-shot.sh（抓图）+ scripts/pin-image.py（贴图窗口）。
local pinShot = "/home/yangfeng/.config/hypr/scripts/pin-shot.sh"
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(pinShot), { description = "Screenshot region → pin on screen" })
hl.bind(
	"SHIFT + PRINT",
	hl.dsp.exec_cmd(pinShot .. " --full"),
	{ description = "Screenshot full screen → pin on screen" }
)
hl.bind(
	mainMod .. " + ALT + V",
	hl.dsp.exec_cmd(pinShot .. " --clip"),
	{ description = "Pin clipboard image on screen" }
)
hl.bind(
	mainMod .. " + ALT + X",
	hl.dsp.exec_cmd("pkill -f '[s]cripts/pin-image.py'"),
	{ description = "Close all pinned screenshots" }
)
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(copySelection .. " history"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(powerMenu))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(
	mainMod .. " + SHIFT + R",
	hl.dsp.exec_cmd("/home/yangfeng/.config/hypr/scripts/apply-rounding.sh toggle"),
	{ description = "Toggle rounded corners and margins" }
)

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

-- 把工作区搬到别的显示器（整块搬，里面的窗口跟着走）
-- Hyprland 0.57 的 Lua 里对应的 dispatcher 只有一个 hl.dsp.workspace.move：
--   { monitor = "HDMI-A-1" }                 当前工作区 → 指定屏，视图跟过去
--   { monitor = "right" }                    当前工作区 → 右边那块屏
--   { monitor = "left" } / "up" / "down" / "+1" / "-1" / "current" 都是合法选择器
--   { workspace = 3, monitor = "HDMI-A-1" }  指定工作区 → 指定屏（当前视图不跟过去）
-- 光靠 "left"/"right" 在多屏边缘会报 Monitor not found，所以下面用 Lua 函数算目标屏：
-- 有几块屏就去"下一块 / 上一块"，只有一块屏时什么都不做。
local function moveWorkspaceToMonitor(step)
	return function()
		local monitors = hl.get_monitors() or {}
		if #monitors < 2 then
			return
		end
		local active = hl.get_active_monitor()
		local from = 1
		for i, m in ipairs(monitors) do
			if m.name == (active and active.name) then
				from = i
				break
			end
		end
		local target = monitors[((from - 1 + step) % #monitors) + 1]
		hl.dispatch(hl.dsp.workspace.move({ monitor = target.name }))
	end
end

hl.bind(
	mainMod .. " + SHIFT + COMMA",
	moveWorkspaceToMonitor(-1),
	{ description = "Move workspace to previous monitor", category = "Workspace" }
)
hl.bind(
	mainMod .. " + SHIFT + PERIOD",
	moveWorkspaceToMonitor(1),
	{ description = "Move workspace to next monitor", category = "Workspace" }
)

-- 两台显示器的工作区对调（各自留在原地，内容互换）
-- 注意：原来是 SUPER+SHIFT+S，那个键位已经让给"区域截图贴屏"，这里改用 SUPER+CTRL+S
hl.bind(mainMod .. " + CTRL + S", function()
	local monitors = hl.get_monitors() or {}
	local active = hl.get_active_monitor()
	local other
	for _, m in ipairs(monitors) do
		if m.name ~= (active and active.name) then
			other = m
			break
		end
	end
	if other then
		hl.dispatch(hl.dsp.workspace.swap_monitors({ monitor1 = active.name, monitor2 = other.name }))
	end
end, { description = "Swap workspaces between monitors", category = "Workspace" })

-- Scratchpad
hl.bind(mainMod .. " + GRAVE", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Mouse manipulation
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),
	{ locked = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"),
	{ locked = true }
)
hl.bind("F4", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + SLASH", hl.dsp.exec_cmd(keybindsHelp), { description = "Hotkeys cheat sheet" })
