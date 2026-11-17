local cfg = Config.Chat
local open = false

local SLASH = { r = 'radio', radio = 'radio', ooc = 'global', global = 'global', me = 'me', ['do'] = 'do', dept = 'department', department = 'department', ['999'] = 'emergency', emergency = 'emergency', staff = 'staff', say = 'local' }

local function setOpen(state)
    open = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = state and 'openInput' or 'closeInput' })
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('chat', 'Open chat', cfg.OpenKey, function()
        local ok, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if ok and loaded and not open then setOpen(true) end
    end)
end)

RegisterNetEvent('nexoro_chat:message', function(message)
    SendNUIMessage({ action = 'message', message = message })
end)

-- Compatibility: scripts written for the default FiveM chat resource still work.
RegisterNetEvent('chat:addMessage', function(data)
    if type(data) ~= 'table' then return end
    local text = data.args and table.concat(data.args, ' ') or data.message or ''
    SendNUIMessage({ action = 'message', message = { time = '', channelLabel = 'INFO', channelColour = '#FFCC00', prefix = { label = tostring(data.args and #data.args > 1 and data.args[1] or 'SYSTEM'), colour = '#FFCC00' }, name = '', text = tostring(text):sub(1, 400) } })
end)

RegisterNUICallback('submit', function(data, cb)
    cb({ ok = true })
    setOpen(false)
    local text = type(data.text) == 'string' and data.text or ''
    local channel = type(data.channel) == 'string' and data.channel or 'local'
    if text:sub(1, 1) == '/' then
        local name, rest = text:match('^/(%S+)%s*(.*)$')
        if not name then return end
        name = name:lower()
        if name == 'pm' then
            local id, body = rest:match('^(%d+)%s+(.+)$')
            if id then TriggerServerEvent('nexoro_chat:send', 'pm', body, tonumber(id)) end
        elseif SLASH[name] then
            TriggerServerEvent('nexoro_chat:send', SLASH[name], rest)
        else
            ExecuteCommand(text:sub(2))
        end
        return
    end
    if text ~= '' then TriggerServerEvent('nexoro_chat:send', channel, text) end
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
