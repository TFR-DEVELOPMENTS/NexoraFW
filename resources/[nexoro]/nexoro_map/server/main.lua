local cfg = Config.Map

NexoroMap = {}
local M = NexoroMap
-- Overridable in tests.
M.positionOf = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Sends every unit the positions of all units on duty. Civilians never receive positions.
function M.Tick()
    local units = exports.nexoro_dispatch:UnitList()
    local rows = {}
    for _, u in ipairs(units) do
        local p = M.positionOf(u.src)
        if p then
            rows[#rows + 1] = { src = u.src, callsign = u.callsign, category = u.category, status = u.status, x = p.x, y = p.y, z = p.z }
        end
    end
    for _, u in ipairs(units) do TriggerClientEvent('nexoro_map:units', u.src, rows) end
    return #rows
end

CreateThread(function()
    while true do
        Wait(cfg.UnitRefreshMs)
        M.Tick()
    end
end)
