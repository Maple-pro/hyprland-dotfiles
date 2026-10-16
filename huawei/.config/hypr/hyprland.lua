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
-- 重启 waybar 统一走这个脚本：带 flock 串行 + 等旧进程退出，避免同时起两个实例
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
-- 空字符串/不设置时，GTK3/4 在 Wayland 下会退回内置 "wayland"(text-input-v3) 通路，
-- 由 Hyprland 转发给 fcitx5 的 wayland 前端；实测 xdg-desktop-portal-gtk 的对话框
-- 在这条通路上拿不到输入法上下文（Ctrl+Space 无反应）。改为显式 fcitx 后，
-- GTK 应用走 fcitx5-gtk 的 D-Bus 模块，portal 对话框也能正常切输入法。
hl.env("GTK_IM_MODULE", "fcitx")

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

-- 读出 monique 的配置，解析其中的 workspace_rule，再用注入了 hl 的环境执行
-- （本文件里的 hl 在 keybinds.lua 速查表的沙箱中是桩对象，而 dofile 用默认全局
-- 环境，直接 dofile 会让沙箱里取不到 hl）。
local workspaceRules = {}
-- 本轮配置里"正在镜像别人的输出"（例如 mirror 档案里的 HDMI-A-1），
-- 用于检测"离开镜像模式"，见下面的 heal_outputs_that_left_mirror
local mirroredOutputs = {}

local function load_monique_config()
	local f = io.open(monitorsLua, "r")
	if not f then
		return false
	end
	local src = f:read("*a") or ""
	f:close()

	-- 每次加载都重新解析：这两张表是"本轮配置"的快照，
	-- 不清空的话会跨 reload 累加，切换档案后残留上一份的规则。
	workspaceRules = {}
	mirroredOutputs = {}

	for block in src:gmatch("workspace_rule%s*%((.-)%)") do
		local ws = block:match('workspace%s*=%s*"([^"]+)"')
		local mon = block:match('monitor%s*=%s*"([^"]+)"')
		if ws and mon then
			workspaceRules[#workspaceRules + 1] = { workspace = ws, monitor = mon }
		end
	end

	for block in src:gmatch("hl%.monitor%s*%((.-)%)") do
		local output = block:match('output%s*=%s*"([^"]*)"')
		local mirror = block:match('mirror%s*=%s*"([^"]*)"')
		if output and output ~= "" and mirror and mirror ~= "" then
			mirroredOutputs[output] = true
		end
	end

	local chunk = load(src, "@" .. monitorsLua, "t", setmetatable({ hl = hl }, { __index = _G }))
	if not chunk then
		return false
	end
	return pcall(chunk)
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

-- Fallback for any other output：默认「复制」。
-- 没被任何档案/规则单独指到的输出（比如插了另一块屏、档案里的端口名对不上）
-- 一律镜像 eDP-1，避免"以为在复制、结果桌面被扩展出去"。
-- 具体规则（monique 档案里按 eDP-1 / HDMI-A-1 写的那些）排在前面，优先级更高。
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
	mirror = "eDP-1",
})

-- -----------------------------------------------------------------------------
-- 工作区归属：扩展模式时主屏（eDP-1）只保留 workspace 1
-- -----------------------------------------------------------------------------
-- monique 档案里声明的 workspace_rule 只保证"新建"的工作区落在指定屏幕上
-- （实测：切换档案后新建的 ws9/ws10 自动落到外接屏，已存在的 ws5/ws6 不会自己搬），
-- 所以这里在启动 / 配置重载 / 显示器变化时按档案声明的归属校正一次：
-- 声明归谁，就真的待在谁的屏上。mirror / pc-only / external 档案没有工作区规则，
-- 这段就完全不动（否则工作区会被困在已关闭的屏幕上）。
local function enforce_workspace_ownership()
	if #workspaceRules == 0 then
		return
	end

	-- 规则里的显示器写的是 desc:描述，翻译成当前实际存在的输出名
	local name_of = {}
	for _, mon in ipairs(hl.get_monitors() or {}) do
		if mon.name then
			name_of[mon.name] = mon.name
			if mon.description then
				name_of["desc:" .. mon.description] = mon.name
			end
		end
	end

	local current = {}
	for _, ws in ipairs(hl.get_workspaces() or {}) do
		current[ws.id] = ws
	end

	for _, rule in ipairs(workspaceRules) do
		local target = name_of[rule.monitor]
		local id = tonumber(rule.workspace)
		if target and id then
			local ws = current[id]
			local where = ws and ws.monitor and ws.monitor.name
			if where and where ~= target then
				hl.dispatch(hl.dsp.workspace.move({ workspace = rule.workspace, monitor = target }))
			end
		end
	end
end

-- 镜像输出上的工作区要救回来：复制模式下那块屏画的是源屏的内容，
-- 而扩展模式留在它下面的工作区（ws2-10）就变成"调不出来"——既不在主屏，
-- 也不在镜像屏上显示。把这些工作区搬回非镜像的源屏。
local function rescue_workspaces_from_mirrors()
	local fallback = nil
	for _, mon in ipairs(hl.get_monitors() or {}) do
		if not mon.is_mirror then
			fallback = fallback or mon
		end
	end
	if not fallback then
		return
	end

	for _, ws in ipairs(hl.get_workspaces() or {}) do
		local where = ws.monitor
		if where and where.is_mirror then
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws.id), monitor = fallback.name }))
		end
	end
end

-- 显示器变化后的处理（工作区归属校正、镜像救援、waybar 补建、镜像后遗症自愈）。
--
-- 跨 reload 的状态只能落盘：hyprctl reload 会把 Lua 状态整个重置（连 _G 里的全局
-- 都会没），所以监听器里读不到上一轮的 local / global。这里把"上次哪些输出在镜像"
-- 和"上次的布局签名"记在一个小文件里。
local stateFile = (os.getenv("HOME") or "/tmp") .. "/.cache/hypr/monitor-state"

local function read_state()
	local mirrors, signature = {}, nil
	local f = io.open(stateFile, "r")
	if not f then
		return mirrors, signature
	end
	for line in f:lines() do
		local key, value = line:match("^(%S+)%s+(.+)$")
		if key == "mirror" then
			mirrors[value] = true
		elseif key == "signature" then
			signature = value
		end
	end
	f:close()
	return mirrors, signature
end

local function write_state(signature)
	local dir = stateFile:match("^(.*)/[^/]+$")
	if dir then
		pcall(os.execute, "mkdir -p '" .. dir .. "'")
	end
	local f = io.open(stateFile, "w")
	if not f then
		return
	end
	for name in pairs(mirroredOutputs) do
		f:write("mirror ", name, "\n")
	end
	if signature then
		f:write("signature ", signature, "\n")
	end
	f:close()
end

-- 布局指纹：谁在哪、是不是镜像。用于判断"布局真的变了"，避免每次 reload 都重启 waybar
local function monitor_signature()
	local parts = {}
	for _, mon in ipairs(hl.get_monitors() or {}) do
		parts[#parts + 1] = string.format(
			"%s:%d:%d:%s",
			mon.name or "?",
			mon.x or 0,
			mon.y or 0,
			mon.is_mirror and "mirror" or "own"
		)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function on_monitors_changed()
	-- 配置加载阶段的 config.reloaded 会在显示器还没枚举出来时先触发一次，
	-- 这时 hl.get_monitors() 是空的：签名算出空串，跟上次会话存档的签名必然不同，
	-- 于是白重启一次 waybar；紧接着 hyprland.start 又按自启动拉起第二个
	-- → 屏幕上就是两条 bar 叠在一起（开机两个 waybar 的根因）。
	-- 空布局没有任何东西要校正，直接返回；也不要写存档，否则会把上次的签名冲掉。
	if #(hl.get_monitors() or {}) == 0 then
		return
	end

	local previousMirrors, previousSignature = read_state()
	local signature = monitor_signature()

	-- 离开镜像模式：这块输出当过镜像，Hyprland 有时不会重建它的 wl_output
	-- （客户端完全看不到它，waybar 就永远不在上面画 bar，重启 waybar 也没用）。
	-- 唯一可靠的办法是让它走一遍"禁用 → 启用"。
	local to_heal = {}
	for name in pairs(previousMirrors) do
		if not mirroredOutputs[name] then
			to_heal[#to_heal + 1] = name
		end
	end
	write_state(signature)

	if #to_heal > 0 then
		for _, name in ipairs(to_heal) do
			hl.monitor({ output = name, disabled = true })
		end
		hl.timer(function()
			-- reload 按档案把它重新打开，随后重启 waybar 让它在新输出上建 bar
			hl.exec_cmd("hyprctl reload; sleep 1; '" .. waybarRestart .. "'")
		end, { timeout = 700, type = "oneshot" })
		return
	end

	enforce_workspace_ownership()
	rescue_workspaces_from_mirrors()

	if previousSignature and signature ~= previousSignature then
		hl.exec_cmd("'" .. waybarRestart .. "'")
	end
end

-- 这些事件都会在显示器布局变化时触发。监听器不需要手工清理：
-- 每次 reload 都是全新的 Lua 状态，旧的监听器会随之消失。
for _, event in ipairs({
	"config.reloaded",
	"monitor.added",
	"monitor.layout_changed",
}) do
	hl.on(event, on_monitors_changed)
end

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("hyprpaper")
	-- waybar 不直接起：所有拉起 waybar 的地方都走 restart 脚本（flock 串行 + 先杀后起），
	-- 这样即使自启动和显示器钩子在同一秒都想拉起它，最终也只会留下一个实例。
	-- （之前这里写的是 hl.exec_cmd("waybar")，跟布局钩子那次重启撞在一起就是两个 waybar。）
	hl.exec_cmd("'" .. waybarRestart .. "'")
	hl.exec_cmd("dunst")
	hl.exec_cmd("hyprpolkitagent")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("blueman-applet")
	-- 移动硬盘 / U 盘：托盘指示器 + 自动挂载 + 挂载/卸载菜单
	hl.exec_cmd("udiskie")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("foot")
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
		border_size = 1,

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
		-- rounding       = 12,
		-- active_opacity   = 1.0,
		-- inactive_opacity = 0.94,
		--
		-- shadow = {
		--     enabled      = true,
		--     range        = 18,
		--     render_power = 3,
		--     color        = 0xaa1a1b26,
		-- },
		--
		-- blur = {
		--     enabled          = true,
		--     size             = 5,
		--     passes           = 2,
		--     ignore_opacity   = true,
		--     new_optimizations = true,
		--     xray             = false,
		-- },
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
	{ name = "ws-doublecmd", workspace = 2, classes = { "doublecmd", "doublecmd-qt6", "doublecmd-qt", "Double Commander" } },
	{ name = "ws-chrome", workspace = 3, classes = { "google-chrome", "Google-chrome" } },
	-- WPS 表格 (Spreadsheets)
	{ name = "ws-spreadsheet", workspace = 4, classes = { "et" } },
	-- WPS 文字 (Writer) 与 WPS PDF（运行时窗口类是 "pdf"）
	{ name = "ws-word", workspace = 5, classes = { "wps" } },
	{ name = "ws-pdf", workspace = 5, classes = { "pdf", "wpspdf" } },
}

-- class -> 默认工作区，监听器用它判断"这个窗口属不属于设了默认工作区的应用"
local defaultWorkspaceOfClass = {}

-- Hyprland 用 ECMAScript 正则匹配 class，这里把元字符转义后再拼成 ^(a|b)$
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

	for _, class in ipairs(app.classes) do
		defaultWorkspaceOfClass[class] = app.workspace
	end
end

-- 弹窗跟随应用。
-- 规则按 class 把窗口放到默认工作区，但保存文件 / 打开 / 选字体 / 转发信息这类弹窗
-- 和主窗口共用同一个 class，于是即使用户已经把应用挪到别的工作区，弹窗还是会被规则
-- 送回默认工作区。
-- 这里的规则很简单：
--   * 已经有同类窗口"打开着" -> 新窗口去它所在的工作区（有多个时优先当前活动工作区，
--     弹窗的父窗口通常就在那儿）；
--   * 一个同类窗口都没有（应用刚启动的第一扇窗）-> 不动它，交给上面的规则放默认工作区。
-- window.open 在 Hyprland 里是 mapWindow 的最后一步（工作区规则和布局都已处理完），
-- 此时再挪一次是安全的。
local function workspace_of_open_window(w)
	local active = hl.get_active_workspace()
	local fallback = nil

	for _, other in ipairs(hl.get_windows() or {}) do
		if other ~= w and other.class == w.class and other.workspace then
			if active and other.workspace.id == active.id then
				return other.workspace
			end
			fallback = fallback or other.workspace
		end
	end

	return fallback
end

hl.on("window.open", function(w)
	if not w or defaultWorkspaceOfClass[w.class] == nil then
		return
	end

	local target = workspace_of_open_window(w)
	local current = w.workspace
	if not target or not current or target.id == current.id then
		return
	end

	-- follow = false：只搬窗口，不切视图（跟规则里的 "silent" 一致）
	hl.dispatch(hl.dsp.window.move({
		window = w,
		workspace = tostring(target.id),
		follow = false,
	}))
end)

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
-- 当前模式在菜单里用 ● 标出。切换走 scripts/monique-switch.sh（先写 pin 再切），
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
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(powerMenu))
hl.bind(
	mainMod .. " + SLASH",
	hl.dsp.exec_cmd(keybindsHelp),
	{ description = "Show keybind cheatsheet" }
)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exit())

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move active window
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

-- Resize active window
hl.bind(mainMod .. " + CTRL + left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 0"))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -40"))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 40"))

-- Workspaces
for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + BRACKETLEFT", hl.dsp.exec_cmd("hyprctl dispatch workspace m-1"))
hl.bind(mainMod .. " + BRACKETRIGHT", hl.dsp.exec_cmd("hyprctl dispatch workspace m+1"))
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd("hyprctl dispatch workspace previous"))

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
