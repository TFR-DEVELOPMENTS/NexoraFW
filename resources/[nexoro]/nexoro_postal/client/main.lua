local cfg = Config.Postal
local current = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

RegisterNetEvent('nexoro_postal:stop', function(stop)
    if type(stop) ~= 'table' then return end
    current = stop
    SetNewWaypoint(stop.x + 0.0, stop.y + 0.0)
    notify('Next drop: ' .. stop.label .. '. Press E at the door when you arrive.', 'info')
end)

local function deliver()
    CreateThread(function()
        local ok, r = NexoroCore.Callback('nexoro_postal:deliver')
        if not ok then return notify('Delivery: ' .. tostring(r), 'error') end
        if r.done then
            current = nil
            notify(('Round complete. You were paid %s.'):format(r.paid), 'success')
        else
            notify(('Delivered. %s paid. Next: %s.'):format(r.paid, r.next), 'banking')
        end
    end)
end

-- /postal duty · /postal start · /postal stop
RegisterCommand('postal', function(_, args)
    local sub = args[1]
    CreateThread(function()
        if sub == 'duty' then
            local ok, r = NexoroCore.Callback('nexoro_postal:duty')
            notify(ok and (r.onDuty and 'You are on duty as a postal worker.' or 'You are off duty.') or ('Postal: ' .. tostring(r)), ok and 'success' or 'error')
        elseif sub == 'start' then
            local ok, r = NexoroCore.Callback('nexoro_postal:start')
            if ok then notify(('Round started: %d drops. First: %s.'):format(r.stops, r.first), 'success')
            else notify('Postal: ' .. tostring(r), 'error') end
        elseif sub == 'stop' then
            NexoroCore.Callback('nexoro_postal:stop')
            current = nil
            notify('Round ended.', 'info')
        else
            notify('Usage: /postal duty · /postal start · /postal stop', 'info')
        end
    end)
end, false)

CreateThread(function()
    while true do
        local wait = 800
        if current then
            local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
            if okLoaded and loaded then
                local pos = GetEntityCoords(PlayerPedId())
                if #(pos - vector3(current.x, current.y, current.z)) < cfg.StopRadius then
                    exports.nexoro_ui:ShowTextUI('Deliver: ' .. current.label, 'E')
                    wait = 0
                    if IsControlJustPressed(0, 38) then deliver() end
                else
                    exports.nexoro_ui:HideTextUI()
                end
            end
        end
        Wait(wait)
    end
end)
