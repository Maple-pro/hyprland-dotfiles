-- Never pass special workspace IDs through a string (they are relative selectors).
return function(ws)
    if not ws then return nil end
    local name=ws.name
    if type(name)=='string' and name~='' then
        if name=='special' or name:match('^special:') then return name end
        if not name:match('^%d+$') then return 'name:' .. name end
    end
    if ws.id and ws.id>0 then return tostring(ws.id) end
    return nil
end
