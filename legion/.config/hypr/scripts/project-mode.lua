-- -----------------------------------------------------------------------------
-- project-mode.lua —— Win+P 风格的「投影模式」切换（Hyprland 0.56 Lua 配置）
--
-- 四种模式，循环顺序与 Windows 的 Win+P 一致：
--   internal  仅电脑屏幕   eDP-1 亮，HDMI-A-1 关
--   mirror    复制         HDMI-A-1 镜像 eDP-1
--   extend    扩展         HDMI-A-1 在 eDP-1 左侧（auto-left）
--   external  仅投影仪     eDP-1 关，HDMI-A-1 亮
--
-- 普通使用只需按 Super+P（绑定见 hyprland.lua）。
--
-- 装了 monique 之后（本机如此）：显示器布局由 monique 的档案决定，档案在
-- ~/.config/monique/profiles/（pc-only / mirror / extend / external，monique 生成
-- 的 ~/.config/hypr/monitors.lua 被 hyprland.lua include）。此时 Super+P 变成
-- "循环切换 monique 档案"，本文件下面那套按端口名的规则只在没有档案时兜底。
-- 终端里可以直接调用，例如：
--   hyprctl eval 'dofile("/home/yangfeng/.config/hypr/scripts/project-mode.lua").cycle()'
--   hyprctl eval 'dofile("/home/yangfeng/.config/hypr/scripts/project-mode.lua").set("extend")'
--   hyprctl eval 'dofile("/home/yangfeng/.config/hypr/scripts/project-mode.lua").status()'
--
-- 状态保存在 ~/.cache/hypr/project-mode，hyprland.lua 在加载时读取它，
-- 所以登录后 / hyprctl reload 之后仍然是上次选择的模式。
--
-- 注意：Hyprland 0.56 的 Lua 配置里 `hyprctl keyword monitor ...` 不可用，
-- 运行时改显示器必须走 `hyprctl eval`（本模块即如此），并且每条规则都要显式写出
-- disabled 字段，否则关闭过的输出不会重新打开。
-- -----------------------------------------------------------------------------

local M = {}

-- hyprland.lua 通过 attach(hl) 把配置里的 hl 句柄传进来。
-- 原因是 keybinds.lua 的速查表沙箱会用自定义环境加载 hyprland.lua（hl 被换成桩对象），
-- 而 dofile 加载本文件时用的是默认全局环境，取不到那个 hl，所以必须显式注入。
-- 在 `hyprctl eval` 里直接使用时没有注入，就退回全局 hl。
function M.attach(api)
	M._hl = api
	return M
end

local function hl_api()
	return M._hl or hl
end

-- 显示器名（可在 `hyprctl monitors` 里确认）
M.internal = "eDP-1"
M.external = "HDMI-A-1"
-- 外接屏（投影仪）使用的模式；eDP-1 用 preferred
M.external_mode = "preferred"

M.order = { "internal", "mirror", "extend", "external" }
M.default = "internal"

M.labels = {
	internal = "仅电脑屏幕 PC screen only",
	mirror = "复制 Duplicate",
	extend = "扩展 Extend",
	external = "仅投影仪 Second screen only",
}

-- 装了 monique 之后，布局由它的档案接管（见 hyprland.lua 里 include 的 monitors.lua）：
-- Super+P 就变成"循环切换 monique 档案"。档案名固定为下面这张映射表，
-- 文件在 ~/.config/monique/profiles/<名字>.json。
M.profile_names = {
	internal = "pc-only",
	mirror = "mirror",
	extend = "extend",
	external = "external",
}
M.monique_dir = (os.getenv("HOME") or "") .. "/.config/monique"
-- 切换档案用的包装脚本：先设 pin 再切（见脚本里的注释）
M.switch_cmd = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/monique-switch.sh"

local function readable(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- 按 M.order 的顺序返回真正存在的 monique 档案
function M.available_profiles()
	local list = {}
	for _, mode in ipairs(M.order) do
		local name = M.profile_names[mode]
		if name and readable(M.monique_dir .. "/profiles/" .. name .. ".json") then
			list[#list + 1] = { mode = mode, name = name }
		end
	end
	return list
end

-- monique 记录在 settings.json 里的当前档案（没应用过时是 null）
function M.active_profile()
	local f = io.open(M.monique_dir .. "/settings.json", "r")
	if not f then
		return nil
	end
	local data = f:read("*a") or ""
	f:close()
	return data:match('"active_profile"%s*:%s*"([^"]+)"')
end

-- 每个模式对应的 hyprctl eval 规则（显式写全字段，避免状态残留）
function M.rules_for(mode)
	local ext = M.external
	local int = M.internal
	-- 注意：mirror = "" 是必须的。Hyprland 一旦把某个输出设成镜像，之后只改
	-- position/mode 并不会解除镜像，必须显式传空字符串把它清掉。
	if mode == "internal" then
		return {
			{ output = int, mode = "2560x1600@60", position = "0x0", scale = 1.25, disabled = false, mirror = "" },
			{ output = ext, disabled = true },
		}
	elseif mode == "mirror" then
		return {
			{ output = int, mode = "2560x1600@60", position = "0x0", scale = 1.25, disabled = false, mirror = "" },
			{ output = ext, mode = M.external_mode, position = "auto", scale = 1, disabled = false,
				mirror = int },
		}
	elseif mode == "extend" then
		return {
			{ output = int, mode = "2560x1600@60", position = "0x0", scale = 1.25, disabled = false, mirror = "" },
			{ output = ext, mode = M.external_mode, position = "auto-left", scale = 1, disabled = false,
				mirror = "" },
		}
	elseif mode == "external" then
		return {
			{ output = int, disabled = true },
			{ output = ext, mode = M.external_mode, position = "0x0", scale = 1, disabled = false,
				mirror = "" },
		}
	end
	return nil
end

function M.is_mode(mode)
	for _, m in ipairs(M.order) do
		if m == mode then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- 状态文件
----------------------------------------------------------------------

function M.state_path()
	return (os.getenv("HOME") or "/tmp") .. "/.cache/hypr/project-mode"
end

function M.read()
	local f = io.open(M.state_path(), "r")
	if not f then
		return M.default
	end
	local raw = f:read("*l") or ""
	f:close()
	local mode = raw:gsub("%s+", "")
	if M.is_mode(mode) then
		return mode
	end
	return M.default
end

function M.save(mode)
	local path = M.state_path()
	local dir = path:match("^(.*)/[^/]+$")
	if dir and os.execute then
		pcall(os.execute, "mkdir -p '" .. dir .. "'")
	end
	local f = io.open(path, "w")
	if f then
		f:write(mode, "\n")
		f:close()
	end
end

----------------------------------------------------------------------
-- 应用 / 通知
----------------------------------------------------------------------

-- 屏幕右上角弹一下当前模式，样式模仿 Windows 的 Win+P 浮层。
-- 用 Hyprland 自带的 OSD（hl.notification），不依赖 dunst / 通知守护进程；
-- 万一旧版 Hyprland 没有这个 API，再退回 notify-send。
function M.notify(mode)
	local lines = { "投影模式 Projection", "" }
	for _, m in ipairs(M.order) do
		lines[#lines + 1] = (m == mode and "● " or "○ ") .. M.labels[m]
	end
	local text = table.concat(lines, "\n")
	local api = hl_api()
	if api.notification and api.notification.create then
		-- 先关掉上一次自己弹的那个，避免连按时浮层叠一列（Windows 的 Win+P 是原地刷新）。
		-- 句柄存在全局里：每次 hyprctl eval 都会重新 dofile 本文件，模块内的变量留不住。
		local prev = _G.__hypr_project_mode_osd
		if prev then
			pcall(function()
				prev:dismiss()
			end)
		end
		_G.__hypr_project_mode_osd = api.notification.create({ text = text, timeout = 2000, icon = 1 })
	else
		api.exec_cmd(
			"notify-send -a Hyprland -i video-display -t 2000 '投影模式' '"
				.. text:gsub("'", "'\\''")
				.. "'"
		)
	end
end

-- 应用模式；opts.save == false 时不写状态文件（开机恢复用）
function M.apply(mode, opts)
	if not M.is_mode(mode) then
		mode = M.default
	end
	for _, rule in ipairs(M.rules_for(mode) or {}) do
		hl_api().monitor(rule)
	end
	if not (opts and opts.save == false) then
		M.save(mode)
	end
	return mode
end

-- 切到指定模式（带通知）
function M.set(mode)
	local applied = M.apply(mode)
	M.notify(applied)
	return applied
end

-- 循环到下一个模式（Super+P）
function M.cycle()
	-- 有 monique 档案时：切换 monique 档案（它会重写 monitors.lua 并 hyprctl reload，
	-- 于是 hyprland.lua 里 include 的那份新布局生效）
	local profiles = M.available_profiles()
	if #profiles > 0 then
		local current = M.active_profile()
		local index = 0
		for i, p in ipairs(profiles) do
			if p.name == current then
				index = i
			end
		end
		local nextp = profiles[index % #profiles + 1]
		-- 必须异步（hl.exec_cmd）：monique 内部会调用 hyprctl reload，
		-- 如果在这里同步等它返回，Hyprland 主线程正卡在本段 Lua 里，没人处理那个
		-- reload 请求，双方互等 = 卡死。
		--
		-- 走 monique-switch.sh 而不是直接 monique --switch-profile：它会先把 pin
		-- 写成目标档案，避免 moniqued 在切换过程中按过期 pin 重放旧档案
		-- （那会把工作区在两块屏之间反复搬，看起来就像工作区丢了）。
		local api = hl_api()
		if api.exec_cmd then
			api.exec_cmd("'" .. M.switch_cmd .. "' '" .. nextp.name .. "'")
			M.save(nextp.mode)
			M.notify(nextp.mode)
			return nextp.mode
		end
	end

	-- 兜底：没有 monique 档案时按端口名用内置规则
	local current = M.read()
	local index = 1
	for i, m in ipairs(M.order) do
		if m == current then
			index = i
		end
	end
	return M.set(M.order[index % #M.order + 1])
end

function M.status()
	return M.read()
end

-- 供 hyprland.lua 在配置加载时调用：恢复上次模式但不改状态文件
function M.setup()
	return M.apply(M.read(), { save = false })
end

return M
