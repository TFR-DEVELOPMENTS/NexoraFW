local cfg = Config.Banking
local Core

local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

local CAP = math.floor(cfg.MaxBalancePounds * 100 + 0.5)
local MAX_SINGLE = math.floor(cfg.MaxSingleTransactionPounds * 100 + 0.5)

local function validate(src, amount)
    local c = core().GetCharacter(src)
    if not c then return nil, 'no_character' end
    local pence = core().ToPence(amount)
    if not pence or pence <= 0 then return nil, 'invalid_amount' end
    if pence > MAX_SINGLE then return nil, 'amount_too_large' end
    return c, pence
end

local function record(c, kind, delta, counterparty, note)
    local balance = NexoroDB.scalar('SELECT bank_pence FROM nexoro_characters WHERE id = ?', { c.id }) or 0
    NexoroDB.insert(
        'INSERT INTO nexoro_transactions (character_id, citizen_id, type, delta_pence, balance_after_pence, counterparty, note) VALUES (?,?,?,?,?,?,?)',
        { c.id, c.citizenId, kind, delta, balance, counterparty or '', (note or ''):sub(1, 100) })
end

local function account(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    return true, {
        cash = c.cash / 100, bank = c.bank / 100,
        cashText = core().FormatGBP(c.cash), bankText = core().FormatGBP(c.bank),
        name = c.firstName .. ' ' .. c.lastName, citizenId = c.citizenId,
    }
end

-- Moves cash -> bank in ONE atomic statement; the WHERE clause is the balance check.
local function deposit(src, amount)
    local c, pence = validate(src, amount)
    if not c then return false, pence end
    local affected = NexoroDB.update(
        'UPDATE nexoro_characters SET cash_pence = cash_pence - ?, bank_pence = bank_pence + ? WHERE id = ? AND cash_pence >= ? AND bank_pence + ? <= ?',
        { pence, pence, c.id, pence, pence, CAP })
    if affected ~= 1 then return false, c.cash < pence and 'insufficient_funds' or 'balance_limit' end
    core().ReloadBalances(src)
    record(c, 'deposit', pence, nil, 'Cash deposit')
    core().Log('banking', 'deposit', src, { pence = pence })
    return account(src)
end

local function withdraw(src, amount)
    local c, pence = validate(src, amount)
    if not c then return false, pence end
    local affected = NexoroDB.update(
        'UPDATE nexoro_characters SET bank_pence = bank_pence - ?, cash_pence = cash_pence + ? WHERE id = ? AND bank_pence >= ? AND cash_pence + ? <= ?',
        { pence, pence, c.id, pence, pence, CAP })
    if affected ~= 1 then return false, c.bank < pence and 'insufficient_funds' or 'balance_limit' end
    core().ReloadBalances(src)
    record(c, 'withdrawal', -pence, nil, 'Cash withdrawal')
    core().Log('banking', 'withdraw', src, { pence = pence })
    return account(src)
end

-- Bank-to-bank transfer by citizen ID. One statement updates both rows or neither (works for offline recipients).
local function transfer(src, citizenId, amount, note)
    local c, pence = validate(src, amount)
    if not c then return false, pence end
    if not exports.nexoro_identity:IsValidCitizenId(citizenId) then return false, 'invalid_recipient' end
    if citizenId == c.citizenId then return false, 'cannot_pay_yourself' end
    local target = NexoroDB.single('SELECT id, first_name, last_name FROM nexoro_characters WHERE citizen_id = ?', { citizenId })
    if not target then return false, 'recipient_not_found' end

    local affected = NexoroDB.update(
        'UPDATE nexoro_characters a JOIN nexoro_characters b ON b.id = ? SET a.bank_pence = a.bank_pence - ?, b.bank_pence = b.bank_pence + ? ' ..
        'WHERE a.id = ? AND a.bank_pence >= ? AND b.bank_pence + ? <= ?',
        { target.id, pence, pence, c.id, pence, pence, CAP })
    if affected ~= 2 then return false, c.bank < pence and 'insufficient_funds' or 'transfer_failed' end

    core().ReloadBalances(src)
    local targetSrc = core().GetSourceByCitizenId(citizenId)
    if targetSrc then
        core().ReloadBalances(targetSrc)
        core().Notify(targetSrc, ('You received %s from %s.'):format(core().FormatGBP(pence), c.firstName .. ' ' .. c.lastName), 'banking')
    end
    note = type(note) == 'string' and note:gsub('[%c]', ''):sub(1, 100) or ''
    record(c, 'transfer_out', -pence, target.first_name .. ' ' .. target.last_name, note)
    NexoroDB.insert(
        'INSERT INTO nexoro_transactions (character_id, citizen_id, type, delta_pence, balance_after_pence, counterparty, note) VALUES (?,?,?,?,?,?,?)',
        { target.id, citizenId, 'transfer_in', pence, NexoroDB.scalar('SELECT bank_pence FROM nexoro_characters WHERE id = ?', { target.id }) or 0, c.firstName .. ' ' .. c.lastName, note })
    core().Log('banking', 'transfer', src, { pence = pence, to = citizenId })
    return account(src)
end

local function statement(src, payload)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local page = math.max(0, math.tointeger(tonumber(type(payload) == 'table' and payload.page or 0) or 0) or 0)
    local rows = NexoroDB.query(
        "SELECT type, delta_pence, balance_after_pence, counterparty, note, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date " ..
        'FROM nexoro_transactions WHERE character_id = ? ORDER BY id DESC LIMIT ? OFFSET ?',
        { c.id, cfg.StatementPageSize, page * cfg.StatementPageSize }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            type = r.type, amount = core().FormatGBP(r.delta_pence), delta = r.delta_pence / 100,
            balance = core().FormatGBP(r.balance_after_pence), counterparty = r.counterparty, note = r.note, date = r.date,
        }
    end
    return true, out
end

-- Pays the salary of the player's job grade into their bank account.
local function paySalary(src)
    local job = core().GetJob(src)
    local c = core().GetCharacter(src)
    if not job or not c or job.salary <= 0 then return false, 'no_salary' end
    if job.category ~= 'civilian' and not job.onDuty then return false, 'off_duty' end
    local ok = core().AddMoney(src, job.salary, 'bank', 'salary')
    if not ok then return false, 'payment_failed' end
    record(c, 'salary', math.floor(job.salary * 100 + 0.5), job.label, 'Salary')
    core().Notify(src, ('Salary received: %s'):format(core().FormatGBP(math.floor(job.salary * 100 + 0.5))), 'banking')
    return true
end

local function register()
    Core = nil
    local C = core()
    C.RegisterCallback('nexoro_banking:account', function(src) return account(src) end, { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
    C.RegisterCallback('nexoro_banking:deposit', function(src, p) return deposit(src, type(p) == 'table' and p.amount or nil) end, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
    C.RegisterCallback('nexoro_banking:withdraw', function(src, p) return withdraw(src, type(p) == 'table' and p.amount or nil) end, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
    C.RegisterCallback('nexoro_banking:transfer', function(src, p)
        if type(p) ~= 'table' then return false, 'invalid_request' end
        return transfer(src, p.citizenId, p.amount, p.note)
    end, { requireCharacter = true, rateLimit = { max = 5, windowMs = 10000 } })
    C.RegisterCallback('nexoro_banking:statement', statement, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(cfg.SalaryIntervalMinutes * 60 * 1000)
        for _, p in ipairs(core().GetPlayers()) do
            if p.hasCharacter then paySalary(p.source) end
            Wait(100)
        end
    end
end)

exports('Deposit', deposit)
exports('Withdraw', withdraw)
exports('Transfer', transfer)
exports('PaySalary', paySalary)
exports('GetAccount', account)
