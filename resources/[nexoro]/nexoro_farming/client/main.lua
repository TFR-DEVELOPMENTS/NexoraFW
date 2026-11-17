local cfg = Config.Farming
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function work(plot)
    CreateThread(function()
        local ok, r, extra = NexoroCore.Callback('nexoro_farming:harvest', { plot = plot.id })
        if ok then return notify(('Harvested %d × %s.'):format(r.amount, r.crop), 'success') end
        if r == 'empty' then
            if not NexoroUI.Progress({ label = 'Planting wheat', duration = 4000, disable = { move = true, car = true, combat = true } }) then return end
            local okP, p = NexoroCore.Callback('nexoro_farming:plant', { plot = plot.id })
            if okP then notify(('Planted. Ready in %d minutes.'):format(cfg.GrowthMinutes), 'success')
            else notify(p == 'not_enough' and 'You need a wheat seed.' or ('Could not plant: ' .. tostring(p)), 'error') end
        elseif r == 'not_ready' then
            notify(('Not ready yet: about %d minutes to go.'):format(math.ceil((extra or 0) / 60)), 'info')
        else
            notify('This plot is not yours to harvest: ' .. tostring(r), 'error')
        end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, p in ipairs(cfg.Plots) do
                if #(pos - vector3(p.x, p.y, p.z)) < p.radius then found = p; break end
            end
            local key = found and found.id or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.label .. ': plant or harvest', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then local p = found; CreateThread(function() work(p) end) end
            end
        end
        Wait(wait)
    end
end)
