Nexoro = Nexoro or {}
Nexoro.Session = { ready = false, character = nil }

local ready = false

-- The server registers the player a moment after the client starts, so ask until it answers.
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    local attempts = 0
    while not ready and attempts < 60 do
        TriggerServerEvent('nexoro:server:clientReady')
        attempts = attempts + 1
        Wait(2000)
    end
end)

RegisterNetEvent('nexoro:client:playerReady', function(state)
    ready = true
    Nexoro.Session.ready = true
    Nexoro.Session.character = state and state.character or nil
    TriggerEvent('nexoro:client:playerReadyLocal', state)
end)

RegisterNetEvent('nexoro:client:characterLoaded', function(character)
    Nexoro.Session.character = character
    TriggerEvent('nexoro:client:characterLoadedLocal', character)
end)

RegisterNetEvent('nexoro:client:characterUnloaded', function()
    Nexoro.Session.character = nil
    TriggerEvent('nexoro:client:characterUnloadedLocal')
end)

RegisterNetEvent('nexoro:client:jobUpdated', function(job)
    if Nexoro.Session.character then Nexoro.Session.character.job = job end
    TriggerEvent('nexoro:client:jobUpdatedLocal', job)
end)

RegisterNetEvent('nexoro:client:moneyUpdated', function(account, balance)
    if Nexoro.Session.character then Nexoro.Session.character[account] = balance end
    TriggerEvent('nexoro:client:moneyUpdatedLocal', account, balance)
end)

-- Uses nexoro_notifications (Phase 2) when running, otherwise the GTA feed.
RegisterNetEvent('nexoro:client:notify', function(data)
    if type(data) ~= 'table' or type(data.message) ~= 'string' then return end
    if GetResourceState('nexoro_notifications') == 'started' then
        local ok = pcall(function() exports.nexoro_notifications:Notify(data) end)
        if ok then return end
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(data.message)
    EndTextCommandThefeedPostTicker(false, true)
end)

exports('GetCharacterData', function() return Nexoro.Session.character end)
exports('IsCharacterLoaded', function() return Nexoro.Session.character ~= nil end)
exports('IsReady', function() return Nexoro.Session.ready end)

-- GTA's own police are switched off so Nexoro roleplay police is the only police.
if Config.Framework.DisableGtaPolice then
    CreateThread(function()
        while true do
            for service = 1, 15 do EnableDispatchService(service, false) end
            SetMaxWantedLevel(0)
            local pid = PlayerId()
            if GetPlayerWantedLevel(pid) > 0 then
                SetPlayerWantedLevel(pid, 0, false)
                SetPlayerWantedLevelNow(pid, false)
            end
            Wait(1000)
        end
    end)
end
