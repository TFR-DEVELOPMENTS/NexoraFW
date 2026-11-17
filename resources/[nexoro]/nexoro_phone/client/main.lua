local cfg = Config.Phone
local isOpen = false
local prop = nil
local incoming = nil            -- { id, from }
local ringing = false
local inCall = false
local ringtone = 'default'
local SOUNDSETS = { default = 'Phone_SoundSet_Default', michael = 'Phone_SoundSet_Michael', franklin = 'Phone_SoundSet_Franklin', trevor = 'Phone_SoundSet_Trevor' }

local ERRORS = {
    no_phone = 'You need a mobile phone item to use this.', battery_dead = 'Your phone battery is dead. Use a charger.',
    no_character = 'Choose a character first.', rate_limited = 'Slow down a little.', timeout = 'The network is busy. Try again.',
}

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

---------------------------------------------------------------------------
-- Phone animation and prop
---------------------------------------------------------------------------

local function attachPhone()
    local ped = PlayerPedId()
    RequestAnimDict('cellphone@')
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded('cellphone@') and GetGameTimer() < deadline do Wait(0) end
    if not IsPedInAnyVehicle(ped, false) then TaskPlayAnim(ped, 'cellphone@', 'cellphone_text_read_base', 3.0, 3.0, -1, 50, 0, false, false, false) end
    local hash = GetHashKey('prop_npc_phone_02')
    RequestModel(hash)
    deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if HasModelLoaded(hash) then
        local c = GetEntityCoords(ped)
        prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(hash)
    end
end

local function detachPhone()
    local ped = PlayerPedId()
    if prop then DeleteEntity(prop); prop = nil end
    StopAnimTask(ped, 'cellphone@', 'cellphone_text_read_base', 1.0)
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    detachPhone()
end

local function openPhone()
    if isOpen then return close() end
    local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
    if not okLoaded or not loaded then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedRagdoll(ped) then return end
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_phone:open')
        if not ok then return notify(ERRORS[data] or 'Your phone is not working.', 'error') end
        ringtone = data.ringtone
        data.config = { wallpapers = cfg.Wallpapers, ringtones = cfg.Ringtones, gps = cfg.GPS }
        data.incoming = incoming
        data.inCall = inCall
        isOpen = true
        SendNUIMessage({ action = 'open', data = data })
        SetNuiFocus(true, true)
        attachPhone()
    end)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('phone', 'Open phone', cfg.OpenKey, openPhone)
end)
RegisterCommand('phone', openPhone, false)

RegisterNUICallback('close', function(_, cb) close(); cb({ ok = true }) end)

-- NUI -> server. Only phone and banking callbacks are reachable from the phone.
RegisterNUICallback('rpc', function(data, cb)
    local name = tostring(data.name or '')
    if not (name:match('^nexoro_phone:[%w:]+$') or name:match('^nexoro_banking:[%w]+$')) then return cb({ ok = false, error = 'forbidden' }) end
    local ok, result = NexoroCore.Callback(name, data.payload)
    cb({ ok = ok, data = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('gps', function(data, cb)
    local x, y = tonumber(data.x), tonumber(data.y)
    if x and y then SetNewWaypoint(x + 0.0, y + 0.0); notify('GPS route set.', 'info') end
    cb({ ok = true })
end)

RegisterNUICallback('setRingtone', function(data, cb)
    if SOUNDSETS[data.ringtone] then ringtone = data.ringtone end
    cb({ ok = true })
end)

---------------------------------------------------------------------------
-- Calls and sounds
---------------------------------------------------------------------------

local function stopRinging() ringing = false end

local function startRinging()
    if ringing then return end
    ringing = true
    CreateThread(function()
        while ringing do
            PlaySoundFrontend(-1, 'Remote_Ring', SOUNDSETS[ringtone] or SOUNDSETS.default, true)
            Wait(2500)
        end
    end)
end

RegisterNetEvent('nexoro_phone:incoming', function(call)
    incoming = call
    startRinging()
    SendNUIMessage({ action = 'incoming', call = call })
    if not isOpen then notify(('Incoming call from %s. Press Y to answer, N to decline.'):format(call.from), 'info') end
end)
RegisterNetEvent('nexoro_phone:answered', function() inCall = true; SendNUIMessage({ action = 'answered' }) end)
RegisterNetEvent('nexoro_phone:ended', function(info)
    incoming, inCall = nil, false
    stopRinging()
    SendNUIMessage({ action = 'ended', info = info })
end)
RegisterNetEvent('nexoro_phone:message', function(msg)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    SendNUIMessage({ action = 'message', message = msg })
end)
RegisterNetEvent('nexoro_phone:mail', function(m) SendNUIMessage({ action = 'mail', mail = m }) end)
RegisterNetEvent('nexoro_phone:battery', function(level) SendNUIMessage({ action = 'battery', level = level }) end)

-- Answer / decline with Y / N while the phone is closed.
CreateThread(function()
    while true do
        if incoming and not inCall and not isOpen then
            if IsControlJustPressed(0, 246) then
                local ok = NexoroCore.Callback('nexoro_phone:answer', { id = incoming.id })
                if ok then inCall = true; stopRinging() end
            elseif IsControlJustPressed(0, 306) then
                NexoroCore.Callback('nexoro_phone:hangup')
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Game clock for the status bar (24-hour).
CreateThread(function()
    while true do
        if isOpen then SendNUIMessage({ action = 'clock', time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) }) end
        Wait(3000)
    end
end)

AddEventHandler('nexoro:client:characterUnloadedLocal', function() close(); stopRinging(); incoming, inCall = nil, false end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then if isOpen then SetNuiFocus(false, false) end detachPhone() end
end)
