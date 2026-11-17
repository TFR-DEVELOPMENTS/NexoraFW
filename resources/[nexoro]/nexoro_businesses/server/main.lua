local cfg = Config.Businesses
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroBusinesses = {}
local B = NexoroBusinesses
B.now = os.time

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function cleanName(s)
    if type(s) ~= 'string' then return nil end
    s = (s:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', ''))
    local len = utf8.len(s)
    if not len or len < cfg.NameMin or len > cfg.NameMax then return nil end
    return s
end

local function business(id)
    return NexoroDB.single('SELECT id, name, owner_id, bank_pence FROM nexoro_businesses WHERE id = ?', { id })
end

-- Returns the business if the caller owns it, otherwise nil and a reason.
local function ownedBy(src, bizId)
    local id = toInt(bizId)
    if not id then return nil, 'invalid_request' end
    local c = core().GetCharacter(src)
    if not c then return nil, 'no_character' end
    local row = business(id)
    if not row then return nil, 'not_found' end
    if row.owner_id ~= c.id then return nil, 'not_owner' end
    return row
end

function B.Create(src, name)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local text = cleanName(name)
    if not text then return false, 'invalid_name' end
    local owned = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_businesses WHERE owner_id = ?', { c.id }) or 0
    if owned >= cfg.MaxPerOwner then return false, 'business_limit' end
    local ok, why = core().RemoveMoney(src, cfg.RegistrationFeePounds, 'bank', 'business registration')
    if not ok then return false, why end
    local id = NexoroDB.insert('INSERT INTO nexoro_businesses (name, owner_id) VALUES (?,?)', { text, c.id })
    if not id then
        core().AddMoney(src, cfg.RegistrationFeePounds, 'bank', 'refund: registration failed')
        return false, 'database_error'
    end
    core().Log('businesses', 'registered', src, { id = id, name = text })
    return true, { id = id, name = text }
end

function B.Deposit(src, bizId, amount)
    local row, why = ownedBy(src, bizId)
    if not row then return false, why end
    local pence = core().ToPence(tonumber(amount))
    if not pence or pence <= 0 then return false, 'invalid_amount' end
    local ok, err = core().RemoveMoney(src, pence / 100, 'bank', 'business deposit: ' .. row.name)
    if not ok then return false, err end
    NexoroDB.update('UPDATE nexoro_businesses SET bank_pence = bank_pence + ? WHERE id = ?', { pence, row.id })
    return true, { balance = core().FormatGBP((row.bank_pence or 0) + pence) }
end

function B.Withdraw(src, bizId, amount)
    local row, why = ownedBy(src, bizId)
    if not row then return false, why end
    local pence = core().ToPence(tonumber(amount))
    if not pence or pence <= 0 then return false, 'invalid_amount' end
    local affected = NexoroDB.update('UPDATE nexoro_businesses SET bank_pence = bank_pence - ? WHERE id = ? AND bank_pence >= ?', { pence, row.id, pence })
    if affected ~= 1 then return false, 'insufficient_funds' end
    core().AddMoney(src, pence / 100, 'bank', 'business withdrawal: ' .. row.name)
    return true
end

function B.Hire(src, bizId, target, wage)
    local row, why = ownedBy(src, bizId)
    if not row then return false, why end
    local t = toInt(target)
    local tc = t and core().GetCharacter(t)
    if not tc then return false, 'target_not_found' end
    if tc.id == row.owner_id then return false, 'cannot_target_self' end
    local pence = core().ToPence(tonumber(wage))
    if not pence or pence <= 0 or pence > core().ToPence(cfg.MaxWagePounds) then return false, 'invalid_wage' end
    if NexoroDB.scalar('SELECT 1 FROM nexoro_business_staff WHERE business_id = ? AND character_id = ?', { row.id, tc.id }) then return false, 'already_staff' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_business_staff WHERE business_id = ?', { row.id }) or 0
    if count >= cfg.MaxStaff then return false, 'staff_limit' end
    NexoroDB.update('INSERT INTO nexoro_business_staff (business_id, character_id, wage_pence, last_paid_at) VALUES (?,?,?,?)', { row.id, tc.id, pence, B.now() })
    core().Notify(t, ('You have been hired by %s at %s an hour.'):format(row.name, core().FormatGBP(pence)), 'job')
    return true
end

function B.Fire(src, bizId, characterId)
    local row, why = ownedBy(src, bizId)
    if not row then return false, why end
    local cid = toInt(characterId)
    if not cid then return false, 'invalid_request' end
    local affected = NexoroDB.update('DELETE FROM nexoro_business_staff WHERE business_id = ? AND character_id = ?', { row.id, cid })
    if affected ~= 1 then return false, 'not_staff' end
    local online = core().GetSourceByCharacterId(cid)
    if online then core().Notify(online, ('You have left %s.'):format(row.name), 'job') end
    return true
end

function B.Quit(src, bizId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local id = toInt(bizId)
    local affected = NexoroDB.update('DELETE FROM nexoro_business_staff WHERE business_id = ? AND character_id = ?', { id or -1, c.id })
    if affected ~= 1 then return false, 'not_staff' end
    return true
end

-- Pays every employee whose wage is due, from their business account. An empty account pays nobody.
function B.PayWages()
    local now = B.now()
    local due = NexoroDB.query('SELECT s.business_id, s.character_id, s.wage_pence, b.bank_pence, b.name FROM nexoro_business_staff s JOIN nexoro_businesses b ON b.id = s.business_id WHERE s.last_paid_at + ? <= ?',
        { cfg.WageIntervalSeconds, now }) or {}
    local paid, unpaid = 0, 0
    for _, r in ipairs(due) do
        local taken = NexoroDB.update('UPDATE nexoro_businesses SET bank_pence = bank_pence - ? WHERE id = ? AND bank_pence >= ?', { r.wage_pence, r.business_id, r.wage_pence })
        if taken == 1 then
            NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence + ? WHERE id = ?', { r.wage_pence, r.character_id })
            NexoroDB.update('UPDATE nexoro_business_staff SET last_paid_at = ? WHERE business_id = ? AND character_id = ?', { now, r.business_id, r.character_id })
            local src = core().GetSourceByCharacterId(r.character_id)
            if src then
                core().ReloadBalances(src)
                core().Notify(src, ('Wages from %s: %s.'):format(r.name, core().FormatGBP(r.wage_pence)), 'banking')
            end
            paid = paid + 1
        else
            unpaid = unpaid + 1
        end
    end
    return { paid = paid, unpaid = unpaid }
end

function B.Mine(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local owned = NexoroDB.query('SELECT id, name, bank_pence FROM nexoro_businesses WHERE owner_id = ? ORDER BY id', { c.id }) or {}
    for _, b in ipairs(owned) do
        b.balance = core().FormatGBP(b.bank_pence)
        b.bank_pence = nil
        b.staff = NexoroDB.query('SELECT s.character_id AS id, ch.first_name, ch.last_name, s.wage_pence FROM nexoro_business_staff s JOIN nexoro_characters ch ON ch.id = s.character_id WHERE s.business_id = ?', { b.id }) or {}
        for _, st in ipairs(b.staff) do st.name = st.first_name .. ' ' .. st.last_name; st.wage = core().FormatGBP(st.wage_pence); st.wage_pence = nil end
    end
    local working = NexoroDB.query('SELECT b.id, b.name FROM nexoro_business_staff s JOIN nexoro_businesses b ON b.id = s.business_id WHERE s.character_id = ?', { c.id }) or {}
    return true, { owned = owned, working = working }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_businesses:create', function(src, p) return B.Create(src, arg(p, 'name')) end, 5)
    cb('nexoro_businesses:deposit', function(src, p) return B.Deposit(src, arg(p, 'id'), arg(p, 'amount')) end, 10)
    cb('nexoro_businesses:withdraw', function(src, p) return B.Withdraw(src, arg(p, 'id'), arg(p, 'amount')) end, 10)
    cb('nexoro_businesses:hire', function(src, p) return B.Hire(src, arg(p, 'id'), arg(p, 'target'), arg(p, 'wage')) end, 10)
    cb('nexoro_businesses:fire', function(src, p) return B.Fire(src, arg(p, 'id'), arg(p, 'characterId')) end, 10)
    cb('nexoro_businesses:quit', function(src, p) return B.Quit(src, arg(p, 'id')) end, 10)
    cb('nexoro_businesses:mine', function(src) return B.Mine(src) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(cfg.WageIntervalSeconds * 1000 / 4)
        B.PayWages()
    end
end)

exports('Create', B.Create)
exports('PayWages', B.PayWages)
