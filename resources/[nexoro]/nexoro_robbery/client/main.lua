local cfg = Config.Robbery
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function rob(t)
    CreateThread(function()
        local ok, info, minutes = NexoroCore.Callback('nexoro_robbery:check', { target = t.id })
        if not ok then
            if info == 'no_lockpick' then return notify('You need a lockpick.', 'error') end
            if info == 'cooldown' then return notify(('This place was robbed recently. Try again in %d minutes.'):format(minutes or 0), 'warning') end
            return notify('Not now: ' .. tostring(info), 'error')
        end
        if not NexoroUI.Progress({ label = 'Forcing ' .. (t.kind == 'atm' and 'the ATM' or 'the till'), duration = info.seconds * 1000,
            disable = { move = true, car = true, combat = true } }) then
            return notify('You stopped. Nothing was taken.', 'warning')
        end
        local done, r = NexoroCore.Callback('nexoro_robbery:complete', { target = t.id })
        if done then notify(('You took %s. The police have been alerted.'):format(r.taken), 'warning')
        else notify('It did not work: ' .. tostring(r), 'error') end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, t in ipairs(cfg.Targets) do
                if #(pos - vector3(t.x, t.y, t.z)) < t.radius then found = t; break end
            end
            local key = found and found.id or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.label .. ': force', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then local t = found; rob(t) end
            end
        end
        Wait(wait)
    end
end)
