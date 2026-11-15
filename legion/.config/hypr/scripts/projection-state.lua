-- Reconcile only stable, committed layouts; never recreate outputs to repair bars.
--
-- Event driven on purpose. Hyprland 0.57.0 segfaults in
-- CConfigManager::cleanTimers() whenever a Lua timer is still registered when the
-- config manager is torn down (config reload or compositor exit), which took the
-- whole session down. So this module keeps no hl.timer at all:
--   * Hyprland monitor/config events spawn scripts/projection-debounce.sh.
--   * That helper coalesces bursts, waits for Monique to stop applying a profile,
--     and calls M.trigger() back through `hyprctl repl` (settle + reconcile).
-- Everything M.trigger() needs lives in files, so it also works from the IPC Lua
-- state, which is why the context (rules + bar restart command) is persisted.
local M = {}

local SCRIPT_DIR = "/home/yangfeng/.config/hypr/scripts/"
local DEBOUNCE = SCRIPT_DIR .. "projection-debounce.sh"
local selector = dofile(SCRIPT_DIR .. "workspace-selector.lua")

local EVENTS = { "config.reloaded", "monitor.added", "monitor.removed", "monitor.layout_changed" }

local function base_path()
    local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    local signature = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "unknown"
    return runtime .. "/hypr-projection-" .. signature
end

local function read_lines(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    if not text then return nil end
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    return lines
end

local function write_lines(path, lines)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    return true
end

local function busy()
    local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    local f = io.open(runtime .. "/monique-applying", "r")
    if not f then return false end
    local pid = f:read("*l")
    f:close()
    if not pid or not pid:match("^%d+$") then return false end
    f = io.open("/proc/" .. pid .. "/stat", "r")
    if f then f:close(); return true end
    return false
end

local function snapshot(h)
    local active, names, descriptions, parts = {}, {}, {}, {}
    for _, mon in ipairs(h.get_monitors() or {}) do
        if mon.name ~= "FALLBACK" and not mon.is_mirror then
            active[#active + 1] = mon
            names[mon.name] = true
            descriptions[mon.name] = mon.name
            descriptions["desc:" .. (mon.description or "")] = mon.name
            parts[#parts + 1] = table.concat({ mon.name, tostring(mon.x), tostring(mon.y),
                tostring(mon.width), tostring(mon.height), tostring(mon.scale),
                tostring(mon.transform) }, ":")
        end
    end
    table.sort(active, function(a, b) return a.name < b.name end)
    table.sort(parts)
    local topology = {}
    for _, mon in ipairs(active) do topology[#topology + 1] = mon.name end
    return {
        active = active,
        names = names,
        descriptions = descriptions,
        signature = table.concat(parts, ","),
        topology = table.concat(topology, ","),
    }
end

-- Context persisted by setup(): restart command, then "workspace=monitor" rules.
local function read_context()
    local lines = read_lines(base_path() .. ".ctx")
    if not lines or #lines < 1 or lines[1] == "" then return nil end
    local ctx = { restart_bar = lines[1], rules = {} }
    for i = 2, #lines do
        local workspace, monitor = lines[i]:match("^([^=]+)=(.*)$")
        if workspace and monitor and monitor ~= "" then
            ctx.rules[#ctx.rules + 1] = { workspace = workspace, monitor = monitor }
        end
    end
    return ctx
end

local function reconcile(h, ctx, s)
    if #s.active == 0 then return end
    local path = base_path()
    local previous = read_lines(path) or {}
    local rule_parts = {}
    for _, rule in ipairs(ctx.rules) do
        rule_parts[#rule_parts + 1] = rule.workspace .. "=" .. rule.monitor
    end
    table.sort(rule_parts)
    local rule_signature = table.concat(rule_parts, ",")
    -- Apply assignments on entering a profile/topology, not on an unrelated reload.
    local assign = previous[2] ~= rule_signature or previous[3] ~= s.topology
    local fallback = s.active[1].name
    for _, mon in ipairs(s.active) do
        if mon.name:match("^eDP") or mon.name:match("^LVDS") or mon.name:match("^DSI") then
            fallback = mon.name
        end
    end
    local targets = {}
    if assign then
        for _, rule in ipairs(ctx.rules) do
            targets[rule.workspace] = s.descriptions[rule.monitor]
        end
    end
    for _, ws in ipairs(h.get_workspaces() or {}) do
        local target = targets[ws.name] or targets[tostring(ws.id)]
        local where = ws.monitor and ws.monitor.name
        if not target and not s.names[where] then target = fallback end
        local destination = selector(ws)
        if destination and target and target ~= where then
            -- Use explicit special/name selectors; never serialize internal negative IDs.
            h.dispatch(h.dsp.workspace.move({ workspace = destination, monitor = target }))
        end
    end
    write_lines(path, { s.signature, rule_signature, s.topology })
    if previous[1] and previous[1] ~= s.signature then
        h.exec_cmd("'" .. ctx.restart_bar .. "'")
    end
end

-- FALLBACK-only means the panel never came back: re-assert eDP-1, at most 3 times
-- per outage. Runs from trigger() instead of the old 2s polling timer.
local function rescue(h)
    local marker = base_path() .. ".rescue"
    local monitors = h.get_monitors() or {}
    if #monitors ~= 1 or monitors[1].name ~= "FALLBACK" then
        write_lines(marker, { "0" })
        return
    end
    local attempts = tonumber((read_lines(marker) or { "0" })[1]) or 0
    if attempts >= 3 then return end
    -- Only rescue a physically connected panel; never blank a working external output.
    for card = 0, 15 do
        local f = io.open("/sys/class/drm/card" .. card .. "-eDP-1/status", "r")
        if f then
            local status = f:read("*l")
            f:close()
            if status == "connected" then
                write_lines(marker, { tostring(attempts + 1) })
                h.monitor({ output = "eDP-1", mode = "2560x1600@60", position = "0x0",
                    scale = 1.25, disabled = false, mirror = "" })
                return
            end
        end
    end
end

local function sample_seen(signature)
    return write_lines(base_path() .. ".sample", { signature })
end

local function sample_matches(signature)
    local sample = (read_lines(base_path() .. ".sample") or {})[1]
    return sample ~= nil and sample == signature
end

-- Entry point used by projection-debounce.sh through `hyprctl repl`.
-- kind "sample": record the current layout, do nothing else.
-- kind "settle": reconcile only if the layout did not move since the sample.
function M.trigger(kind)
    local h = _G.hl
    if not h then return "no-hl" end
    local ctx = read_context()
    if not ctx then return "no-context" end
    if busy() then return "busy" end
    local s = snapshot(h)
    if kind == "sample" then
        sample_seen(s.signature)
        return "sampled"
    end
    if not sample_matches(s.signature) then return "unstable" end
    reconcile(h, ctx, s)
    rescue(h)
    return "reconciled"
end

function M.setup(hl, rules, restart_bar)
    local ctx = { restart_bar }
    for _, rule in ipairs(rules) do
        ctx[#ctx + 1] = tostring(rule.workspace) .. "=" .. tostring(rule.monitor)
    end
    write_lines(base_path() .. ".ctx", ctx)
    write_lines(base_path() .. ".rescue", { "0" })
    for _, event in ipairs(EVENTS) do
        hl.on(event, function() hl.exec_cmd("'" .. DEBOUNCE .. "'") end)
    end
    -- Debounced, so the first reconcile still happens shortly after startup
    -- without blocking the config load.
    hl.exec_cmd("'" .. DEBOUNCE .. "'")
end

return M
