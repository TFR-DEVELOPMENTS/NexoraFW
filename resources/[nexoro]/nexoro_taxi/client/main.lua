local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local function call(name, payload, ok_text)
    CreateThread(function()
        local ok, r = NexoroCore.Callback(name, payload)
        if ok then
            if ok_text then notify(ok_text(r), 'success') end
        else
            notify('Fare: ' .. tostring(r), 'error')
        end
    end)
end

-- Passengers get an offer they can accept or decline.
RegisterNetEvent('nexoro_taxi:offer', function(o)
    if type(o) ~= 'table' then return end
    CreateThread(function()
        local accepted = NexoroUI.Confirm({ title = 'Taxi fare offer',
            text = ('%s offers you a ride. Starting fare %s, then per mile.'):format(o.driver, o.base),
            confirmLabel = 'Accept', cancelLabel = 'Decline' })
        call('nexoro_taxi:respond', { id = o.id, accept = accepted == true })
    end)
end)

-- Drivers: /taxi fare <serverId>, /taxi finish <fareId>, /taxi cancel <fareId>
RegisterCommand('taxi', function(_, args)
    local sub = args[1]
    if sub == 'fare' and tonumber(args[2]) then
        call('nexoro_taxi:offer', { passenger = tonumber(args[2]) }, function(r) return ('Fare %d offered.'):format(r.id) end)
    elseif sub == 'finish' and tonumber(args[2]) then
        call('nexoro_taxi:finish', { id = tonumber(args[2]) }, function(r) return ('Fare %s paid. You earned %s.'):format(r.fare, r.driverPay) end)
    elseif sub == 'cancel' and tonumber(args[2]) then
        call('nexoro_taxi:cancel', { id = tonumber(args[2]) }, function() return 'Fare cancelled.' end)
    else
        notify('Usage: /taxi fare <player id> · /taxi finish <fare id> · /taxi cancel <fare id>', 'info')
    end
end, false)
