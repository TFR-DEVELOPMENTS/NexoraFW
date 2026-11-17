local TYPES = { success = true, error = true, warning = true, info = true, emergency = true, job = true, banking = true, inventory = true, staff = true }

-- data = { message = 'text', type = 'success', duration = 5000, title = 'optional' }
local function notify(data)
    if type(data) ~= 'table' or type(data.message) ~= 'string' then return end
    local kind = TYPES[data.type] and data.type or 'info'
    SendNUIMessage({
        action = 'notify', message = data.message:sub(1, 300), title = type(data.title) == 'string' and data.title:sub(1, 40) or nil,
        kind = kind, duration = math.min(math.max(tonumber(data.duration) or 5000, 1500), 30000),
    })
    local snd = Config.Notifications.Sounds and Config.Notifications.SoundFor[kind]
    if snd then PlaySoundFrontend(-1, snd[1], snd[2], true) end
end

exports('Notify', notify)
RegisterNetEvent('nexoro:notify', notify)

-- Keeps GTA's own top-corner feed out of the way while Nexoro notifications are in use.
if Config.Notifications.HideVanillaFeed then
    CreateThread(function()
        while true do
            ThefeedHideThisFrame()
            Wait(0)
        end
    end)
end
