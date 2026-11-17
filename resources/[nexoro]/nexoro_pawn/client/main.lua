-- /pawn <item> <amount>, used at the pawn shop counter.
local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

RegisterCommand('pawn', function(_, args)
    if not args[1] then return notify('Usage: /pawn <item id> [amount]', 'info') end
    CreateThread(function()
        local ok, r = NexoroCore.Callback('nexoro_pawn:sell', { item = args[1], amount = tonumber(args[2]) or 1 })
        if ok then notify('Pawned for ' .. r.received .. '.', 'banking') else notify('Pawn: ' .. tostring(r), 'error') end
    end)
end, false)
