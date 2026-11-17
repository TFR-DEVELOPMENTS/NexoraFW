local cfg = Config.Courts
local inside = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function openFines()
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_courts:fines')
        if not ok then return notify('Could not load your fines.', 'error') end
        if #data.fines == 0 then return notify('You have no outstanding fines.', 'success') end
        local options = {}
        for _, f in ipairs(data.fines) do
            options[#options + 1] = { title = f.amount .. ' · ' .. f.detail, description = ('Issued %s by %s'):format(f.date, f.officer), icon = '£', onSelect = function()
                CreateThread(function()
                    if not NexoroUI.Confirm({ title = 'Pay this fine?', text = ('%s for: %s'):format(f.amount, f.detail), confirmLabel = 'Pay' }) then return end
                    local paid, r = NexoroCore.Callback('nexoro_courts:pay', { id = f.id, account = 'bank' })
                    if paid then notify('Fine paid: ' .. r.paid, 'banking') else notify('Payment failed: ' .. tostring(r), 'error') end
                end)
            end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_courts_fines', title = 'Outstanding fines · ' .. data.total, options = options })
        NexoroUI.ShowContext('nexoro_courts_fines')
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local o = cfg.Office
            local near = #(GetEntityCoords(PlayerPedId()) - vector3(o.x, o.y, o.z)) < o.radius
            if near ~= inside then
                inside = near
                if near then exports.nexoro_ui:ShowTextUI(o.label .. ': fines', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then CreateThread(openFines) end
            end
        end
        Wait(wait)
    end
end)

-- Phone and bank apps can also call nexoro_courts:pay with byPhone = true (see nexoro_phone).
RegisterCommand('fines', openFines, false)
