local cfg = Config.Police
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroPolice = {}
local P = NexoroPolice

-- Overridable in tests. Returns the ped position on the server.
P.getCoords = function(src)
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

local function cleanText(s, min, max)
    if type(s) ~= 'string' then return nil end
    s = (s:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', ''))
    local len = utf8.len(s)
    if not len or len < min or len > max then return nil end
    return s
end

local function can(src, perm) return exports.nexoro_emergency:HasPerm(src, perm, false) end

local function officer(src)
    local c = core().GetCharacter(src)
    return { name = c and (c.firstName .. ' ' .. c.lastName) or 'Unknown', callsign = core().GetMetadata(src, 'callsign') or '' }
end

local function nearTarget(src, t)
    local a, b = P.getCoords(src), P.getCoords(t)
    if not a or not b then return false end
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) <= cfg.InteractDistance
end

local function targetOf(target)
    local t = toInt(target)
    if not t or not core().GetCharacter(t) then return nil, 'target_not_found' end
    return t
end

local function record(src, kind, characterId, detail, status, amountPence)
    local o = officer(src)
    return NexoroDB.insert(
        'INSERT INTO nexoro_police_records (character_id, kind, detail, status, amount_pence, officer, callsign) VALUES (?,?,?,?,?,?,?)',
        { characterId, kind, (detail or ''):sub(1, 300), status or 'open', amountPence or 0, o.name:sub(1, 100), o.callsign:sub(1, 12) })
end

---------------------------------------------------------------------------
-- Restraint and arrest
---------------------------------------------------------------------------

function P.Cuff(src, target)
    if not can(src, 'police.cuff') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if t == src then return false, 'cannot_target_self' end
    if not nearTarget(src, t) then return false, 'too_far' end
    if core().GetMetadata(t, 'cuffed') then return false, 'already_cuffed' end
    core().SetMetadata(t, 'cuffed', true)
    TriggerClientEvent('nexoro_police:cuffs', t, true)
    core().Log('police', 'cuff', src, { target = t })
    return true
end

function P.Uncuff(src, target)
    if not can(src, 'police.cuff') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    if not core().GetMetadata(t, 'cuffed') then return false, 'not_cuffed' end
    core().SetMetadata(t, 'cuffed', nil)
    TriggerClientEvent('nexoro_police:cuffs', t, false)
    return true
end

function P.Arrest(src, target, offence, minutes)
    if not can(src, 'police.cuff') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    if not core().GetMetadata(t, 'cuffed') then return false, 'not_cuffed' end
    local text = cleanText(offence, 3, 120)
    if not text then return false, 'invalid_offence' end
    local m = toInt(minutes or 0)
    if not m or m < 0 or m > cfg.MaxSentenceMinutes then return false, 'invalid_sentence' end
    local id = record(src, 'arrest', core().GetCharacter(t).id, text .. (m > 0 and (' - ' .. m .. ' minutes') or ''), 'open', 0)
    core().SetMetadata(t, 'arrested', m)
    TriggerEvent('nexoro:server:arrested', t, m, text)   -- nexoro_prison takes it from here
    core().Log('police', 'arrest', src, { target = t, record = id })
    return true, { recordId = id }
end

function P.Release(src, target)
    if not can(src, 'police.cuff') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    if not core().GetMetadata(t, 'cuffed') and core().GetMetadata(t, 'arrested') == nil then return false, 'not_detained' end
    core().SetMetadata(t, 'cuffed', nil)
    core().SetMetadata(t, 'arrested', nil)
    TriggerClientEvent('nexoro_police:cuffs', t, false)
    return true
end

---------------------------------------------------------------------------
-- Penalties and cautions
---------------------------------------------------------------------------

function P.Fine(src, target, amount, reason)
    if not can(src, 'police.fine') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    local text = cleanText(reason, 3, 120)
    if not text then return false, 'invalid_reason' end
    local pence = core().ToPence(tonumber(amount))
    if not pence or pence <= 0 then return false, 'invalid_amount' end
    if pence > cfg.MaxFine * 100 then return false, 'amount_too_large' end
    local ok, err = core().RemoveMoney(t, pence / 100, 'bank', 'penalty notice: ' .. text)
    local status
    if ok then status = 'paid'
    elseif err == 'insufficient_funds' then status = 'outstanding'
    else return false, err end
    record(src, 'fine', core().GetCharacter(t).id, text, status, pence)
    core().Notify(t, ('Penalty notice: %s (%s, %s).'):format(core().FormatGBP(pence), text, status), 'warning', 8000)
    return true, { status = status, amount = core().FormatGBP(pence) }
end

function P.Caution(src, target, reason)
    if not can(src, 'police.caution') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    local text = cleanText(reason, 3, 300)
    if not text then return false, 'invalid_reason' end
    local id = record(src, 'caution', core().GetCharacter(t).id, text, 'issued', 0)
    core().Notify(t, 'You have received a caution: ' .. text, 'warning', 8000)
    return true, { recordId = id }
end

---------------------------------------------------------------------------
-- Warrants and MDT
---------------------------------------------------------------------------

local function characterByCitizen(citizenId)
    if not exports.nexoro_identity:IsValidCitizenId(citizenId) then return nil, 'invalid_citizen_id' end
    local row = NexoroDB.single('SELECT id, citizen_id, first_name, last_name FROM nexoro_characters WHERE citizen_id = ?', { citizenId })
    if not row then return nil, 'citizen_not_found' end
    return row
end

function P.Warrant(src, citizenId, reason)
    if not can(src, 'police.warrant') then return false, 'forbidden' end
    local row, why = characterByCitizen(citizenId)
    if not row then return false, why end
    local text = cleanText(reason, 3, 300)
    if not text then return false, 'invalid_reason' end
    local id = record(src, 'warrant', row.id, text, 'open', 0)
    core().Log('police', 'warrant', src, { citizenId = row.citizen_id, record = id })
    return true, { recordId = id, name = row.first_name .. ' ' .. row.last_name }
end

function P.ClearWarrant(src, recordId)
    if not can(src, 'police.warrant') then return false, 'forbidden' end
    local id = toInt(recordId)
    if not id then return false, 'invalid_request' end
    local affected = NexoroDB.update("UPDATE nexoro_police_records SET status = 'cleared' WHERE id = ? AND kind = 'warrant' AND status = 'open'", { id })
    if affected ~= 1 then return false, 'not_found' end
    core().Log('police', 'warrant_cleared', src, { record = id })
    return true
end

function P.Mdt(src, citizenId)
    if not can(src, 'police.mdt') then return false, 'forbidden' end
    local row, why = characterByCitizen(citizenId)
    if not row then return false, why end
    local records = NexoroDB.query(
        "SELECT kind, detail, status, amount_pence, officer, callsign, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM nexoro_police_records WHERE character_id = ? ORDER BY id DESC LIMIT 30",
        { row.id }) or {}
    for _, r in ipairs(records) do
        r.amount = r.amount_pence > 0 and core().FormatGBP(r.amount_pence) or nil
        r.amount_pence = nil
    end
    local warrants = NexoroDB.scalar("SELECT COUNT(*) FROM nexoro_police_records WHERE character_id = ? AND kind = 'warrant' AND status = 'open'", { row.id }) or 0
    return true, { name = row.first_name .. ' ' .. row.last_name, citizenId = row.citizen_id, openWarrants = warrants, records = records }
end

function P.Wanted(src)
    if not can(src, 'police.mdt') then return false, 'forbidden' end
    return true, NexoroDB.query(
        "SELECT r.id, c.citizen_id, c.first_name, c.last_name, r.detail, r.officer, DATE_FORMAT(r.created_at, '%d/%m/%Y') AS date " ..
        "FROM nexoro_police_records r JOIN nexoro_characters c ON c.id = r.character_id WHERE r.kind = 'warrant' AND r.status = 'open' ORDER BY r.id DESC LIMIT 50") or {}
end

-- Vehicle lookups need nexoro_vehicles; reported cleanly when it is not running.
function P.Plate(src, plate)
    if not can(src, 'police.mdt') then return false, 'forbidden' end
    if GetResourceState('nexoro_vehicles') ~= 'started' then return false, 'vehicles_unavailable' end
    local ok, data = pcall(function() return exports.nexoro_vehicles:LookupPlate(plate) end)
    if not ok or not data then return false, 'not_found' end
    return true, data
end

---------------------------------------------------------------------------
-- Search, seizure, breath
---------------------------------------------------------------------------

function P.Search(src, target)
    if not can(src, 'police.search') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    local inv = exports.nexoro_inventory:GetInventory(t)
    if not inv then return false, 'inventory_unavailable' end
    local items = {}
    for _, it in ipairs(inv.items) do items[#items + 1] = { slot = it.slot, item = it.item, label = it.label, amount = it.amount } end
    return true, { items = items, weight = inv.weight }
end

local EVIDENCE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
local function newEvidenceRef()
    for _ = 1, 20 do
        local t = {}
        for i = 1, 6 do local k = math.random(1, #EVIDENCE_CHARS); t[i] = EVIDENCE_CHARS:sub(k, k) end
        local ref = 'EV' .. table.concat(t)
        if not NexoroDB.scalar('SELECT 1 FROM nexoro_police_evidence WHERE reference = ?', { ref }) then return ref end
    end
    return nil
end

-- Takes items from a suspect into a numbered evidence bag. Fails safely: the item is returned on any error.
function P.Seize(src, target, item, amount)
    if not can(src, 'police.seize') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    if type(item) ~= 'string' or not item:match('^[a-z0-9_]+$') then return false, 'invalid_item' end
    local n = toInt(amount)
    if not n or n < 1 or n > 1000 then return false, 'invalid_amount' end
    local ref = newEvidenceRef()
    if not ref then return false, 'evidence_failed' end
    local removed, rwhy = exports.nexoro_inventory:RemoveItem(t, item, n)
    if not removed then return false, rwhy end
    local o = officer(src)
    NexoroDB.insert('INSERT INTO nexoro_police_evidence (reference, officer) VALUES (?, ?)', { ref, o.name })
    local stashed = exports.nexoro_inventory:AddItemToStash('evidence', ref, item, n, nil, { slots = cfg.EvidenceSlots, maxWeight = cfg.EvidenceMaxWeight })
    if not stashed then
        exports.nexoro_inventory:AddItem(t, item, n)
        NexoroDB.update('DELETE FROM nexoro_police_evidence WHERE reference = ?', { ref })
        return false, 'evidence_failed'
    end
    record(src, 'seizure', core().GetCharacter(t).id, ('%s x%d seized as %s'):format(item, n, ref), 'held', 0)
    core().Log('police', 'seize', src, { target = t, reference = ref, item = item, amount = n })
    return true, { reference = ref }
end

function P.Breath(src, target)
    if not can(src, 'police.breath') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not nearTarget(src, t) then return false, 'too_far' end
    local reading = tonumber(core().GetMetadata(t, 'alcohol')) or 0
    local passed = reading <= cfg.BreathLimit
    if not passed then record(src, 'breath', core().GetCharacter(t).id, ('reading %d (limit %d)'):format(reading, cfg.BreathLimit), 'failed', 0) end
    return true, { reading = reading, passed = passed, limit = cfg.BreathLimit }
end

---------------------------------------------------------------------------
-- Registration and lifecycle
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 40, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_police:cuff', function(src, p) return P.Cuff(src, arg(p, 'target')) end)
    cb('nexoro_police:uncuff', function(src, p) return P.Uncuff(src, arg(p, 'target')) end)
    cb('nexoro_police:arrest', function(src, p) return P.Arrest(src, arg(p, 'target'), arg(p, 'offence'), arg(p, 'minutes')) end, 20)
    cb('nexoro_police:release', function(src, p) return P.Release(src, arg(p, 'target')) end)
    cb('nexoro_police:fine', function(src, p) return P.Fine(src, arg(p, 'target'), arg(p, 'amount'), arg(p, 'reason')) end, 20)
    cb('nexoro_police:caution', function(src, p) return P.Caution(src, arg(p, 'target'), arg(p, 'reason')) end, 20)
    cb('nexoro_police:warrant', function(src, p) return P.Warrant(src, arg(p, 'citizenId'), arg(p, 'reason')) end, 10)
    cb('nexoro_police:clearWarrant', function(src, p) return P.ClearWarrant(src, arg(p, 'id')) end, 10)
    cb('nexoro_police:search', function(src, p) return P.Search(src, arg(p, 'target')) end)
    cb('nexoro_police:seize', function(src, p) return P.Seize(src, arg(p, 'target'), arg(p, 'item'), arg(p, 'amount')) end, 20)
    cb('nexoro_police:breath', function(src, p) return P.Breath(src, arg(p, 'target')) end, 20)
    cb('nexoro_police:mdt', function(src, p) return P.Mdt(src, arg(p, 'citizenId')) end, 30)
    cb('nexoro_police:wanted', function(src) return P.Wanted(src) end, 20)
    cb('nexoro_police:plate', function(src, p) return P.Plate(src, arg(p, 'plate')) end, 30)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Cuff', P.Cuff)
exports('Uncuff', P.Uncuff)
exports('Fine', P.Fine)
exports('Warrant', P.Warrant)
exports('Mdt', P.Mdt)
