local cfg = Config.Pawn
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroPawn = {}
local P = NexoroPawn
P.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function atShop(src)
    local p = P.getCoords(src)
    if not p then return false end
    local s = cfg.Shop
    return math.sqrt((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) <= s.radius + 2.0
end

function P.Sell(src, item, amount)
    if not atShop(src) then return false, 'too_far' end
    local price = cfg.Prices[item]
    if not price then return false, 'not_accepted' end
    local n = math.tointeger(tonumber(amount))
    if not n or n < 1 or n > cfg.MaxPerSale then return false, 'invalid_amount' end
    if (exports.nexoro_inventory:GetItemCount(src, item) or 0) < n then return false, 'not_enough' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, why end
    local pence = core().ToPence(price) * n
    local ok, err = core().AddMoney(src, pence / 100, 'cash', 'pawn: ' .. item)
    if not ok then exports.nexoro_inventory:AddItem(src, item, n); return false, err end
    core().Log('pawn', 'sold', src, { item = item, amount = n, pence = pence })
    return true, { received = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    core().RegisterCallback('nexoro_pawn:sell', function(src, p)
        if type(p) ~= 'table' then return false, 'invalid_request' end
        return P.Sell(src, p.item, p.amount)
    end, { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Sell', P.Sell)
