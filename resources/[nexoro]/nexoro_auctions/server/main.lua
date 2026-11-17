local cfg = Config.Auctions
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroAuctions = {}
local A = NexoroAuctions
A.now = os.time
A.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function atHouse(src)
    local p = A.getCoords(src)
    if not p then return false end
    local h = cfg.House
    return math.sqrt((p.x - h.x) ^ 2 + (p.y - h.y) ^ 2 + (p.z - h.z) ^ 2) <= h.radius + 2.0
end

local function row(id)
    return NexoroDB.single('SELECT id, seller_id, item, amount, start_pence, current_pence, bidder_id, ends_at, status FROM nexoro_auctions WHERE id = ?', { id })
end

local function minIncrement(currentPence)
    local pct = math.floor(currentPence * cfg.MinIncreasePercent / 100 + 0.5)
    return math.max(core().ToPence(cfg.MinIncreasePounds), pct)
end

-- Puts an item up for sale. The item is held by the auction house until it sells or is claimed.
function A.Create(src, item, amount, startPounds, minutes)
    if not atHouse(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local n = toInt(amount)
    if not n or n < 1 or n > 1000 then return false, 'invalid_amount' end
    local start = core().ToPence(tonumber(startPounds))
    if not start or start <= 0 then return false, 'invalid_price' end
    local m = toInt(minutes)
    if not m or m < cfg.MinMinutes or m > cfg.MaxMinutes then return false, 'invalid_duration' end
    local active = NexoroDB.scalar("SELECT COUNT(*) FROM nexoro_auctions WHERE seller_id = ? AND status = 'active'", { c.id }) or 0
    if active >= cfg.MaxListingsPerSeller then return false, 'listing_limit' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, why end
    local id = NexoroDB.insert(
        'INSERT INTO nexoro_auctions (seller_id, item, amount, start_pence, current_pence, ends_at) VALUES (?,?,?,?,?,?)',
        { c.id, item, n, start, start, A.now() + m * 60 })
    if not id then
        exports.nexoro_inventory:AddItem(src, item, n)
        return false, 'database_error'
    end
    core().Log('auctions', 'listed', src, { id = id, item = item, amount = n })
    return true, { id = id }
end

-- Places a bid. The bid is taken from the bidder now; the previous bidder is refunded at once.
function A.Bid(src, id, pounds)
    if not atHouse(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local r = row(toInt(id) or -1)
    if not r or r.status ~= 'active' then return false, 'not_active' end
    if r.ends_at <= A.now() then return false, 'ended' end
    if r.seller_id == c.id then return false, 'own_listing' end
    local bid = core().ToPence(tonumber(pounds))
    if not bid then return false, 'invalid_price' end
    local minBid = (r.bidder_id == nil) and r.start_pence or (r.current_pence + minIncrement(r.current_pence))
    if bid < minBid then return false, 'bid_too_low' end
    local ok = core().RemoveMoney(src, bid / 100, 'bank', 'auction bid #' .. r.id)
    if not ok then return false, 'insufficient_funds' end
    local affected = NexoroDB.update(
        "UPDATE nexoro_auctions SET current_pence = ?, bidder_id = ? WHERE id = ? AND status = 'active' AND current_pence = ?",
        { bid, c.id, r.id, r.current_pence })
    if affected ~= 1 then
        core().AddMoney(src, bid / 100, 'bank', 'refund: bid raced')
        return false, 'bid_raced'
    end
    if r.bidder_id then
        local prevSrc = core().GetSourceByCharacterId(r.bidder_id)
        NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence + ? WHERE id = ?', { r.current_pence, r.bidder_id })
        if prevSrc then
            core().ReloadBalances(prevSrc)
            core().Notify(prevSrc, ('You were outbid on auction #%d. Your %s is refunded.'):format(r.id, core().FormatGBP(r.current_pence)), 'warning')
        end
    end
    return true, { current = core().FormatGBP(bid) }
end

-- Settles auctions whose time is up: the seller is paid less the fee, and the winner can claim the item.
function A.Settle()
    local now = A.now()
    local ended = NexoroDB.query("SELECT id, seller_id, bidder_id, current_pence FROM nexoro_auctions WHERE status = 'active' AND ends_at <= ?", { now }) or {}
    local sold, unsold = 0, 0
    for _, r in ipairs(ended) do
        if r.bidder_id then
            local fee = math.floor(r.current_pence * cfg.FeePercent / 100 + 0.5)
            NexoroDB.update("UPDATE nexoro_auctions SET status = 'sold' WHERE id = ? AND status = 'active'", { r.id })
            NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence + ? WHERE id = ?', { r.current_pence - fee, r.seller_id })
            local s = core().GetSourceByCharacterId(r.seller_id)
            if s then core().ReloadBalances(s); core().Notify(s, ('Your auction #%d sold for %s.'):format(r.id, core().FormatGBP(r.current_pence)), 'banking') end
            sold = sold + 1
        else
            NexoroDB.update("UPDATE nexoro_auctions SET status = 'unsold' WHERE id = ? AND status = 'active'", { r.id })
            unsold = unsold + 1
        end
    end
    return { sold = sold, unsold = unsold }
end

-- The winner of a sale, or the seller of an unsold item, collects the item.
function A.Claim(src, id)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local r = row(toInt(id) or -1)
    if not r then return false, 'not_found' end
    local claimant
    if r.status == 'sold' and r.bidder_id == c.id then claimant = 'sold'
    elseif r.status == 'unsold' and r.seller_id == c.id then claimant = 'unsold'
    else return false, 'not_yours' end
    local given, why = exports.nexoro_inventory:AddItem(src, r.item, r.amount)
    if not given then return false, why end
    NexoroDB.update("UPDATE nexoro_auctions SET status = 'claimed' WHERE id = ? AND status = ?", { r.id, claimant })
    return true, { item = r.item, amount = r.amount }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_auctions:create', function(src, p) return A.Create(src, arg(p, 'item'), arg(p, 'amount'), arg(p, 'price'), arg(p, 'minutes')) end, 10)
    cb('nexoro_auctions:bid', function(src, p) return A.Bid(src, arg(p, 'id'), arg(p, 'price')) end, 20)
    cb('nexoro_auctions:claim', function(src, p) return A.Claim(src, arg(p, 'id')) end, 20)
    cb('nexoro_auctions:list', function()
        return true, NexoroDB.query("SELECT id, item, amount, current_pence, ends_at FROM nexoro_auctions WHERE status = 'active' ORDER BY ends_at LIMIT 50") or {}
    end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(cfg.SettleSeconds * 1000)
        A.Settle()
    end
end)

exports('Create', A.Create)
exports('Bid', A.Bid)
exports('Settle', A.Settle)
