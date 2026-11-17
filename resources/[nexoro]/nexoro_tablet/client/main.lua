local cfg = Config.Tablet
local open = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function show()
    CreateThread(function()
        local ok, apps = NexoroCore.Callback('nexoro_tablet:apps')
        if not ok then return notify(apps == 'no_tablet' and 'You need a department tablet.' or 'You do not have access to the tablet.', 'error') end
        open = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', apps = apps, forms = cfg.Forms, appDefs = cfg.Apps })
    end)
end

RegisterNetEvent('nexoro_tablet:open', show)
RegisterCommand('tablet', show, false)

RegisterNUICallback('relay', function(data, cb)
    local ok, res = NexoroCore.Callback('nexoro_tablet:relay', { app = data.app, call = data.call, payload = data.payload })
    cb({ ok = ok, data = ok and res or nil, error = not ok and res or nil })
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

AddEventHandler('nexoro:client:characterUnloadedLocal', function()
    if open then open = false; SetNuiFocus(false, false); SendNUIMessage({ action = 'close' }) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
