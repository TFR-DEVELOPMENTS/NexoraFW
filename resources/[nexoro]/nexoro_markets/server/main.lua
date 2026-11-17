local cfg = Config.Markets
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroMarkets = {}
local M = NexoroMarkets
M.now = os.time
M.random = function(lo, hi) return math.random(lo, hi) end
M.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local dayTotals = {}   -- [characterId] = { day, pence }

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function alarm(description, pos)
    TriggerEvent('nexoro:server:alarm', { description = description, x = pos.x, y = pos.y, z = pos.z })
end
local function dayRecord(characterId)
    local day = M.now() // 86400
    local r = dayTotals[characterId]
    if not r or r.day ~= day then r = { day = day, pence = 0 }; dayTotals[characterId] = r end
    return r
end
local function nearMarket(src, market)
    local p = M.getCoords(src)
    return p ~= nil and distance(p, market) <= market.radius + 2.0
end

-- You sell to the contact. They pay Share of their price, up to the daily cap. Each deal may raise an alarm.
function M.SellTo(src, marketId, item, amount)
    local market = cfg[marketId]
    if not market then return false, 'unknown_market' end
    if not nearMarket(src, market) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local list = market.Buys[item]
    if not list then return false, 'not_wanted' end
    local n = math.tointeger(tonumber(amount)) or 0
    if n < 1 or n > 20 then return false, 'invalid_amount' end
    local pence = math.floor(core().ToPence(list) * market.Share + 0.5) * n
    local rec = dayRecord(c.id)
    if rec.pence + pence > core().ToPence(market.DailyCapPounds) then return false, 'daily_cap' end
    if (exports.nexoro_inventory:GetItemCount(src, item) or 0) < n then return false, 'not_enough' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, why end
    core().AddMoney(src, pence / 100, 'cash', 'street deal')
    rec.pence = rec.pence + pence
    if M.random(1, 100) <= market.AlarmChance then alarm(('Suspicious deal reported: %s'):format(market.label), M.getCoords(src)) end
    core().Log('markets', 'sold', src, { market = marketId, item = item, amount = n })
    return true, { received = core().FormatGBP(pence) }
end

-- You buy from the contact at their price.
function M.BuyFrom(src, marketId, item, amount)
    local market = cfg[marketId]
    if not market then return false, 'unknown_market' end
    if not nearMarket(src, market) then return false, 'too_far' end
    local price = market.Sells[item]
    if not price then return false, 'not_for_sale' end
    local n = math.tointeger(tonumber(amount)) or 0
    if n < 1 or n > 5 then return false, 'invalid_amount' end
    local pence = core().ToPence(price) * n
    local ok, why = core().RemoveMoney(src, pence / 100, 'cash', 'street purchase')
    if not ok then return false, why end
    local added, awhy = exports.nexoro_inventory:AddItem(src, item, n)
    if not added then core().AddMoney(src, pence / 100, 'cash', 'refund'); return false, awhy end
    if M.random(1, 100) <= market.AlarmChance then alarm(('Suspicious purchase reported: %s'):format(market.label), M.getCoords(src)) end
    return true, { paid = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_markets:sell', function(src, p) return M.SellTo(src, arg(p, 'market'), arg(p, 'item'), arg(p, 'amount')) end, 10)
    cb('nexoro_markets:buy', function(src, p) return M.BuyFrom(src, arg(p, 'market'), arg(p, 'item'), arg(p, 'amount')) end, 10)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('SellTo', M.SellTo)
exports('BuyFrom', M.BuyFrom)
