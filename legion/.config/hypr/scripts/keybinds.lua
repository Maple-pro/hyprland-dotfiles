#!/usr/bin/env lua
-- -----------------------------------------------------------------------------
-- keybinds.lua —— Hyprland 快捷键速查表（rofi 脚本模式）
--
-- 为什么不用 hyprctl：
--   本机是 Hyprland 0.56 的 Lua 配置格式。`hyprctl binds` 对这些绑定只会返回
--   dispatcher="__lua" 且 description 为空，无法得知动作含义。
--   所以这里把 hyprland.lua 放进一个"沙箱"里真正执行一遍：把全局 hl 换成桩对象，
--   于是每一次 hl.bind() 都会被捕获。好处是变量（SUPER / foot / rofi -show drun）
--   自动解析，for 循环生成的绑定也会被真实展开——不需要手工维护任何按键清单。
--
-- 用法：
--   直接运行                   打开 rofi 速查表
--   ROFI_RETV=0（rofi 调用）   输出条目列表
--   ROFI_RETV=1（rofi 调用）   用户选中某条；本工具为纯查看，不做任何事
--   --dump                     在终端打印纯文本表格，便于调试
--
-- 想给某条绑定写自定义说明时，直接在该 hl.bind 的选项表里加 description 字段：
--   hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close this window" })
-- 本脚本会优先采用它，没有时才使用下面的自动规则。
-- 注意：这个字段 HotKeyHub 也识别，所以写了它对两个工具都有好处。
-- -----------------------------------------------------------------------------

local HOME = os.getenv("HOME") or ""
local CONFIG = os.getenv("HYPR_KEYBINDS_CONFIG") or (HOME .. "/.config/hypr/hyprland.lua")
local DEFAULT_SELF = HOME .. "/.config/hypr/scripts/keybinds.lua"

local US = string.char(31) -- rofi 选项分隔符 \x1f
local NUL = string.char(0) -- rofi 行内选项前缀 \0

-- 界面文案统一用英文（可按需改回中文）
local PROMPT = "Hyprland Keybinds"

----------------------------------------------------------------------
-- 1. 沙箱执行 hyprland.lua，捕获所有 hl.bind() 调用
----------------------------------------------------------------------

local binds = {}

-- 任意 hl.xxx(...) / hl.dsp.a.b(...) 都返回一个描述性表，不会产生副作用。
-- 注意：桩对象不会执行 hl.on("hyprland.start", ...) 里的回调，所以不会真的启动程序。
local function make_proxy(path)
	return setmetatable({}, {
		__index = function(_, key)
			return make_proxy(path .. "." .. key)
		end,
		__call = function(_, ...)
			return { __dispatch = true, path = path, args = { ... } }
		end,
	})
end

local hl = make_proxy("hl")

-- bind 需要特殊处理：记录下来而不是当普通 dispatcher
hl.bind = function(keys, dispatcher, opts)
	binds[#binds + 1] = {
		keys = tostring(keys),
		dispatcher = (type(dispatcher) == "table" and dispatcher.__dispatch) and dispatcher or nil,
		opts = (type(opts) == "table") and opts or {},
	}
	return { remove = function() end, unbind = function() end }
end

local function load_config()
	local chunk, err = loadfile(CONFIG, "t", setmetatable({ hl = hl }, { __index = _G }))
	if not chunk then
		return nil, err
	end
	local ok, run_err = pcall(chunk)
	if not ok then
		return nil, run_err
	end
	return true
end

local ok, err = load_config()
if not ok then
	io.stderr:write("keybinds: failed to parse " .. CONFIG .. "\n" .. tostring(err) .. "\n")
	os.exit(1)
end

----------------------------------------------------------------------
-- 2. 显示宽度（中文/emoji 按 2 列算），用于对齐
----------------------------------------------------------------------

local function char_width(cp)
	if cp >= 0x1100 and (
		cp <= 0x115F
		or (cp >= 0x2E80 and cp <= 0xA4CF)
		or (cp >= 0xAC00 and cp <= 0xD7A3)
		or (cp >= 0xF900 and cp <= 0xFAFF)
		or (cp >= 0xFE30 and cp <= 0xFE6F)
		or (cp >= 0xFF00 and cp <= 0xFF60)
		or (cp >= 0xFFE0 and cp <= 0xFFE6)
		or (cp >= 0x1F300 and cp <= 0x1FAFF)
	) then
		return 2
	end
	return 1
end

local function dwidth(s)
	local w = 0
	for _, cp in utf8.codes(s) do
		w = w + char_width(cp)
	end
	return w
end

----------------------------------------------------------------------
-- 3. 按键名的可读化
----------------------------------------------------------------------

local KEY_ALIAS = {
	RETURN = "Enter",
	ESCAPE = "Esc",
	TAB = "Tab",
	BACKSPACE = "Backspace",
	BRACKETLEFT = "[",
	BRACKETRIGHT = "]",
	GRAVE = "`",
	SLASH = "/",
	PRINT = "Print",
	left = "←",
	right = "→",
	up = "↑",
	down = "↓",
	["mouse:272"] = "Mouse Left",
	["mouse:273"] = "Mouse Right",
	-- 这些是独立硬件键，不是组合键，所以刻意不加空格，避免和 "A + B" 混淆
	XF86AudioRaiseVolume = "Vol+",
	XF86AudioLowerVolume = "Vol−",
	XF86AudioMute = "Mute",
	XF86AudioMicMute = "MicMute",
	XF86MonBrightnessUp = "Bright+",
	XF86MonBrightnessDown = "Bright−",
	XF86AudioNext = "Next",
	XF86AudioPrev = "Prev",
	XF86AudioPlay = "Play",
	XF86AudioPause = "Pause",
}

local function pretty_keys(keys)
	local parts = {}
	for part in keys:gmatch("[^+]+") do
		local trimmed = part:match("^%s*(.-)%s*$")
		parts[#parts + 1] = KEY_ALIAS[trimmed] or trimmed
	end
	return table.concat(parts, " + ")
end

----------------------------------------------------------------------
-- 4. 动作 -> 英文说明 / 分类
----------------------------------------------------------------------

-- exec 命令的说明规则：从上到下匹配，先具体后通用
local CMD_RULES = {
	{ "powermenu.sh", "Power menu (lock / suspend / logout / reboot / shutdown)", "System" },
	{ "cliphist", "Clipboard history", "System" },
	{ 'grim -g "$(slurp)"', "Screenshot region → clipboard", "System" },
	{ "grim - |", "Screenshot full screen → clipboard", "System" },
	{ "hyprpicker", "Pick color (HEX to clipboard)", "System" },
	{ "hyprlock", "Lock screen", "System" },
	{ "loginctl lock-session", "Lock screen", "System" },
	{ "--signal=SIGUSR1 waybar.service", "Toggle Waybar", "System" },
	{ "pkill -SIGUSR1 waybar", "Reload Waybar", "System" },
	{ "keybinds.lua", "Show this keybind cheatsheet", "System" },
	{ "rofi -show keybinds", "Show this keybind cheatsheet", "System" },

	{ "rofi -show window", "Window switcher", "Launch" },
	{ "rofi -show drun", "App launcher", "Launch" },
	{ "google-chrome-stable", "Open browser (Chrome)", "Launch" },
	{ "doublecmd", "Open file manager (Double Commander)", "Launch" },
	{ "kate", "Open editor (Kate)", "Launch" },
	{ "fsearch", "File search (FSearch)", "Launch" },
	{ "foot", "Open terminal (foot)", "Launch" },

	{ "movewindow l", "Move window left", "Window" },
	{ "movewindow r", "Move window right", "Window" },
	{ "movewindow u", "Move window up", "Window" },
	{ "movewindow d", "Move window down", "Window" },
	{ "resizeactive -40 0", "Shrink window width by 40", "Window" },
	{ "resizeactive 40 0", "Grow window width by 40", "Window" },
	{ "resizeactive 0 -40", "Shrink window height by 40", "Window" },
	{ "resizeactive 0 40", "Grow window height by 40", "Window" },

	{ "workspace m-1", "Previous workspace", "Workspace" },
	{ "workspace m+1", "Next workspace", "Workspace" },
	{ "workspace previous", "Last used workspace", "Workspace" },

	{ "@DEFAULT_AUDIO_SINK@ 5%+", "Volume +5%", "Media" },
	{ "@DEFAULT_AUDIO_SINK@ 5%-", "Volume −5%", "Media" },
	{ "@DEFAULT_AUDIO_SINK@ toggle", "Toggle mute", "Media" },
	{ "@DEFAULT_AUDIO_SOURCE@ toggle", "Toggle mic mute", "Media" },
	{ "brightnessctl -e4 -n2 set 5%+", "Brightness +5%", "Media" },
	{ "brightnessctl -e4 -n2 set 5%-", "Brightness −5%", "Media" },
	{ "playerctl next", "Next track", "Media" },
	{ "playerctl previous", "Previous track", "Media" },
	{ "playerctl play-pause", "Play / pause", "Media" },
}

local function describe_exec(cmd)
	for _, rule in ipairs(CMD_RULES) do
		if cmd:find(rule[1], 1, true) then
			return rule[2], rule[3]
		end
	end
	return cmd, "Other"
end

-- 返回：说明文字, 分类
local function describe(bind)
	local d = bind.dispatcher
	local FALLBACK_CAT = "Other"

	if not d then
		-- dispatcher 传的是 Lua 函数而不是 hl.dsp.*（本配置没有，但别炸）
		return "(custom Lua function — cannot describe automatically)", FALLBACK_CAT
	end

	local name = d.path:gsub("^hl%.dsp%.", "")
	local a = d.args[1]

	local desc, cat
	if name == "exec_cmd" then
		desc, cat = describe_exec(tostring(a or ""))
	elseif name == "window.close" then
		desc, cat = "Close active window", "Window"
	elseif name == "window.fullscreen" then
		desc, cat = "Toggle fullscreen", "Window"
	elseif name == "window.float" then
		desc, cat = "Toggle floating / tiling", "Window"
	elseif name == "window.pseudo" then
		desc, cat = "Toggle pseudo-tile", "Window"
	elseif name == "window.drag" then
		desc, cat = "Drag window (hold)", "Mouse"
	elseif name == "window.resize" then
		if type(a) == "table" and a.relative then
			desc, cat = string.format("Resize window by %s × %s", a.x or 0, a.y or 0), "Window"
		else
			desc, cat = "Resize window (hold)", "Mouse"
		end
	elseif name == "layout" then
		desc, cat = (tostring(a) == "togglesplit") and "Toggle split direction" or ("Layout: " .. tostring(a)), "Window"
	elseif name == "exit" then
		desc, cat = "Exit Hyprland", "System"
	elseif name == "workspace.toggle_special" then
		desc, cat = "Toggle scratchpad", "Workspace"
	elseif name == "focus" then
		if type(a) == "table" and a.direction then
			desc, cat = "Focus " .. tostring(a.direction), "Focus"
		elseif type(a) == "table" and a.workspace then
			desc, cat = "Go to workspace " .. tostring(a.workspace), "Workspace"
		end
	elseif name == "window.move" then
		if type(a) == "table" and a.direction then
			desc, cat = "Move window " .. tostring(a.direction), "Window"
		elseif type(a) == "table" and a.workspace ~= nil then
			local ws = tostring(a.workspace)
			if ws:find("special:") then
				desc, cat = "Move window to scratchpad", "Workspace"
			else
				desc, cat = "Move window to workspace " .. ws, "Workspace"
			end
		end
	end

	-- 未知 dispatcher（例如以后配置里新加的动作）：至少把名字和参数原样显示，
	-- 而不是丢一句没用的"无法识别"，方便直接对照 Hyprland 文档。
	if not desc then
		local parts = {}
		for i = 1, #d.args do
			local v = d.args[i]
			if type(v) == "table" then
				local kv = {}
				for k, vv in pairs(v) do
					kv[#kv + 1] = tostring(k) .. "=" .. tostring(vv)
				end
				table.sort(kv)
				parts[#parts + 1] = "{" .. table.concat(kv, ", ") .. "}"
			else
				parts[#parts + 1] = tostring(v)
			end
		end
		desc = name .. (#parts > 0 and ("  " .. table.concat(parts, " ")) or "")
	end
	cat = cat or FALLBACK_CAT

	-- 配置里写了 description / desc 就以它为准
	local custom = bind.opts.description or bind.opts.desc
	if type(custom) == "string" and custom ~= "" then
		desc = custom
	end

	return desc, cat
end

----------------------------------------------------------------------
-- 5. 组装条目
----------------------------------------------------------------------

local CATEGORY_ORDER = {
	"Launch",
	"Window",
	"Focus",
	"Workspace",
	"System",
	"Media",
	"Mouse",
	"Other",
}

local rows = {}
for _, bind in ipairs(binds) do
	local desc, cat = describe(bind)
	rows[#rows + 1] = {
		key = pretty_keys(bind.keys),
		desc = desc,
		cat = cat,
	}
end

-- 按键列最大宽度，用于对齐
local max_key_w = 0
for _, row in ipairs(rows) do
	local w = dwidth(row.key)
	if w > max_key_w then
		max_key_w = w
	end
end

local function xml_escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- 按分类顺序分组（同一分类的条目会归拢到一起，即使源码里不连续）
local present = {}
for _, row in ipairs(rows) do
	present[row.cat] = true
end

local ordered_cats = {}
for _, cat in ipairs(CATEGORY_ORDER) do
	if present[cat] then
		ordered_cats[#ordered_cats + 1] = cat
		present[cat] = nil
	end
end
-- 兜底：CATEGORY_ORDER 里没列到的分类，按出现顺序补在后面
for _, row in ipairs(rows) do
	if present[row.cat] then
		ordered_cats[#ordered_cats + 1] = row.cat
		present[row.cat] = nil
	end
end

local groups = {}
for _, cat in ipairs(ordered_cats) do
	local group = { cat = cat, rows = {} }
	for _, row in ipairs(rows) do
		if row.cat == cat then
			group.rows[#group.rows + 1] = row
		end
	end
	groups[#groups + 1] = group
end

local KEY_COLOR = "#8839ef" -- Catppuccin Latte mauve
local HEAD_COLOR = "#1e66f5" -- Latte blue

local out = {}
for _, group in ipairs(groups) do
	-- 分类标题：不可选中，所以只是视觉分隔
	out[#out + 1] = string.format(
		"%s%sdisplay%s<span foreground='%s' weight='bold'>── %s (%d) ──</span>%snonselectable%strue",
		"##" .. group.cat,
		NUL,
		US,
		HEAD_COLOR,
		xml_escape(group.cat),
		#group.rows,
		NUL,
		US
	)

	for _, row in ipairs(group.rows) do
		local pad = string.rep(" ", max_key_w - dwidth(row.key))
		local display = string.format(
			"<span foreground='%s' weight='bold'>%s</span>%s  %s",
			KEY_COLOR,
			xml_escape(row.key),
			pad,
			xml_escape(row.desc)
		)
		-- 条目正文（用于过滤，不含 markup）；display 只负责好看
		out[#out + 1] = string.format(
			"%s  %s%sdisplay%s%s%smeta%s%s",
			row.key,
			row.desc,
			NUL,
			US,
			display,
			NUL,
			US,
			row.cat
		)
	end
end

----------------------------------------------------------------------
-- 6. 入口
----------------------------------------------------------------------

local retv = os.getenv("ROFI_RETV")

-- --dump：终端里看纯文本结果，方便调试（分组/对齐与 rofi 里的完全一致）
if arg and (arg[1] == "--dump" or arg[1] == "-d") then
	for _, group in ipairs(groups) do
		print("\n[" .. group.cat .. "]")
		for _, row in ipairs(group.rows) do
			local pad = string.rep(" ", max_key_w - dwidth(row.key))
			print("  " .. row.key .. pad .. "  " .. row.desc)
		end
	end
	print(string.format("\n%d binds, parsed from %s", #rows, CONFIG))
	os.exit(0)
end

if retv == nil then
	-- 由快捷键/终端直接运行 -> 拉起 rofi 的 keybinds 模式
	local self = (arg and arg[0]) or DEFAULT_SELF
	if self:sub(1, 1) ~= "/" then
		self = DEFAULT_SELF
	end
	local cmd = table.concat({
		"rofi -show keybinds",
		'-modi "drun,run,window,keybinds:' .. self .. '"',
		"-theme-str 'window { width: 46%; } listview { lines: 18; }'",
	}, " ")
	os.exit(os.execute(cmd) and 0 or 1)
end

if retv == "1" then
	-- 用户选中了某条：纯查看模式，什么都不做
	os.exit(0)
end

-- ROFI_RETV=0（以及其它情况）：输出条目
-- 注意：rofi 每行只解析第一个 mode option，多个选项必须各占一行，
-- 否则后面的会被静默忽略（markup-rows 就不会生效）。
io.write(string.format("%sprompt%s%s\n", NUL, US, PROMPT))
io.write(string.format("%smarkup-rows%strue\n", NUL, US))
io.write(string.format("%sno-custom%strue\n", NUL, US))
io.write(table.concat(out, "\n"), "\n")
