local cfg = Config.Driving
local indicator = nil          -- 'left' | 'right' | nil
local indicatorSince = 0
local lastBeltChime = 0
local lastGrip = nil

local function driverVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function setIndicators(veh, side)
    SetVehicleIndicatorLights(veh, 1, side == 'left')    -- 1 = left
    SetVehicleIndicatorLights(veh, 0, side == 'right')   -- 0 = right
end

local function toggleIndicator(side)
    local veh = driverVehicle()
    if not veh then return end
    if indicator == side then
        indicator = nil
    else
        indicator = side
        indicatorSince = GetGameTimer()
    end
    setIndicators(veh, indicator)
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('indicator_left', 'Left indicator', cfg.LeftIndicatorKey, function() toggleIndicator('left') end)
    exports.nexoro_core:RegisterKeybind('indicator_right', 'Right indicator', cfg.RightIndicatorKey, function() toggleIndicator('right') end)
end)

-- Indicator auto-cancel, belt chime and wet-road grip.
CreateThread(function()
    while true do
        local wait = 500
        local veh = driverVehicle()
        if veh then
            wait = 250
            if indicator and GetGameTimer() - indicatorSince > cfg.IndicatorAutoCancelMs then
                indicator = nil
                setIndicators(veh, nil)
            end

            local mph = GetEntitySpeed(veh) * 2.236936
            local belted = false
            local okBelt, res = pcall(function() return exports.nexoro_hud:IsBelted() end)
            if okBelt then belted = res == true end
            local now = GetGameTimer()
            if mph > cfg.BeltWarnMph and not belted and now - lastBeltChime > cfg.BeltChimeSeconds * 1000 then
                lastBeltChime = now
                PlaySoundFrontend(-1, cfg.BeltChimeSound[1], cfg.BeltChimeSound[2], true)
            end

            if cfg.WetGrip then
                local okWet, wet = pcall(function() return exports.nexoro_world:IsWet() end)
                wet = okWet and wet == true
                if wet ~= lastGrip then
                    lastGrip = wet
                    pcall(SetVehicleReduceGrip, veh, wet)
                end
            end
        elseif lastGrip ~= nil then
            lastGrip = nil
            indicator = nil
        end
        Wait(wait)
    end
end)
