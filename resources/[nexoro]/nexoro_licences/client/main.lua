local cfg = Config.Licences
local inside = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function sitTest()
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_licences:applyDriving')
        if not ok then return notify('Could not start the test: ' .. tostring(data), 'error') end
        local answers = {}
        for i, q in ipairs(data.questions) do
            local opts = {}
            for n, o in ipairs(q.options) do opts[#opts + 1] = { value = n, label = o } end
            local v = NexoroUI.Input({ title = ('Question %d of %d'):format(i, #data.questions), fields = {
                { type = 'select', name = 'a', label = q.q, options = opts, required = true } } })
            if not v then return notify('Test cancelled. The fee is not refunded.', 'warning') end
            answers[i] = tonumber(v.a)
        end
        local okS, r = NexoroCore.Callback('nexoro_licences:submitDriving', { answers = answers })
        if not okS then return notify('Could not mark the test.', 'error') end
        if r.passed then notify(('You passed: %d of %d. Your licence is issued.'):format(r.score, r.of), 'success')
        else notify(('You scored %d of %d. You need %d to pass.'):format(r.score, r.of, cfg.Driving.passMark), 'error') end
    end)
end

local function office()
    CreateThread(function()
        local _, mine = NexoroCore.Callback('nexoro_licences:mine')
        local options = {
            { title = cfg.Driving.label, description = ('Written test, £%.2f. Pass mark %d of %d.'):format(cfg.Driving.feePounds, cfg.Driving.passMark, cfg.Driving.questionsPerTest),
              icon = '⛟', disabled = mine and mine.driving, onSelect = sitTest },
            { title = cfg.Fishing.label, description = ('Needed to fish. £%.2f.'):format(cfg.Fishing.feePounds), icon = '~', disabled = mine and mine.fishing,
              onSelect = function()
                  CreateThread(function()
                      local ok, r = NexoroCore.Callback('nexoro_licences:buyFishing')
                      if ok then notify('Fishing licence issued for ' .. r.fee .. '.', 'success') else notify('Could not buy the licence: ' .. tostring(r), 'error') end
                  end)
              end },
            { title = cfg.Hunting.label, description = ('Needed to hunt. £%.2f.'):format(cfg.Hunting.feePounds), icon = '^', disabled = mine and mine.hunting,
              onSelect = function()
                  CreateThread(function()
                      local ok, r = NexoroCore.Callback('nexoro_licences:buyHunting')
                      if ok then notify('Hunting licence issued for ' .. r.fee .. '.', 'success') else notify('Could not buy the licence: ' .. tostring(r), 'error') end
                  end)
              end },
            { title = cfg.Weapon.label, description = ('Needed to carry a firearm legally. £%.2f.'):format(cfg.Weapon.feePounds), icon = '!', disabled = mine and mine.weapon,
              onSelect = function()
                  CreateThread(function()
                      local ok, r = NexoroCore.Callback('nexoro_licences:buyWeapon')
                      if ok then notify('Firearms licence issued for ' .. r.fee .. '.', 'success') else notify('Could not buy the licence: ' .. tostring(r), 'error') end
                  end)
              end },
        }
        NexoroUI.RegisterContext({ id = 'nexoro_licensing_office', title = cfg.Office.label, options = options })
        NexoroUI.ShowContext('nexoro_licensing_office')
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local o = cfg.Office
            local near = #(GetEntityCoords(PlayerPedId()) - vector3(o.x, o.y, o.z)) < o.radius
            if near ~= inside then
                inside = near
                if near then exports.nexoro_ui:ShowTextUI(o.label .. ': licences', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then CreateThread(office) end
            end
        end
        Wait(wait)
    end
end)
