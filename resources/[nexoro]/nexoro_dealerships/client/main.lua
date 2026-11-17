local cfg = Config
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local ERR = { insufficient_funds = 'You cannot afford that.', deposit_too_small = 'The deposit must be at least 10% of the price.', deposit_covers_price = 'The deposit already covers the price: pay by bank instead.',
    too_far = 'Move closer to the dealership.', not_for_sale = 'That vehicle is not for sale.', not_stored = 'The vehicle must be in a garage.', finance_outstanding = 'Pay off the finance first.', rate_limited = 'Slow down a little.', invalid_amount = 'Enter a valid amount.' }
local function errText(e) return ERR[e] or 'That did not work.' end

local function buy(id, v)
    local values = NexoroUI.Input({ title = ('%s - %s'):format(v.label, v.priceText), submitLabel = 'Continue', fields = {
        { type = 'select', name = 'method', label = 'Payment', options = { { value = 'bank', label = 'Bank transfer (full price)' }, { value = 'cash', label = 'Cash (full price)' }, { value = 'finance', label = 'Finance (deposit + weekly payments)' } }, default = 'bank' },
        { type = 'number', name = 'deposit', label = 'Finance deposit (£, at least 10%)', min = 0, step = 1, default = math.ceil(v.price * 0.1) },
    } })
    if not values then return end
    local text = ('Buy %s for %s?'):format(v.label, v.priceText)
    if values.method == 'finance' then
        local ok, t = NexoroCore.Callback('nexoro_dealerships:terms', { id = id, model = v.model, deposit = values.deposit })
        if not ok then return notify(errText(t), 'error') end
        text = ('Deposit %s now, then %s per payment until %s is paid (includes interest).'):format(t.deposit, t.payment, t.remaining)
    end
    if not NexoroUI.Confirm({ title = 'Confirm purchase', text = text, confirmLabel = 'Buy' }) then return end
    local ok, r = NexoroCore.Callback('nexoro_dealerships:purchase', { id = id, model = v.model, method = values.method, deposit = values.deposit })
    if not ok then return notify(errText(r), 'error') end
    NexoroUI.Alert({ title = 'Purchase complete', text = ('You bought a %s.\nNumber plate: %s\nPaid: %s\nCollect it from your garage (%s).'):format(v.label, r.plate, r.paid, r.garage) })
end

local function openCatalogue(id)
    local ok, data = NexoroCore.Callback('nexoro_dealerships:catalogue', { id = id })
    if not ok then return notify(errText(data), 'error') end
    local categories, order = {}, {}
    for _, v in ipairs(data.vehicles) do
        if not categories[v.category] then categories[v.category] = {}; order[#order + 1] = v.category end
        local list = categories[v.category]
        list[#list + 1] = { title = v.label, description = v.priceText .. ' · you choose bank, cash or finance next', icon = '▶', onSelect = function() CreateThread(function() buy(id, v) end) end }
    end
    local options = {}
    for _, cat in ipairs(order) do
        local menuId = ('nexoro_dealer_%s_%s'):format(id, cat)
        NexoroUI.RegisterContext({ id = menuId, title = cat, menu = 'nexoro_dealer_' .. id, options = categories[cat] })
        options[#options + 1] = { title = cat, menu = menuId, icon = '▸' }
    end
    options[#options + 1] = { title = 'Sell a vehicle to the dealer', icon = '£', description = 'Sell a stored, paid-off vehicle back. The price falls with mileage.', onSelect = function()
        CreateThread(function()
            local okSell, list = NexoroCore.Callback('nexoro_dealerships:sellList', { id = id })
            if not okSell then return notify(errText(list), 'error') end
            local sellOptions = {}
            for _, s in ipairs(list) do
                sellOptions[#sellOptions + 1] = { title = ('%s [%s]'):format(s.model:upper(), s.plate), description = ('Offer %s · %.1f miles'):format(s.price, s.miles), onSelect = function()
                    CreateThread(function()
                        if not NexoroUI.Confirm({ title = 'Sell ' .. s.plate .. '?', text = 'The dealer offers ' .. s.price .. '.', confirmLabel = 'Sell' }) then return end
                        local done, r = NexoroCore.Callback('nexoro_dealerships:sell', { id = id, plate = s.plate })
                        if done then notify('Sold for ' .. r.price .. '.', 'banking') else notify(errText(r), 'error') end
                    end)
                end }
            end
            if #sellOptions == 0 then sellOptions[1] = { title = 'No vehicles to sell (they must be in a garage, paid off)', disabled = true } end
            NexoroUI.RegisterContext({ id = 'nexoro_dealer_sell_' .. id, title = 'Sell a vehicle', menu = 'nexoro_dealer_' .. id, options = sellOptions })
            NexoroUI.ShowContext('nexoro_dealer_sell_' .. id)
        end)
    end }
    NexoroUI.RegisterContext({ id = 'nexoro_dealer_' .. id, title = data.label, options = options })
    NexoroUI.ShowContext('nexoro_dealer_' .. id)
end

CreateThread(function()
    for _, def in pairs(cfg.Dealerships) do
        local blip = AddBlipForCoord(def.x, def.y, def.z)
        SetBlipSprite(blip, 225); SetBlipColour(blip, 3); SetBlipScale(blip, 0.8); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(def.label); EndTextCommandSetBlipName(blip)
    end
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        -- On foot only: driving past a dealership must never open the showroom.
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for id, def in pairs(cfg.Dealerships) do
                if #(pos - vector3(def.x, def.y, def.z)) < def.radius then found = id; break end
            end
            if found ~= inside then
                inside = found
                if found then exports.nexoro_ui:ShowTextUI(cfg.Dealerships[found].label, 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then local id = inside; CreateThread(function() openCatalogue(id) end) end
            end
        end
        Wait(wait)
    end
end)
