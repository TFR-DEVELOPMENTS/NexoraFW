local cfg = Config.Crafting
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function make(station, recipe)
    CreateThread(function()
        if not NexoroUI.Progress({ label = recipe.label, duration = recipe.time, disable = { move = true, car = true, combat = true } }) then return end
        local ok, r = NexoroCore.Callback('nexoro_crafting:craft', { station = station, recipe = recipe.id })
        if ok then notify(('Made %d × %s.'):format(r.amount, r.made), 'success')
        else notify(r == 'missing_ingredients' and 'You are missing ingredients.' or ('Could not craft: ' .. tostring(r)), 'error') end
    end)
end

local function openBench(stationId)
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_crafting:recipes', { station = stationId })
        if not ok then return notify('Could not reach the workbench.', 'error') end
        local options = {}
        for _, r in ipairs(data.recipes) do
            options[#options + 1] = { title = r.label, icon = '⚒', disabled = not r.canMake,
                description = r.canMake and ('Takes %d seconds'):format(math.floor(r.time / 1000)) or ('Missing: ' .. r.missing),
                onSelect = function() make(stationId, r) end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_bench_' .. stationId, title = data.station, options = options })
        NexoroUI.ShowContext('nexoro_bench_' .. stationId)
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, s in ipairs(cfg.Stations) do
                if #(pos - vector3(s.x, s.y, s.z)) < s.radius then found = s.id; break end
            end
            if found ~= inside then
                inside = found
                if found then exports.nexoro_ui:ShowTextUI('Workbench: craft', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then local id = inside; CreateThread(function() openBench(id) end) end
            end
        end
        Wait(wait)
    end
end)
