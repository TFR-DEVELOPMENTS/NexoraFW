local hazards = {}
local inside = {}

RegisterNetEvent('nexoro_fire:hazards', function(list)
    if type(list) == 'table' then hazards = list end
end)

-- Warns once each time the player walks into a hazard zone.
CreateThread(function()
    while true do
        Wait(2000)
        if #hazards > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local now = GetGameTimer()
            local seen = {}
            for _, h in ipairs(hazards) do
                local d = #(pos - vector3(h.x, h.y, h.z))
                if d <= h.radius then
                    seen[h.id] = true
                    if not inside[h.id] then
                        inside[h.id] = true
                        TriggerEvent('nexoro:notify', { message = 'Hazard zone: fire and smoke. Keep clear or wear appropriate protection.', type = 'emergency', duration = 6000 })
                    end
                end
            end
            for id in pairs(inside) do if not seen[id] then inside[id] = nil end end
        end
    end
end)
