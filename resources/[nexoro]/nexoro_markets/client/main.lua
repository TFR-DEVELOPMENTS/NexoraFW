local cfg = Config.Markets
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function contactMenu(id)
    CreateThread(function()
        local m = cfg[id]
        local options = {}
        for item, price in pairs(m.Buys) do
            options[#options + 1] = { title = 'Sell ' .. item, description = ('Pays up to £%.2f each, less than the street price.'):format(price * m.Share), icon = '£',
                onSelect = function()
                    CreateThread(function()
                        local ok, r = NexoroCore.Callback('nexoro_markets:sell', { market = id, item = item, amount = 1 })
                        if ok then notify('Deal done: ' .. r.received .. '.', 'warning') else notify('Deal refused: ' .. tostring(r), 'error') end
                    end)
                end }
        end
        for item, price in pairs(m.Sells) do
            options[#options + 1] = { title = 'Buy ' .. item, description = ('£%.2f each.'):format(price), icon = '$',
                onSelect = function()
                    CreateThread(function()
                        local ok, r = NexoroCore.Callback('nexoro_markets:buy', { market = id, item = item, amount = 1 })
                        if ok then notify('Bought for ' .. r.paid .. '.', 'warning') else notify('Purchase refused: ' .. tostring(r), 'error') end
                    end)
                end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_market_' .. id, title = m.label, options = options })
        NexoroUI.ShowContext('nexoro_market_' .. id)
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for id, m in pairs(cfg) do
                if #(pos - vector3(m.x, m.y, m.z)) < m.radius then found = id; break end
            end
            if found ~= inside then
                inside = found
                if found then exports.nexoro_ui:ShowTextUI(cfg[found].label .. ': E', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then local id = found; CreateThread(function() contactMenu(id) end) end
            end
        end
        Wait(wait)
    end
end)
