local cfg = Config.Death
local downed, reporting, bleeding = false, false, false
local downedAt = 0

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'warning', duration = 6000 }) end

local function nearestHospital()
    local c = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, h in ipairs(cfg.Hospitals) do
        local d = #(c - vector3(h.x, h.y, h.z))
        if not bestD or d < bestD then best, bestD = h, d end
    end
    return best or cfg.Hospitals[1]
end

-- Lying-down emote. The character and clothes stay the same; only the pose changes.
local function lieDown()
    local ped = PlayerPedId()
    RequestAnimDict(cfg.Anim.dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(cfg.Anim.dict) and GetGameTimer() < deadline do Wait(0) end
    if HasAnimDictLoaded(cfg.Anim.dict) then
        TaskPlayAnim(ped, cfg.Anim.dict, cfg.Anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

local function clearState()
    downed, bleeding = false, false
    exports.nexoro_ui:HideTextUI()
end

-- Brings the SAME ped back on the spot or at a hospital. Keeps clothes, appearance and inventory.
local function resurrect(h)
    NetworkResurrectLocalPlayer(h.x, h.y, h.z, h.heading or 0.0, true, false)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, cfg.RespawnHealth)
    clearState()
end

local function report()
    if reporting then return end
    reporting = true
    CreateThread(function()
        local ok = NexoroCore.Callback('nexoro_death:report')
        reporting = false
        if not ok then return end
    end)
end

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return ('%d:%02d'):format(m, s)
end

CreateThread(function()
    while true do
        local wait = cfg.TickMs
        local ped = PlayerPedId()
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and IsEntityDead(ped) then
            if not downed then
                downed = true
                downedAt = GetGameTimer()
                CreateThread(lieDown)
                report()
            end
            local left = math.max(0, cfg.BleedOutSeconds - (GetGameTimer() - downedAt) / 1000)
            if left > 0 then
                exports.nexoro_ui:ShowTextUI(('Critically injured. Bleeding out in %s. Emergency services can revive you.'):format(formatTime(left)), nil)
            else
                exports.nexoro_ui:ShowTextUI('Bleeding out. Respawning at hospital...', nil)
            end
            for _, c in ipairs(cfg.DisableControls) do DisableControlAction(0, c, true) end
            wait = 0
            if left <= 0 and not bleeding then
                bleeding = true
                CreateThread(function()
                    local ok = NexoroCore.Callback('nexoro_death:bleedout')
                    if ok then
                        resurrect(nearestHospital())
                        notify('You were taken to hospital.', 'info')
                    else
                        bleeding = false
                    end
                end)
            end
        elseif downed then
            -- Revived by emergency services (or anything else that stands you up).
            clearState()
            ClearPedTasks(PlayerPedId())
        end
        Wait(wait)
    end
end)
