-- Apply a saved layout with an early guard for booting after unplugging HDMI.
-- Read DRM connection status directly; compositor outputs may not exist yet.
local M = {}
local function connected(output)
    for card = 0, 15 do
        local f = io.open('/sys/class/drm/card' .. card .. '-' .. output .. '/status', 'r')
        if f then
            local state = f:read('*l'); f:close()
            if state == 'connected' then return true end
        end
    end
    return false
end
function M.load(api, path, status_reader)
    local f = io.open(path, 'r')
    if not f then return false, {} end
    local source = f:read('*a'); f:close()
    local monitors, workspaces = {}, {}
    local proxy = setmetatable({
        monitor = function(rule) monitors[#monitors + 1] = rule end,
        workspace_rule = function(rule)
            workspaces[#workspaces + 1] = {workspace = rule.workspace, monitor = rule.monitor}
            api.workspace_rule(rule)
        end,
    }, {__index = api})
    local chunk = load(source, '@' .. path, 't', setmetatable({hl = proxy}, {__index = _G}))
    if not chunk then return false, {} end
    local ok = pcall(chunk)
    if not ok then return false, {} end
    local read_status = status_reader or connected
    local outputs = {['eDP-1'] = true, ['HDMI-A-1'] = true, ['DP-1'] = true}
    for _, rule in ipairs(monitors) do
        if rule.output and rule.output ~= '' and not rule.output:match('^desc:') then outputs[rule.output] = true end
    end
    local internal, external = nil, false
    for name in pairs(outputs) do
        if read_status(name) then
            if name:match('^eDP') or name:match('^LVDS') or name:match('^DSI') then
                internal = internal or name
            else
                external = true
            end
        end
    end
    -- A stored external-only rule must never disable the sole connected panel.
    local guarded = internal and not external
    local internal_applied = false
    for _, rule in ipairs(monitors) do
        if guarded and rule.output == internal then
            local safe = {}
            for key, value in pairs(rule) do safe[key] = value end
            safe.disabled = false; safe.mirror = ''; safe.position = '0x0'; safe.mode = 'preferred'
            api.monitor(safe); internal_applied = true
        else
            api.monitor(rule)
        end
    end
    if guarded then
        if not internal_applied then
            api.monitor({output = internal, mode = 'preferred', position = '0x0', scale = 1, disabled = false, mirror = ''})
        end
        api.config({cursor = {default_monitor = internal}})
    end
    return true, workspaces
end
return M
