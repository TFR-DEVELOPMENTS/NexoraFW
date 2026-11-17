local PRIORITY_COLOUR = { [1] = 'emergency', [2] = 'warning', [3] = 'info' }

RegisterNetEvent('nexoro_dispatch:alert', function(a)
    if type(a) ~= 'table' then return end
    TriggerEvent('nexoro:notify', {
        title = ('%s - Incident %d'):format(a.label or 'Incident', a.id or 0),
        message = tostring(a.description or ''):sub(1, 200),
        type = PRIORITY_COLOUR[a.priority] or 'emergency',
        duration = 9000,
    })
end)

RegisterNetEvent('nexoro_dispatch:waypoint', function(w)
    if type(w) ~= 'table' or type(w.x) ~= 'number' or type(w.y) ~= 'number' then return end
    SetNewWaypoint(w.x + 0.0, w.y + 0.0)
    TriggerEvent('nexoro:notify', { message = 'Route set: ' .. tostring(w.label or 'Incident'), type = 'emergency' })
end)

RegisterCommand('radio', function(_, args)
    local ch = tonumber(args[1])
    if not ch then return TriggerEvent('nexoro:notify', { message = 'Usage: /radio <channel>', type = 'info' }) end
    CreateThread(function()
        local ok, res = NexoroCore.Callback('nexoro_dispatch:radioJoin', { channel = ch })
        if ok then TriggerEvent('nexoro:notify', { message = ('Radio channel %d.'):format(res.channel), type = 'success' })
        else TriggerEvent('nexoro:notify', { message = 'Radio: ' .. tostring(res), type = 'error' }) end
    end)
end, false)

RegisterCommand('radiooff', function()
    CreateThread(function() NexoroCore.Callback('nexoro_dispatch:radioLeave') end)
end, false)
