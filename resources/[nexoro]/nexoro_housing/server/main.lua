local cfg = Config.Housing
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroHousing = {}
local H = NexoroHousing
H.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
H.now = os.time

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function propertyDef(id)
    for _, p in ipairs(cfg.Properties) do if p.id == id then return p end end
    return nil
end
local function agentOf(id) return cfg.Agents[id] end

local function near(src, pos, radius)
    local p = H.getCoords(src)
    return p ~= nil and distance(p, pos) <= radius
end

local function row(id)
    return NexoroDB.single('SELECT id, label, price_pence, weekly_pence, owner_id, arrears, next_bill_at FROM nexoro_properties WHERE id = ?', { id })
end

local function hasAccess(c, r)
    if not c or not r then return false end
    if r.owner_id == c.id then return true end
    return NexoroDB.scalar('SELECT 1 FROM nexoro_property_keys WHERE property_id = ? AND character_id = ?', { r.id, c.id }) ~= nil
end

-- Makes sure every configured property exists in the database (safe to run every start).
function H.Seed()
    for _, p in ipairs(cfg.Properties) do
        NexoroDB.update('INSERT IGNORE INTO nexoro_properties (id, label, price_pence, weekly_pence, next_bill_at) VALUES (?,?,?,?,0)',
            { p.id, p.label, core().ToPence(p.price), core().ToPence(p.weekly) })
    end
end

function H.List(src, agentId)
    local agent = agentOf(agentId)
    if not agent then return false, 'unknown_agent' end
    if not near(src, agent, agent.radius + 2.0) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local out = {}
    for _, p in ipairs(cfg.Properties) do
        if p.agent == agentId then
            local r = row(p.id)
            local status = 'for sale'
            if r and r.owner_id == c.id then status = 'yours'
            elseif r and r.owner_id then status = 'sold' end
            out[#out + 1] = { id = p.id, label = p.label, status = status,
                price = core().FormatGBP(r and r.price_pence or core().ToPence(p.price)),
                weekly = core().FormatGBP(r and r.weekly_pence or core().ToPence(p.weekly)) }
        end
    end
    return true, { agent = agent.label, properties = out }
end

function H.Buy(src, id)
    local def = propertyDef(id)
    if not def then return false, 'unknown_property' end
    if not near(src, agentOf(def.agent), agentOf(def.agent).radius + 2.0) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local r = row(id)
    if not r then return false, 'unknown_property' end
    if r.owner_id then return false, 'already_owned' end
    local ok, why = core().RemoveMoney(src, r.price_pence / 100, 'bank', 'property: ' .. id)
    if not ok then return false, why end
    local affected = NexoroDB.update('UPDATE nexoro_properties SET owner_id = ?, arrears = 0, next_bill_at = ? WHERE id = ? AND owner_id IS NULL',
        { c.id, H.now() + cfg.BillIntervalSeconds, id })
    if affected ~= 1 then
        core().AddMoney(src, r.price_pence / 100, 'bank', 'refund: property taken')
        return false, 'already_owned'
    end
    core().Log('housing', 'bought', src, { property = id })
    return true, { property = def.label, paid = core().FormatGBP(r.price_pence) }
end

function H.SellBack(src, id)
    local def = propertyDef(id)
    if not def then return false, 'unknown_property' end
    if not near(src, agentOf(def.agent), agentOf(def.agent).radius + 2.0) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    local r = row(id)
    if not c or not r or r.owner_id ~= c.id then return false, 'not_owner' end
    if r.arrears > 0 then return false, 'arrears_outstanding' end
    local pence = math.floor(r.price_pence * cfg.SellBackRate + 0.5)
    local affected = NexoroDB.update('UPDATE nexoro_properties SET owner_id = NULL, arrears = 0 WHERE id = ? AND owner_id = ?', { id, c.id })
    if affected ~= 1 then return false, 'not_owner' end
    NexoroDB.update('DELETE FROM nexoro_property_keys WHERE property_id = ?', { id })
    core().AddMoney(src, pence / 100, 'bank', 'property sold back: ' .. id)
    core().Log('housing', 'sold_back', src, { property = id, pence = pence })
    return true, { received = core().FormatGBP(pence) }
end

function H.PayArrears(src, id)
    local c = core().GetCharacter(src)
    local r = row(id)
    if not c or not r or r.owner_id ~= c.id then return false, 'not_owner' end
    if r.arrears == 0 then return false, 'no_arrears' end
    local pence = r.weekly_pence * r.arrears
    local ok, why = core().RemoveMoney(src, pence / 100, 'bank', 'property arrears: ' .. id)
    if not ok then return false, why end
    NexoroDB.update('UPDATE nexoro_properties SET arrears = 0 WHERE id = ? AND owner_id = ?', { id, c.id })
    return true, { paid = core().FormatGBP(pence) }
end

-- Weekly bills. Paid from the bank if there is money; otherwise arrears build up.
-- Owners who are offline are charged the same way: the bank row is the source of truth.
function H.Bills()
    local now = H.now()
    local due = NexoroDB.query('SELECT id, owner_id, weekly_pence, arrears FROM nexoro_properties WHERE owner_id IS NOT NULL AND next_bill_at <= ?', { now }) or {}
    local paid, missed, repossessed = 0, 0, 0
    for _, r in ipairs(due) do
        local taken = NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence - ? WHERE id = ? AND bank_pence >= ?',
            { r.weekly_pence, r.owner_id, r.weekly_pence })
        local src = core().GetSourceByCharacterId(r.owner_id)
        if taken == 1 then
            NexoroDB.update('UPDATE nexoro_properties SET next_bill_at = next_bill_at + ? WHERE id = ?', { cfg.BillIntervalSeconds, r.id })
            if src then core().ReloadBalances(src) end
            paid = paid + 1
        else
            local arrears = r.arrears + 1
            if arrears >= cfg.MaxArrearsWeeks then
                NexoroDB.update('UPDATE nexoro_properties SET owner_id = NULL, arrears = 0, next_bill_at = 0 WHERE id = ?', { r.id })
                NexoroDB.update('DELETE FROM nexoro_property_keys WHERE property_id = ?', { r.id })
                repossessed = repossessed + 1
                core().Log('housing', 'repossessed', src or 0, { property = r.id })
                if src then core().Notify(src, ('%s has been repossessed for unpaid bills.'):format(r.id), 'error', 10000) end
            else
                NexoroDB.update('UPDATE nexoro_properties SET arrears = ?, next_bill_at = next_bill_at + ? WHERE id = ?', { arrears, cfg.BillIntervalSeconds, r.id })
                missed = missed + 1
                if src then core().Notify(src, ('A bill for %s could not be paid. Arrears: %d week(s).'):format(r.id, arrears), 'warning', 10000) end
            end
        end
    end
    return { paid = paid, missed = missed, repossessed = repossessed }
end

function H.Enter(src, id)
    local def = propertyDef(id)
    if not def then return false, 'unknown_property' end
    if not hasAccess(core().GetCharacter(src), row(id)) then return false, 'no_access' end
    if not near(src, def.entrance, 4.0) then return false, 'too_far' end
    TriggerClientEvent('nexoro_housing:enter', src, { interior = def.interior })
    return true
end

function H.Leave(src, id)
    local def = propertyDef(id)
    if not def then return false, 'unknown_property' end
    if not hasAccess(core().GetCharacter(src), row(id)) then return false, 'no_access' end
    if not near(src, def.interior, 6.0) then return false, 'not_inside' end
    TriggerClientEvent('nexoro_housing:leave', src, { entrance = def.entrance })
    return true
end

function H.GiveKey(src, id, target)
    local c = core().GetCharacter(src)
    local r = row(id)
    if not c or not r or r.owner_id ~= c.id then return false, 'not_owner' end
    local t = toInt(target)
    local tc = t and core().GetCharacter(t)
    if not tc then return false, 'target_not_found' end
    if tc.id == c.id then return false, 'cannot_target_self' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_property_keys WHERE property_id = ?', { id }) or 0
    if count >= cfg.MaxKeys then return false, 'key_limit' end
    NexoroDB.update('INSERT IGNORE INTO nexoro_property_keys (property_id, character_id) VALUES (?, ?)', { id, tc.id })
    core().Notify(t, ('You have been given a key to %s.'):format(r.label), 'info')
    return true
end

function H.RevokeKey(src, id, characterId)
    local c = core().GetCharacter(src)
    local r = row(id)
    if not c or not r or r.owner_id ~= c.id then return false, 'not_owner' end
    local cid = toInt(characterId)
    if not cid then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_property_keys WHERE property_id = ? AND character_id = ?', { id, cid })
    return true
end

function H.Deposit(src, id, item, amount)
    local r = row(id)
    if not r or not hasAccess(core().GetCharacter(src), r) then return false, 'no_access' end
    local n = toInt(amount)
    if not n or n < 1 or n > 1000 then return false, 'invalid_amount' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, why end
    local stored, swhy = exports.nexoro_inventory:AddItemToStash('property', id, item, n, nil, { slots = cfg.StashSlots, maxWeight = cfg.StashWeightGrams })
    if not stored then
        exports.nexoro_inventory:AddItem(src, item, n)
        return false, swhy or 'no_space'
    end
    return true
end

function H.Withdraw(src, id, item, amount)
    local r = row(id)
    if not r or not hasAccess(core().GetCharacter(src), r) then return false, 'no_access' end
    local n = toInt(amount)
    if not n or n < 1 or n > 1000 then return false, 'invalid_amount' end
    local taken, why = exports.nexoro_inventory:RemoveItemFromStash('property', id, item, n)
    if not taken then return false, why end
    local given, gwhy = exports.nexoro_inventory:AddItem(src, item, n)
    if not given then
        exports.nexoro_inventory:AddItemToStash('property', id, item, n, nil, { slots = cfg.StashSlots, maxWeight = cfg.StashWeightGrams })
        return false, gwhy
    end
    return true
end

function H.Stash(src, id)
    local r = row(id)
    if not r or not hasAccess(core().GetCharacter(src), r) then return false, 'no_access' end
    return true, exports.nexoro_inventory:GetStash('property', id, { slots = cfg.StashSlots, maxWeight = cfg.StashWeightGrams })
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_housing:list', function(src, p) return H.List(src, arg(p, 'agent')) end)
    cb('nexoro_housing:buy', function(src, p) return H.Buy(src, arg(p, 'id')) end, 5)
    cb('nexoro_housing:sell', function(src, p) return H.SellBack(src, arg(p, 'id')) end, 5)
    cb('nexoro_housing:arrears', function(src, p) return H.PayArrears(src, arg(p, 'id')) end, 5)
    cb('nexoro_housing:enter', function(src, p) return H.Enter(src, arg(p, 'id')) end, 30)
    cb('nexoro_housing:leave', function(src, p) return H.Leave(src, arg(p, 'id')) end, 30)
    cb('nexoro_housing:giveKey', function(src, p) return H.GiveKey(src, arg(p, 'id'), arg(p, 'target')) end, 5)
    cb('nexoro_housing:revokeKey', function(src, p) return H.RevokeKey(src, arg(p, 'id'), arg(p, 'characterId')) end, 5)
    cb('nexoro_housing:deposit', function(src, p) return H.Deposit(src, arg(p, 'id'), arg(p, 'item'), arg(p, 'amount')) end, 20)
    cb('nexoro_housing:withdraw', function(src, p) return H.Withdraw(src, arg(p, 'id'), arg(p, 'item'), arg(p, 'amount')) end, 20)
    cb('nexoro_housing:stash', function(src, p) return H.Stash(src, arg(p, 'id')) end, 20)
end

AddEventHandler('nexoro:core:ready', function() H.Seed(); register() end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then H.Seed(); register() end
    while true do
        Wait(cfg.BillCheckSeconds * 1000)
        H.Bills()
    end
end)

exports('List', H.List)
exports('Buy', H.Buy)
exports('Bills', H.Bills)
exports('Enter', H.Enter)
