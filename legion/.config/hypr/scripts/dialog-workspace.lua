-- 新窗口跟随应用：把刚打开的窗口挪到"该应用已打开的窗口"所在的工作区。
--
-- 为什么需要这一步：hyprland.lua 里的 workspace 规则按 class 匹配，而保存/打开/
-- 选字体/转发信息这类弹窗和主窗口共用同一个 class，所以只要应用被挪到别的工作区，
-- 弹窗还是会被规则送回默认工作区。
--
-- 跟随谁（依次尝试）：
--   1) 当前聚焦的窗口 —— 规则带 "silent"，新窗口不抢焦点，此时聚焦的就是它的父窗口；
--   2) 上一个聚焦的窗口 —— 新窗口自己拿到了焦点时，它之前聚焦的那个才是父窗口；
--   3) 该应用其它窗口如果都在同一个工作区，就跟这个工作区（同一应用开多个文件很常见）；
--   4) 窗口分散在不同工作区又没有焦点线索时不猜，保持规则给的默认工作区。
--
-- 只看 class：不依赖 Hyprland 是否把某个窗口识别成 floating / modal（很多应用的
-- 弹窗两个都不是），也不要求 pid 相同（多进程的应用同样要跟随）。
local M = {}
local selector = dofile("/home/yangfeng/.config/hypr/scripts/workspace-selector.lua")

local function usable(candidate, w)
	return candidate ~= nil
		and candidate ~= w
		and candidate.class == w.class
		and candidate.mapped ~= false
		and candidate.workspace ~= nil
end

function M.target(w, hl, windows)
	local focused = hl.get_active_window()
	if usable(focused, w) then return focused.workspace end
	local previous = hl.get_last_window()
	if usable(previous, w) then return previous.workspace end

	local target = nil
	for _, other in ipairs(windows) do
		if usable(other, w) then
			if target and target.id ~= other.workspace.id then
				return nil -- 分散在不同工作区，又没有焦点线索，不猜
			end
			target = other.workspace
		end
	end

	return target
end

function M.setup(hl, apps)
	local allowed = {}
	for _, app in ipairs(apps) do
		for _, class in ipairs(app.classes) do
			allowed[class] = true
		end
	end

	hl.on("window.open", function(w)
		if not w or not allowed[w.class] then
			return
		end

		local target = M.target(w, hl, hl.get_windows() or {})
		local destination = selector(target)
		-- follow = false：只搬窗口，不切视图（跟规则里的 "silent" 一致）
		if destination and w.workspace and target.id ~= w.workspace.id then
			hl.dispatch(hl.dsp.window.move({ window = w, workspace = destination, follow = false }))
		end
	end)
end

return M
