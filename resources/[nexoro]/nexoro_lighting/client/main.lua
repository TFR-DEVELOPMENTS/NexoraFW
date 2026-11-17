local cfg = Config.Lighting
local states = {}          -- array of { net, preset, siren }
local presetNames = {}
for name in pairs(cfg.Presets) do presetNames[#presetNames + 1] = name end
table.sort(presetNames)

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info', duration = 2500 }) end

RegisterNetEvent('nexoro_lighting:states', function(list)
    if type(list) == 'table' then states = list end
end)

local function stateFor(net)
    for _, s in ipairs(states) do if s.net == net then return s end end
    return nil
end

local function drawPattern(veh, preset, now)
    local p = cfg.Presets[preset]
    if not p then return end
    local total = 0
    for _, step in ipairs(p.steps) do total = total + step[3] end
    local t = now % total
    local current = p.steps[1]
    local acc = 0
    for _, step in ipairs(p.steps) do
        acc = acc + step[3]
        if t < acc then current = step; break end
    end
    local side, colour = current[1], cfg.Colours[current[2]]
    if side == 'off' or not colour then return end
    for _, lp in ipairs(cfg.LightPoints) do
        if side == 'both' or lp.side == side then
            local wx, wy, wz = GetOffsetFromEntityInWorldCoords(veh, lp.x, lp.y, lp.z)
            DrawLightWithRange(wx, wy, wz, colour[1], colour[2], colour[3], cfg.DrawRange, cfg.DrawIntensity)
        end
    end
end

-- Draws the LED patterns for nearby emergency vehicles.
CreateThread(function()
    while true do
        local wait = 400
        if #states > 0 then
            local me = GetEntityCoords(PlayerPedId())
            local now = GetGameTimer()
            for _, s in ipairs(states) do
                local veh = NetworkGetEntityFromNetworkId(s.net)
                if veh ~= 0 and DoesEntityExist(veh) then
                    if #(me - GetEntityCoords(veh)) <= cfg.ViewDistance then
                        wait = 0
                        drawPattern(veh, s.preset, now)
                    end
                    -- Siren sound follows the state on every client, so everyone hears it.
                    SetVehicleSiren(veh, s.siren == true)
                end
            end
        end
        Wait(wait)
    end
end)

-- Driver controls.
local function currentVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function cyclePreset()
    CreateThread(function()
        local veh = currentVehicle()
        if not veh then return notify('Drive an emergency vehicle to use the lightbar.', 'warning') end
        local net = NetworkGetNetworkIdFromEntity(veh)
        local s = stateFor(net)
        local nextPreset = presetNames[1]
        if s then
            local idx
            for i, name in ipairs(presetNames) do if name == s.preset then idx = i end end
            nextPreset = idx and presetNames[idx + 1] or presetNames[1]
        end
        local ok, res
        if not nextPreset then
            ok, res = NexoroCore.Callback('nexoro_lighting:set', { net = net, preset = 'off' })
        else
            ok, res = NexoroCore.Callback('nexoro_lighting:set', { net = net, preset = nextPreset })
        end
        if not ok then return notify('Lightbar: ' .. tostring(res), 'error') end
        notify(res.preset == 'off' and 'Lightbar off.' or ('Lightbar: ' .. cfg.Presets[res.preset].label), 'info')
    end)
end

local function toggleSiren()
    CreateThread(function()
        local veh = currentVehicle()
        if not veh then return end
        local net = NetworkGetNetworkIdFromEntity(veh)
        local s = stateFor(net)
        local on = not (s and s.siren)
        local ok, res = NexoroCore.Callback('nexoro_lighting:siren', { net = net, on = on })
        if not ok then return notify('Siren: ' .. tostring(res), 'error') end
    end)
end

local function airhorn()
    local veh = currentVehicle()
    if veh then StartVehicleHorn(veh, 1500, GetHashKey('HELDDOWN'), false) end
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('lighting_preset', 'Cycle lightbar pattern', cfg.LightKey, cyclePreset)
    exports.nexoro_core:RegisterKeybind('lighting_siren', 'Toggle siren', cfg.SirenKey, toggleSiren)
    exports.nexoro_core:RegisterKeybind('lighting_airhorn', 'Airhorn', cfg.AirhornKey, airhorn)
end)
