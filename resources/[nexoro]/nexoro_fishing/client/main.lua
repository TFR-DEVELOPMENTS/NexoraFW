local cfg = Config.Fishing
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function cast(spot)
    CreateThread(function()
        if not NexoroUI.Progress({ label = 'Fishing', duration = 6000, disable = { move = true, car = true, combat = true } }) then return end
        local ok, r, extra = NexoroCore.Callback('nexoro_fishing:cast', { spot = spot.id })
        if ok then notify(('You caught: %s.'):format(r.label), 'success')
        elseif r == 'no_licence' then notify('You need a fishing licence from the council office.', 'error')
        elseif r == 'cooldown' then notify(('Wait a moment before casting again (%d s).'):format(math.ceil(extra or 0)), 'warning')
        else notify('Fishing: ' .. tostring(r), 'error') end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, s in ipairs(cfg.Spots) do
                if #(pos - vector3(s.x, s.y, s.z)) < s.radius then found = s; break end
            end
            local key = found and found.id or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.label .. ': fish', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then local s = found; CreateThread(function() cast(s) end) end
            end
        end
        Wait(wait)
    end
end)
