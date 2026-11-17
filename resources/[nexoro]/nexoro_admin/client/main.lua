local cfg = Config.Admin
local isOpen = false
local state = { noclip = false, god = false, invisible = false, nametags = false, frozenWorld = false }
local spectating = false
local world = nil

local function notify(text, kind) pcall(function() exports.nexoro_core:GetCharacterData() end); TriggerEvent('nexoro:notify', { message = text, type = kind or 'staff' }) end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

local function setOpen(open)
    isOpen = open
    SetNuiFocus(open, open)
    if not open then SendNUIMessage({ action = 'close' }) end
end

local function openMenu()
    if isOpen then return setOpen(false) end
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_admin:open')
        if not ok then return notify('You are not staff on this server. If you should be owner, check the server console for the claim code, or type /mystaff.', 'error') end
        SendNUIMessage({ action = 'open', menu = data })
        setOpen(true)
    end)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('admin_menu', 'Open staff menu', cfg.OpenKey, openMenu)
end)
RegisterCommand('admin', openMenu, false)
RegisterCommand('mod', openMenu, false)

local ENDPOINTS = { dashboard = true, players = true, player = true, logs = true, economy = true, bans = true, vehicles = true }

RegisterNUICallback('api', function(data, cb)
    if data.endpoint == 'action' then
        local ok, result = NexoroCore.Callback('nexoro_admin:action', data.name, data.payload)
        return cb({ ok = ok, data = ok and result or nil, error = not ok and result or nil })
    end
    if not ENDPOINTS[data.endpoint] then return cb({ ok = false, error = 'unknown_endpoint' }) end
    local ok, result = NexoroCore.Callback('nexoro_admin:' .. data.endpoint, data.payload)
    cb({ ok = ok, data = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('close', function(_, cb) setOpen(false); cb({ ok = true }) end)

---------------------------------------------------------------------------
-- Effects requested by the server (permission already checked there)
---------------------------------------------------------------------------

local function groundZ(x, y)
    for z = 1000.0, -100.0, -25.0 do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
        local found, gz = GetGroundZFor_3dCoord(x, y, z, false)
        if found then return gz end
    end
    return nil
end

local function mainEntity()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    return veh ~= 0 and veh or ped
end

local function startNoclip()
    CreateThread(function()
        local ped = PlayerPedId()
        SetEntityInvincible(ped, true)
        while state.noclip do
            Wait(0)
            local entity = mainEntity()
            SetEntityCollision(entity, false, false)
            local pos = GetEntityCoords(entity)
            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local fx, fy, fz = -math.sin(yaw) * math.abs(math.cos(pitch)), math.cos(yaw) * math.abs(math.cos(pitch)), math.sin(pitch)
            local rx, ry = math.cos(yaw), math.sin(yaw)
            local speed = IsControlPressed(0, 21) and 3.0 or (IsControlPressed(0, 19) and 0.15 or 0.7)
            local x, y, z = pos.x, pos.y, pos.z
            if IsControlPressed(0, 32) then x, y, z = x + fx * speed, y + fy * speed, z + fz * speed end
            if IsControlPressed(0, 33) then x, y, z = x - fx * speed, y - fy * speed, z - fz * speed end
            if IsControlPressed(0, 34) then x, y = x - rx * speed, y - ry * speed end
            if IsControlPressed(0, 35) then x, y = x + rx * speed, y + ry * speed end
            if IsControlPressed(0, 22) then z = z + speed end
            if IsControlPressed(0, 36) then z = z - speed end
            SetEntityCoordsNoOffset(entity, x, y, z, true, true, true)
            SetEntityHeading(entity, -math.deg(yaw) % 360.0)
        end
        local entity = mainEntity()
        SetEntityCollision(entity, true, true)
        SetEntityInvincible(PlayerPedId(), state.god)
    end)
end

local function drawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, 0.32); SetTextFont(4); SetTextCentre(true); SetTextOutline()
    SetTextColour(255, 204, 0, 230)
    BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function startNametags()
    CreateThread(function()
        while state.nametags do
            Wait(0)
            local mine = GetEntityCoords(PlayerPedId())
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                local pos = GetEntityCoords(ped)
                if #(mine - pos) < 60.0 then
                    drawText3D(pos.x, pos.y, pos.z + 1.05, ('[%d] %s'):format(GetPlayerServerId(player), GetPlayerName(player)))
                end
            end
        end
    end)
end

local function spawnVehicle(data)
    local hash = GetHashKey(data.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return notify('Unknown vehicle model: ' .. tostring(data.model), 'error') end
    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return notify('Vehicle model failed to load.', 'error') end
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.5)
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(veh)
    if data.plate then SetVehicleNumberPlateText(veh, data.plate) end
    TaskWarpPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)
end

local function targetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local c = GetEntityCoords(ped)
    veh = GetClosestVehicle(c.x, c.y, c.z, 6.0, 0, 71)
    return veh ~= 0 and veh or nil
end

local EFFECTS = {
    freeze = function(on) FreezeEntityPosition(PlayerPedId(), on == true); notify(on and 'You have been frozen by staff.' or 'You have been unfrozen.', 'staff') end,
    heal = function() SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId())) end,
    armour = function() SetPedArmour(PlayerPedId(), 100) end,
    revive = function()
        local ped = PlayerPedId()
        if IsEntityDead(ped) then
            local c = GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
            ClearPedTasksImmediately(PlayerPedId())
        end
        SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
    end,
    noclip = function(on) state.noclip = on; if on then startNoclip() end; notify('Noclip ' .. (on and 'on' or 'off'), 'staff') end,
    god = function(on) state.god = on; SetEntityInvincible(PlayerPedId(), on or state.noclip); notify('God mode ' .. (on and 'on' or 'off'), 'staff') end,
    invisible = function(on) state.invisible = on; SetEntityVisible(PlayerPedId(), not on, false); notify('Invisible ' .. (on and 'on' or 'off'), 'staff') end,
    nametags = function(on) state.nametags = on; if on then startNametags() end end,
    tpwaypoint = function()
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then return notify('Set a waypoint on the map first.', 'warning') end
        local c = GetBlipInfoIdCoord(blip)
        local z = groundZ(c.x, c.y) or c.z
        SetEntityCoordsNoOffset(mainEntity(), c.x, c.y, z + 1.0, false, false, false)
    end,
    spawnvehicle = spawnVehicle,
    deletevehicle = function() local v = targetVehicle(); if v then NetworkRequestControlOfEntity(v); SetEntityAsMissionEntity(v, true, true); DeleteVehicle(v) end end,
    repairvehicle = function() local v = targetVehicle(); if v then SetVehicleFixed(v); SetVehicleDeformationFixed(v); SetVehicleEngineHealth(v, 1000.0); SetVehicleDirtLevel(v, 0.0) end end,
    cleanvehicle = function() local v = targetVehicle(); if v then WashDecalsFromVehicle(v, 1.0); SetVehicleDirtLevel(v, 0.0) end end,
    flipvehicle = function() local v = targetVehicle(); if v then SetEntityRotation(v, 0.0, 0.0, GetEntityHeading(v), 2, true); SetVehicleOnGroundProperly(v) end end,
    spectate = function(targetId)
        if targetId == nil then
            if spectating then NetworkSetInSpectatorMode(false, PlayerPedId()); spectating = false end
            return
        end
        CreateThread(function()
            local deadline = GetGameTimer() + 5000
            local player = GetPlayerFromServerId(targetId)
            while (player == -1 or not DoesEntityExist(GetPlayerPed(player))) and GetGameTimer() < deadline do Wait(100); player = GetPlayerFromServerId(targetId) end
            if player == -1 then return notify('Could not stream that player in to spectate.', 'warning') end
            NetworkSetInSpectatorMode(true, GetPlayerPed(player))
            spectating = true
            notify('Spectating. Use the Stop spectating button or /mod to leave.', 'staff')
        end)
    end,
}

RegisterNetEvent('nexoro:admin:client', function(kind, data)
    local fn = EFFECTS[kind]
    if fn then fn(data) end
end)

---------------------------------------------------------------------------
-- World sync (weather and time controlled by staff)
---------------------------------------------------------------------------

RegisterNetEvent('nexoro:world:sync', function(w)
    if type(w) ~= 'table' or GetResourceState('nexoro_world') == 'started' then return end
    world = w
    ClearOverrideWeather(); ClearWeatherTypePersist()
    SetWeatherTypePersist(w.weather); SetWeatherTypeNow(w.weather); SetWeatherTypeNowPersist(w.weather)
    NetworkOverrideClockTime(w.hour, w.minute, 0)
end)

CreateThread(function()
    while true do
        if world and world.frozen then
            NetworkOverrideClockTime(world.hour, world.minute, 0)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    state.noclip, state.nametags = false, false
    SetEntityVisible(PlayerPedId(), true, false)
end)
