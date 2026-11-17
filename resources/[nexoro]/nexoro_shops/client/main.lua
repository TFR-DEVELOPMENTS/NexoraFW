local cfg = Config.Shops
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local ERR = { out_of_stock = 'That item is out of stock. Come back later.', insufficient_funds = 'You cannot afford that.', not_enough = 'You do not have that many.',
    no_space = 'Your inventory is full.', too_far = 'Move closer to the counter.', not_bought_here = 'This shop does not buy that.', invalid_amount = 'Enter a valid amount.' }

local function buy(shopId, row)
    CreateThread(function()
        local v = NexoroUI.Input({ title = ('Buy %s - %s each'):format(row.label, row.price), submitLabel = 'Buy', fields = {
            { type = 'number', name = 'amount', label = 'How many (stock: ' .. row.stock .. ')', default = 1, min = 1, max = 50, required = true },
            { type = 'select', name = 'account', label = 'Pay with', options = { 'cash', 'bank' }, default = 'cash' } } })
        if not v then return end
        local ok, r = NexoroCore.Callback('nexoro_shops:buy', { shop = shopId, item = row.item, amount = v.amount, account = v.account })
        if ok then notify(('Bought %d for %s.'):format(r.amount, r.paid), 'success') else notify(ERR[r] or 'Purchase failed.', 'error') end
    end)
end

local function sell(shopId, row)
    CreateThread(function()
        local v = NexoroUI.Input({ title = ('Sell %s - %s each'):format(row.label, row.sellPrice), submitLabel = 'Sell', fields = {
            { type = 'number', name = 'amount', label = 'How many', default = 1, min = 1, max = 50, required = true } } })
        if not v then return end
        local ok, r = NexoroCore.Callback('nexoro_shops:sell', { shop = shopId, item = row.item, amount = v.amount })
        if ok then notify('Sold for ' .. r.received .. '.', 'banking') else notify(ERR[r] or 'Sale failed.', 'error') end
    end)
end

local function openShop(shopId)
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_shops:list', { shop = shopId })
        if not ok then return notify(ERR[data] or 'The shop is closed.', 'error') end
        local options = {}
        for _, row in ipairs(data.items) do
            local desc = ('%s · %d in stock'):format(row.price, row.stock)
            if row.sellPrice then desc = desc .. (' · we buy at %s'):format(row.sellPrice) end
            options[#options + 1] = { title = row.label, description = desc, icon = '▶', onSelect = function()
                NexoroUI.RegisterContext({ id = 'nexoro_shop_item_' .. shopId .. row.item, title = row.label, menu = 'nexoro_shop_' .. shopId, options = {
                    { title = 'Buy', description = 'Buy from the shop at ' .. row.price .. ' each.', icon = '£', onSelect = function() buy(shopId, row) end },
                    row.sellPrice and { title = 'Sell', description = 'Sell yours to the shop at ' .. row.sellPrice .. ' each.', icon = '⇄', onSelect = function() sell(shopId, row) end } or nil,
                } })
                NexoroUI.ShowContext('nexoro_shop_item_' .. shopId .. row.item)
            end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_shop_' .. shopId, title = data.shop, options = options,
            description = nil })
        NexoroUI.ShowContext('nexoro_shop_' .. shopId)
    end)
end

CreateThread(function()
    for _, def in pairs(cfg) do
        if def.label then
            local blip = AddBlipForCoord(def.x, def.y, def.z)
            SetBlipSprite(blip, 52); SetBlipColour(blip, 2); SetBlipScale(blip, 0.6); SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(def.label); EndTextCommandSetBlipName(blip)
        end
    end
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for id, def in pairs(cfg) do
                if def.label and #(pos - vector3(def.x, def.y, def.z)) < def.radius then found = id; break end
            end
            if found ~= inside then
                inside = found
                if found then exports.nexoro_ui:ShowTextUI(cfg[found].label .. ': shop', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then local id = inside; CreateThread(function() openShop(id) end) end
            end
        end
        Wait(wait)
    end
end)
