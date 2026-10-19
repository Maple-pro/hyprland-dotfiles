-- Reconcile only stable, committed layouts; never recreate outputs to repair bars.
local M = {}
local selector=dofile("/home/yangfeng/.config/hypr/scripts/workspace-selector.lua")
function M.setup(hl, rules, restart_bar)
    local runtime = os.getenv('XDG_RUNTIME_DIR') or '/tmp'
    local state_path = runtime .. '/hypr-projection-' .. (os.getenv('HYPRLAND_INSTANCE_SIGNATURE') or 'unknown')
    local generation, fallback_ticks, recoveries = 0, 0, 0
    local function read_state()
        local f = io.open(state_path, 'r')
        if not f then return {} end
        local text = f:read('*a'); f:close()
        local lines = {}; for line in (text .. '\n'):gmatch('(.-)\n') do lines[#lines+1] = line end
        return lines
    end
    local function busy()
        local f = io.open(runtime .. '/monique-applying', 'r')
        if not f then return false end
        local pid = f:read('*l'); f:close()
        if not pid or not pid:match('^%d+$') then return false end
        f = io.open('/proc/' .. pid .. '/stat', 'r')
        if f then f:close(); return true end
        return false
    end
    local function snapshot()
        local active, names, descriptions, parts = {}, {}, {}, {}
        for _, mon in ipairs(hl.get_monitors() or {}) do
            if mon.name ~= 'FALLBACK' and not mon.is_mirror then
                active[#active+1] = mon; names[mon.name] = true
                descriptions[mon.name] = mon.name
                descriptions['desc:' .. (mon.description or '')] = mon.name
                parts[#parts+1] = table.concat({mon.name, tostring(mon.x), tostring(mon.y),
                    tostring(mon.width), tostring(mon.height), tostring(mon.scale), tostring(mon.transform)}, ':')
            end
        end
        table.sort(active, function(a,b) return a.name < b.name end); table.sort(parts)
        local topology = {}; for _, mon in ipairs(active) do topology[#topology+1] = mon.name end
        return {active=active, names=names, descriptions=descriptions, signature=table.concat(parts, ','), topology=table.concat(topology, ',')}
    end
    local rule_parts = {}
    for _, rule in ipairs(rules) do rule_parts[#rule_parts+1] = tostring(rule.workspace) .. '=' .. tostring(rule.monitor) end
    table.sort(rule_parts)
    local rule_signature = table.concat(rule_parts, ',')
    local function reconcile(s)
        if #s.active == 0 then return end
        local previous = read_state()
        -- Apply assignments on entering a profile/topology, not on an unrelated reload.
        local assign = previous[2] ~= rule_signature or previous[3] ~= s.topology
        local fallback = s.active[1].name
        for _, mon in ipairs(s.active) do
            if mon.name:match('^eDP') or mon.name:match('^LVDS') or mon.name:match('^DSI') then fallback=mon.name end
        end
        local targets = {}
        if assign then
            for _, rule in ipairs(rules) do targets[tostring(rule.workspace)] = s.descriptions[rule.monitor] end
        end
        for _, ws in ipairs(hl.get_workspaces() or {}) do
            local target = targets[ws.name] or targets[tostring(ws.id)]
            local where = ws.monitor and ws.monitor.name
            if not target and not s.names[where] then target=fallback end
            local destination=selector(ws)
            if destination and target and target ~= where then
                -- Use explicit special/name selectors; never serialize internal negative IDs.
                hl.dispatch(hl.dsp.workspace.move({workspace=destination, monitor=target}))
            end
        end
        local f = io.open(state_path, 'w')
        if f then f:write(s.signature, '\n', rule_signature, '\n', s.topology, '\n'); f:close() end
        if previous[1] and previous[1] ~= s.signature then hl.exec_cmd("'" .. restart_bar .. "'") end
    end
    local schedule
    schedule = function()
        generation=generation+1
        local current=generation
        hl.timer(function()
            if current ~= generation then return end
            if busy() then schedule(); return end
            local first=snapshot()
            hl.timer(function()
                if current ~= generation then return end
                if busy() then schedule(); return end
                local second=snapshot()
                if first.signature ~= second.signature then schedule(); return end
                reconcile(second)
            end, {timeout=350, type='oneshot'})
        end, {timeout=450, type='oneshot'})
    end
    for _, event in ipairs({'config.reloaded','monitor.added','monitor.removed','monitor.layout_changed'}) do hl.on(event,schedule) end
    hl.timer(function()
        local monitors=hl.get_monitors() or {}
        if busy() then fallback_ticks=0; return end
        if #monitors == 1 and monitors[1].name == 'FALLBACK' then
            fallback_ticks=fallback_ticks+1
            if fallback_ticks >= 2 and recoveries < 3 then
                recoveries=recoveries+1; fallback_ticks=0
                -- Only rescue a physically connected panel; never blank a working external output.
                for card=0,15 do
                    local f=io.open('/sys/class/drm/card' .. card .. '-eDP-1/status','r')
                    if f then
                        local status=f:read('*l'); f:close()
                        if status == 'connected' then
                            hl.monitor({output='eDP-1',mode='preferred',position='0x0',scale=1,disabled=false,mirror=''})
                            schedule(); break
                        end
                    end
                end
            end
        else
            fallback_ticks=0
            if #monitors > 0 then recoveries=0 end
        end
    end, {timeout=2000,type='repeat'})
    schedule()
end
return M
