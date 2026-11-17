-- Restraint state. The server decides who is cuffed; this only enforces it locally.
local cuffed = false
local DISABLED = { 21, 22, 24, 25, 140, 141, 142, 143, 257, 263, 264 }  -- sprint, jump, attacks, weapons, melee

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'warning' }) end

local function playRestraintAnim()
    local dict = 'mp_arresting'
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    if HasAnimDictLoaded(dict) then TaskPlayAnim(PlayerPedId(), dict, 'idle', 8.0, 8.0, -1, 49, 0, false, false, false) end
end

RegisterNetEvent('nexoro_police:cuffs', function(state)
    cuffed = state == true
    if cuffed then
        notify('You have been handcuffed.', 'warning')
        CreateThread(playRestraintAnim)
        CreateThread(function()
            while cuffed do
                for _, c in ipairs(DISABLED) do DisableControlAction(0, c, true) end
                DisablePlayerFiring(PlayerId(), true)
                Wait(0)
            end
        end)
    else
        notify('Your handcuffs have been removed.', 'info')
        ClearPedTasks(PlayerPedId())
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cuffed = false end
end)
