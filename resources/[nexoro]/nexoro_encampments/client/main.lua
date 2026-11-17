local cfg = Config.Encampments
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

-- Claimable pitches are on the map so people can find the land.
CreateThread(function()
    for _, p in ipairs(cfg.Pitches) do
        local blip = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(blip, 40); SetBlipColour(blip, 47); SetBlipScale(blip, 0.6); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Pitch: ' .. p.label); EndTextCommandSetBlipName(blip)
    end
end)

RegisterNetEvent('nexoro_encampments:gate', function(g)
    if type(g) ~= 'table' then return end
    local gate
    for _, x in ipairs(cfg.Gates) do if x.id == g.id then gate = x end end
    if not gate or not gate.model then return end
    -- Swings the gate prop placed in the map to its open or closed heading.
    local obj = GetClosestObjectOfType(gate.x + 0.0, gate.y + 0.0, gate.z + 0.0, 3.0, GetHashKey(gate.model), false, false, false)
    if obj ~= 0 then SetEntityHeading(obj, (g.open and gate.openHeading or gate.closedHeading) + 0.0) end
    notify(('Gate is now %s.'):format(g.open and 'open' or 'closed'), 'info')
end)

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, g in ipairs(cfg.Gates) do
                if #(pos - vector3(g.x, g.y, g.z)) < g.radius then found = g; break end
            end
            local key = found and found.id or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI('Gate: E to open or close', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then
                    local id = found.id
                    CreateThread(function()
                        local ok, r = NexoroCore.Callback('nexoro_encampments:gate', { gate = id })
                        if not ok then notify('The gate stays as it is: ' .. tostring(r), 'error') end
                    end)
                end
            end
        end
        Wait(wait)
    end
end)
