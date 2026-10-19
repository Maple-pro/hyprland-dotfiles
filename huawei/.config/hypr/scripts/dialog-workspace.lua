-- Native parent placement is preferred. Hidden/special parents need a narrow
-- fallback: only a modal/native floating dialog with a unique same-process
-- top-level candidate. Forced-floating application windows are excluded.
local M = {}
local selector=dofile("/home/yangfeng/.config/hypr/scripts/workspace-selector.lua")
function M.is_modal(w)
    if type(w.tags)=='table' then
        for _,tag in ipairs(w.tags) do if tag=='config-modal' then return true end end
    elseif type(w.tags)=='string' then
        for tag in w.tags:gmatch('[^,%s]+') do if tag=='config-modal' then return true end end
    end
    return false
end
function M.is_dialog(w,forced_float)
    return M.is_modal(w) or (w.floating==true and not forced_float[w.class])
end
function M.target(w,windows,forced_float)
    forced_float=forced_float or {}
    if not M.is_dialog(w,forced_float) or not w.pid or w.pid<=0 then return nil end
    local candidate=nil
    for _,other in ipairs(windows) do
        if other.address ~= w.address and other.class==w.class and other.pid==w.pid
            and other.workspace and other.mapped~=false and not M.is_dialog(other,forced_float) then
            if candidate then return nil end -- ambiguous; do not guess from current focus
            candidate=other.workspace
        end
    end
    return candidate
end
function M.setup(hl,apps)
    local allowed,forced_float={},{}
    for _,app in ipairs(apps) do
        for _,class in ipairs(app.classes) do
            allowed[class]=true
            if app.force_float then forced_float[class]=true end
        end
    end
    hl.window_rule({name='identify-modal-dialogs',match={modal=true},tag='+config-modal'})
    hl.on('window.open',function(w)
        if not w or not allowed[w.class] then return end
        local target=M.target(w,hl.get_windows() or {},forced_float)
        local destination=selector(target)
        if destination and w.workspace and target.id~=w.workspace.id then
            hl.dispatch(hl.dsp.window.move({window=w,workspace=destination,follow=false}))
        end
    end)
end
return M
