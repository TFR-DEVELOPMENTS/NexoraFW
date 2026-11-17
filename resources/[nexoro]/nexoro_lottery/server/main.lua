local cfg = Config.Lottery
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroLottery = {}
local L = NexoroLottery
L.now = os.time
L.random = function(n) return math.random(1, n) end
L.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function atOffice(src)
    local p = L.getCoords(src)
    if not p then return false end
    local o = cfg.Office
    return math.sqrt((p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2) <= o.radius + 2.0
end

-- The draw that is taking tickets right now. Creates one if there is none.
function L.CurrentDraw()
    local open = NexoroDB.single("SELECT id, draw_at, carried_pence, pot_pence FROM nexoro_lottery_draws WHERE status = 'open' ORDER BY id DESC LIMIT 1")
    if open then return open end
    local lastCarry = NexoroDB.scalar("SELECT carried_pence FROM nexoro_lottery_draws WHERE status = 'drawn' ORDER BY id DESC LIMIT 1") or 0
    local id = NexoroDB.insert("INSERT INTO nexoro_lottery_draws (draw_at, carried_pence, pot_pence, status) VALUES (?,?,0,'open')",
        { L.now() + cfg.DrawIntervalSeconds, lastCarry })
    return NexoroDB.single('SELECT id, draw_at, carried_pence, pot_pence FROM nexoro_lottery_draws WHERE id = ?', { id })
end

-- Validates the six numbers a player chose: distinct, whole, and inside the pool.
local function parseNumbers(numbers)
    if type(numbers) ~= 'table' or #numbers ~= cfg.NumbersPerTicket then return nil end
    local seen, out = {}, {}
    for _, v in ipairs(numbers) do
        local n = math.tointeger(tonumber(v))
        if not n or n < 1 or n > cfg.PoolSize or seen[n] then return nil end
        seen[n] = true
        out[#out + 1] = n
    end
    table.sort(out)
    return out
end

function L.Buy(src, numbers)
    if not atOffice(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local chosen = parseNumbers(numbers)
    if not chosen then return false, 'invalid_numbers' end
    local draw = L.CurrentDraw()
    local mine = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_lottery_tickets WHERE draw_id = ? AND character_id = ?', { draw.id, c.id }) or 0
    if mine >= cfg.MaxTicketsPerDraw then return false, 'ticket_limit' end
    local price = core().ToPence(cfg.TicketPricePounds)
    local ok, why = exports.nexoro_gambling:Reserve(c.id, price)
    if not ok then return false, why end
    local took, tw = core().RemoveMoney(src, price / 100, 'bank', 'lottery ticket')
    if not took then exports.nexoro_gambling:Release(c.id, price); return false, tw end
    local text = table.concat(chosen, ',')
    NexoroDB.insert('INSERT INTO nexoro_lottery_tickets (draw_id, character_id, numbers, created_at) VALUES (?,?,?,?)', { draw.id, c.id, text, L.now() })
    NexoroDB.update('UPDATE nexoro_lottery_draws SET pot_pence = pot_pence + ? WHERE id = ?', { math.floor(price * cfg.PotShare + 0.5), draw.id })
    core().Log('lottery', 'ticket', src, { draw = draw.id })
    return true, { numbers = text, drawAt = draw.draw_at }
end

local function creditBank(characterId, pence, reason)
    if pence <= 0 then return end
    NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence + ? WHERE id = ?', { pence, characterId })
    local src = core().GetSourceByCharacterId(characterId)
    if src then core().ReloadBalances(src) end
    if src then core().Notify(src, ('%s: %s paid to your bank.'):format(reason, core().FormatGBP(pence)), 'banking', 10000) end
end

-- Draws the winning numbers, pays each tier that has winners, rolls the rest over, and opens the next draw.
function L.Draw(drawId)
    local draw = NexoroDB.single("SELECT id, carried_pence, pot_pence FROM nexoro_lottery_draws WHERE id = ? AND status = 'open'", { drawId })
    if not draw then return false, 'not_open' end
    local pool = {}
    for i = 1, cfg.PoolSize do pool[i] = i end
    local winning = {}
    for _ = 1, cfg.NumbersPerTicket do
        local k = L.random(#pool)
        winning[#winning + 1] = table.remove(pool, k)
    end
    table.sort(winning)
    local winSet = {}
    for _, n in ipairs(winning) do winSet[n] = true end
    local tickets = NexoroDB.query('SELECT id, character_id, numbers FROM nexoro_lottery_tickets WHERE draw_id = ?', { drawId }) or {}
    local byMatch = {}
    for _, t in ipairs(tickets) do
        local m = 0
        for n in t.numbers:gmatch('%d+') do if winSet[tonumber(n)] then m = m + 1 end end
        byMatch[m] = byMatch[m] or {}
        table.insert(byMatch[m], t)
    end
    local pot = draw.carried_pence + draw.pot_pence
    local paid = 0
    for _, tier in ipairs(cfg.Tiers) do
        local winners = byMatch[tier.match] or {}
        if #winners > 0 then
            local tierPot = math.floor(pot * tier.share)
            local each = math.floor(tierPot / #winners)
            for _, t in ipairs(winners) do
                creditBank(t.character_id, each, ('Lottery: %d numbers'):format(tier.match))
                paid = paid + each
            end
        end
    end
    local carry = pot - paid
    NexoroDB.update("UPDATE nexoro_lottery_draws SET status = 'drawn', numbers = ? WHERE id = ?", { table.concat(winning, ','), drawId })
    NexoroDB.insert("INSERT INTO nexoro_lottery_draws (draw_at, carried_pence, pot_pence, status) VALUES (?,?,0,'open')", { L.now() + cfg.DrawIntervalSeconds, carry })
    core().Log('lottery', 'drawn', 0, { draw = drawId, numbers = table.concat(winning, ','), paid = paid, carried = carry })
    return true, { numbers = winning, paid = paid, carried = carry }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_lottery:buy', function(src, p) return L.Buy(src, arg(p, 'numbers')) end, 20)
    cb('nexoro_lottery:current', function()
        local d = L.CurrentDraw()
        return true, { drawAt = d.draw_at, pot = core().FormatGBP(d.carried_pence + d.pot_pence) }
    end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(300000)
        local due = NexoroDB.query("SELECT id FROM nexoro_lottery_draws WHERE status = 'open' AND draw_at <= ?", { L.now() }) or {}
        for _, d in ipairs(due) do L.Draw(d.id) end
    end
end)

exports('Buy', L.Buy)
exports('Draw', L.Draw)
