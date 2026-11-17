local cfg = Config.Shops
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroShops = {}
local S = NexoroShops
S.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
S.now = os.time

local stock = {}   -- [shopId][item] = { count, updated }

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function findShop(id)
    if type(id) ~= 'string' or not cfg[id] then return nil end
    cfg[id].id = id
    return cfg[id]
end
S.findShop = findShop

local function itemIn(shop, name)
    for _, it in ipairs(shop.items) do if it.item == name then return it end end
    return nil
end

local function near(src, shop)
    local p = S.getCoords(src)
    if not p then return false end
    return math.sqrt((p.x - shop.x) ^ 2 + (p.y - shop.y) ^ 2 + (p.z - shop.z) ^ 2) <= shop.radius + 2.0
end

-- Current stock, restocked for the time that has passed.
local function currentStock(shop, it)
    local now = S.now()
    stock[shop.id] = stock[shop.id] or {}
    local s = stock[shop.id][it.item]
    if not s then
        s = { count = it.stock, updated = now }
        stock[shop.id][it.item] = s
    end
    local cap = it.maxStock or it.stock
    local hours = (now - s.updated) / 3600
    if hours >= 1 and s.count < cap then
        local add = math.floor(hours * it.restockPerHour)
        if add > 0 then
            s.count = math.min(cap, s.count + add)
            s.updated = s.updated + math.floor(add * 3600 / it.restockPerHour)
        end
    end
    if s.count >= cap then s.updated = now end
    return s.count, s
end

function S.List(src, id)
    local shop = findShop(id)
    if not shop then return false, 'unknown_shop' end
    if not near(src, shop) then return false, 'too_far' end
    local out = {}
    for _, it in ipairs(shop.items) do
        local count = currentStock(shop, it)
        local def = exports.nexoro_inventory:GetItemDefinition(it.item) or {}
        out[#out + 1] = {
            item = it.item, label = def.label or it.item, price = core().FormatGBP(core().ToPence(it.price)),
            stock = count, sellPrice = it.buyPrice and core().FormatGBP(core().ToPence(it.buyPrice)) or nil,
        }
    end
    return true, { shop = shop.label, items = out }
end

function S.Buy(src, id, item, amount, acct)
    local shop = findShop(id)
    if not shop then return false, 'unknown_shop' end
    if not near(src, shop) then return false, 'too_far' end
    local it = itemIn(shop, item)
    if not it then return false, 'not_sold_here' end
    local n = toInt(amount)
    if not n or n < 1 or n > 50 then return false, 'invalid_amount' end
    local count, s = currentStock(shop, it)
    if count < n then return false, 'out_of_stock' end
    local total = core().ToPence(it.price) * n
    local account = acct == 'bank' and 'bank' or 'cash'
    local ok, why = core().RemoveMoney(src, total / 100, account, 'shop: ' .. item)
    if not ok then return false, why end
    local added, awhy = exports.nexoro_inventory:AddItem(src, item, n)
    if not added then
        core().AddMoney(src, total / 100, account, 'refund: shop full')
        return false, awhy
    end
    s.count = count - n
    core().Log('shops', 'buy', src, { shop = id, item = item, amount = n })
    return true, { paid = core().FormatGBP(total), item = item, amount = n }
end

function S.Sell(src, id, item, amount)
    local shop = findShop(id)
    if not shop then return false, 'unknown_shop' end
    if not near(src, shop) then return false, 'too_far' end
    local it = itemIn(shop, item)
    if not it or not it.buyPrice then return false, 'not_bought_here' end
    local n = toInt(amount)
    if not n or n < 1 or n > 50 then return false, 'invalid_amount' end
    local have = exports.nexoro_inventory:GetItemCount(src, item) or 0
    if have < n then return false, 'not_enough' end
    local removed, rwhy = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, rwhy end
    local pence = core().ToPence(it.buyPrice) * n
    local ok, why = core().AddMoney(src, pence / 100, 'cash', 'sold to shop: ' .. item)
    if not ok then
        exports.nexoro_inventory:AddItem(src, item, n)
        return false, why
    end
    local count, s = currentStock(shop, it)
    s.count = math.min(it.maxStock or it.stock, count + n)
    core().Log('shops', 'sell', src, { shop = id, item = item, amount = n })
    return true, { received = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_shops:list', function(src, p) return S.List(src, arg(p, 'shop')) end)
    cb('nexoro_shops:buy', function(src, p) return S.Buy(src, arg(p, 'shop'), arg(p, 'item'), arg(p, 'amount'), arg(p, 'account')) end, 20)
    cb('nexoro_shops:sell', function(src, p) return S.Sell(src, arg(p, 'shop'), arg(p, 'item'), arg(p, 'amount')) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('List', S.List)
exports('Buy', S.Buy)
exports('Sell', S.Sell)
