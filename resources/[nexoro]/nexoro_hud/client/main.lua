local cfg = Config.Hud
local KVP = 'nexoro_hud_settings'
local DIRECTIONS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }

local settings = { position = cfg.DefaultPosition, scale = 1.0, hidden = {}, radar = cfg.ShowRadar == true }
local needs = { hunger = 100, thirst = 100, stress = 0 }
local seatbelt = false
local lastJson = ''
local prevSpeed = 0.0

do
    local raw = GetResourceKvpString(KVP)
    if raw then
        local ok, saved = pcall(json.decode, raw)
        if ok and type(saved) == 'table' then
            settings.position = ({ ['bottom-right'] = true, ['bottom-left'] = true, ['bottom-centre'] = true })[saved.position] and saved.position or settings.position
            settings.scale = math.min(math.max(tonumber(saved.scale) or 1.0, 0.7), 1.4)
            settings.hidden = type(saved.hidden) == 'table' and saved.hidden or {}
            if type(saved.radar) == 'boolean' then settings.radar = saved.radar end
        end
    end
end

local ELEMENTS = {
    { key = 'health', label = 'Health' }, { key = 'armour', label = 'Armour' }, { key = 'hunger', label = 'Hunger' }, { key = 'thirst', label = 'Thirst' },
    { key = 'stress', label = 'Stress' }, { key = 'stamina', label = 'Stamina' }, { key = 'money', label = 'Cash and bank' }, { key = 'identity', label = 'Name, ID and job' },
    { key = 'voice', label = 'Voice indicator' }, { key = 'location', label = 'Street and compass' }, { key = 'vehicle', label = 'Vehicle panel' },
}

local function applySettings() SendNUIMessage({ action = 'settings', settings = settings }) end

local function saveSettings()
    SetResourceKvp(KVP, json.encode(settings))
    applySettings()
end

local function openSettings()
    CreateThread(function()
        local fields = {
            { type = 'select', name = 'position', label = 'HUD position', default = settings.position, options = { 'bottom-right', 'bottom-left', 'bottom-centre' } },
            { type = 'number', name = 'scale', label = 'Size (0.7 to 1.4)', default = settings.scale, min = 0.7, max = 1.4, step = 0.05 },
            { type = 'checkbox', name = 'radar', label = 'Show the minimap (its own vanilla health and stamina bars come with it)', default = settings.radar },
        }
        for _, e in ipairs(ELEMENTS) do fields[#fields + 1] = { type = 'checkbox', name = e.key, label = 'Show: ' .. e.label, default = not settings.hidden[e.key] } end
        local values = NexoroUI.Input({ title = 'HUD settings', fields = fields, submitLabel = 'Save' })
        if not values then return end
        settings.position = values.position or settings.position
        settings.scale = math.min(math.max(tonumber(values.scale) or 1.0, 0.7), 1.4)
        settings.radar = values.radar == true
        settings.hidden = {}
        for _, e in ipairs(ELEMENTS) do if values[e.key] == false then settings.hidden[e.key] = true end end
        saveSettings()
    end)
end

RegisterCommand('hud', openSettings, false)
exports('OpenSettings', openSettings)

RegisterNetEvent('nexoro_hud:needs', function(n)
    if type(n) == 'table' then needs = n end
end)

RegisterNetEvent('nexoro_hud:starving', function(damage)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - (tonumber(damage) or 5)))
    TriggerEvent('nexoro:notify', { message = 'You are starving. Find something to eat or drink.', type = 'warning' })
end)

-- Seatbelt
CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('seatbelt', 'Toggle seatbelt', cfg.SeatbeltKey, function()
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then return end
        seatbelt = not seatbelt
        PlaySoundFrontend(-1, seatbelt and cfg.BeltSound[1] or cfg.BeltRemoveSound[1], seatbelt and cfg.BeltSound[2] or cfg.BeltRemoveSound[2], true)
        TriggerEvent('nexoro:notify', { message = seatbelt and 'Seatbelt fastened.' or 'Seatbelt removed.', type = 'info', duration = 2000 })
    end)
end)

local function hideDefaults()
    HideHudComponentThisFrame(3); HideHudComponentThisFrame(4); HideHudComponentThisFrame(6)
    HideHudComponentThisFrame(7); HideHudComponentThisFrame(8); HideHudComponentThisFrame(9)
end

CreateThread(function()
    while true do
        hideDefaults()
        DisplayRadar(settings.radar == true)
        local ped = PlayerPedId()
        if seatbelt and IsPedInAnyVehicle(ped, false) then DisableControlAction(0, 75, true) end
        Wait(0)
    end
end)

local function direction(heading)
    return DIRECTIONS[(math.floor(((heading + 22.5) % 360) / 45) % 8) + 1]
end

local function collect()
    local ped = PlayerPedId()
    local maxHealth = GetEntityMaxHealth(ped)
    local data = {
        health = math.max(0, math.floor((GetEntityHealth(ped) - 100) / math.max(maxHealth - 100, 1) * 100 + 0.5)),
        armour = GetPedArmour(ped), hunger = needs.hunger, thirst = needs.thirst, stress = needs.stress,
        stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(PlayerId()) + 0.5),
        id = GetPlayerServerId(PlayerId()), talking = NetworkIsPlayerTalking(PlayerId()),
    }
    local okChar, character = pcall(function() return exports.nexoro_core:GetCharacterData() end)
    if okChar and character then
        data.name = character.firstName .. ' ' .. character.lastName
        data.job = character.job and (character.job.label .. ' · ' .. character.job.gradeLabel) or nil
        data.onDuty = character.job and character.job.onDuty or false
        data.cash, data.bank = character.cash, character.bank
    end
    local proximity = LocalPlayer.state.proximity
    data.voiceMode = type(proximity) == 'table' and proximity.mode or 'Normal'
    local radio = LocalPlayer.state.radioChannel
    data.radio = (type(radio) == 'number' and radio > 0) and radio or nil

    local coords = GetEntityCoords(ped)
    local street = GetStreetNameFromHashKey((GetStreetNameAtCoord(coords.x, coords.y, coords.z)))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    data.street, data.zone = street, zone ~= 'NULL' and zone or ''
    data.compass = direction(GetEntityHeading(ped))

    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local speed = GetEntitySpeed(veh) * 2.236936
        data.vehicle = {
            speed = math.floor(speed + 0.5), fuel = math.floor(GetVehicleFuelLevel(veh) + 0.5),
            engine = math.max(0, math.floor(GetVehicleEngineHealth(veh) / 10 + 0.5)), seatbelt = seatbelt,
            engineOn = GetIsVehicleEngineRunning(veh),
        }
        if not seatbelt and prevSpeed - speed > cfg.EjectSpeedDropMph and prevSpeed > 40.0 then
            local fwd = GetEntityForwardVector(veh)
            SetEntityCoords(ped, coords.x + fwd.x * 1.0, coords.y + fwd.y * 1.0, coords.z + 0.4, false, false, false, false)
            SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
            SetEntityVelocity(ped, fwd.x * prevSpeed * 0.3, fwd.y * prevSpeed * 0.3, 2.0)
        end
        prevSpeed = speed
    else
        seatbelt = false
        prevSpeed = 0.0
    end
    return data
end

CreateThread(function()
    applySettings()
    while true do
        Wait(cfg.UpdateIntervalMs)
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local data = collect()
            local encoded = json.encode(data)
            if encoded ~= lastJson then   -- only talk to the UI when something changed
                lastJson = encoded
                SendNUIMessage({ action = 'update', data = data })
            end
        elseif lastJson ~= '' then
            lastJson = ''
            SendNUIMessage({ action = 'clear' })
        end
    end
end)

---------------------------------------------------------------------------
-- Small on-screen text. Used for the route guide. Size and colour are deliberately modest.
---------------------------------------------------------------------------
local function drawSmall(text, x, y)
    SetTextFont(4)
    SetTextScale(0.0, cfg.RouteTextScale)
    SetTextColour(255, 204, 0, 235)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Route guide: the destination street and distance, shown small at the bottom of the screen.
CreateThread(function()
    while true do
        local wait = 500
        if IsWaypointActive() and not IsEntityDead(PlayerPedId()) then
            local blip = GetFirstBlipInfoId(8)
            if DoesBlipExist(blip) then
                wait = 0
                local wp = GetBlipInfoIdCoord(blip)
                local me = GetEntityCoords(PlayerPedId())
                local miles = #(me - vector3(wp.x, wp.y, wp.z)) / 1609.34
                local street = GetStreetNameFromHashKey((GetStreetNameAtCoord(wp.x, wp.y, wp.z)))
                drawSmall(('Route: %s  ·  %.1f mi'):format(street ~= '' and street or 'Destination', miles), 0.5, 0.94)
            end
        end
        Wait(wait)
    end
end)

exports('IsBelted', function() return seatbelt == true end)
