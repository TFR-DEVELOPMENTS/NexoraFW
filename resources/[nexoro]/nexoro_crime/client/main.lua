local cfg = Config.Crime
local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

-- /steal: take the vehicle you are standing next to (lockpick needed).
RegisterCommand('steal', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, 4.0, 0, 70)
    if veh == 0 then return notify('No vehicle close enough.', 'warning') end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    CreateThread(function()
        local ok, r = NexoroCore.Callback('nexoro_crime:steal', { netId = netId })
        if ok then notify(('You took %s (%s).'):format(r.model, r.plate), 'warning')
        else notify('Theft: ' .. tostring(r), 'error') end
    end)
end, false)

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            for _, h in ipairs(cfg.Robbery.Houses) do
                if #(pos - vector3(h.x, h.y, h.z)) < 3.0 then
                    wait = 0
                    if IsControlJustPressed(0, 38) then
                        local id = h.id
                        CreateThread(function()
                            local ok, r = NexoroCore.Callback('nexoro_crime:rob', { house = id })
                            if ok then notify('Burglary done. You took what you could carry.', 'warning')
                            else notify('Burglary: ' .. tostring(r), 'error') end
                        end)
                    end
                end
            end
            local f = cfg.Fence
            if #(pos - vector3(f.x, f.y, f.z)) < f.radius then
                wait = 0
                exports.nexoro_ui:ShowTextUI(f.label .. ': E to buy lockpicks', 'E')
                if IsControlJustPressed(0, 38) then
                    CreateThread(function()
                        local ok, r = NexoroCore.Callback('nexoro_crime:fenceBuy', { item = 'lockpick', amount = 1 })
                        if ok then notify('Bought a lockpick for ' .. r.paid .. '.', 'success')
                        else notify('Fence: ' .. tostring(r), 'error') end
                    end)
                end
            end
        end
        Wait(wait)
    end
end)
