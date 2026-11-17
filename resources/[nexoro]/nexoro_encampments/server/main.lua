local cfg = Config.Encampments
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroEncampments = {}
local E = NexoroEncampments
E.now = os.time
E.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local gateOpen = {}   -- [gateId] = true when open (default closed)

local function pitchDef(id)
    for _, p in ipairs(cfg.Pitches) do if p.id == id then return p end end
    return nil
end
local function gateDef(id)
    for _, g in ipairs(cfg.Gates) do if g.id == id then return g end end
    return nil
end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

local function ensurePitch(id)
    NexoroDB.update('INSERT IGNORE INTO nexoro_pitches (id) VALUES (?)', { id })
end

local function policeJob(src)
    local job = core().GetJob(src)
    if not job or job.onDuty ~= true then return nil end
    if job.name ~= 'caledonia_police' then return nil end
    return job
end

-- Claims an empty pitch on the site. One pitch per character.
function E.Claim(src, pitchId)
    local def = pitchDef(pitchId)
    if not def then return false, 'unknown_pitch' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local p = E.getCoords(src)
    if not p or distance(p, def) > def.radius then return false, 'too_far' end
    if NexoroDB.scalar('SELECT 1 FROM nexoro_pitches WHERE owner_id = ?', { c.id }) then return false, 'already_claimed' end
    ensurePitch(def.id)
    local ok, why = core().RemoveMoney(src, cfg.ClaimFeePounds, 'bank', 'pitch claim: ' .. def.id)
    if not ok then return false, why end
    local affected = NexoroDB.update('UPDATE nexoro_pitches SET owner_id = ?, claimed_at = ? WHERE id = ? AND owner_id IS NULL', { c.id, E.now(), def.id })
    if affected ~= 1 then
        core().AddMoney(src, cfg.ClaimFeePounds, 'bank', 'refund: pitch taken')
        return false, 'pitch_taken'
    end
    core().Log('encampments', 'claimed', src, { pitch = def.id })
    return true, { pitch = def.label }
end

function E.Vacate(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local pitch = NexoroDB.single('SELECT id FROM nexoro_pitches WHERE owner_id = ?', { c.id })
    if not pitch then return false, 'no_pitch' end
    NexoroDB.update('UPDATE nexoro_pitches SET owner_id = NULL, claimed_at = NULL WHERE id = ?', { pitch.id })
    NexoroDB.update("UPDATE nexoro_pitch_notices SET status = 'closed' WHERE pitch_id = ? AND status = 'active'", { pitch.id })
    return true
end

-- Police serve a notice to the occupant of a pitch. The notice gives NoticeDays to move on.
function E.ServeNotice(src, pitchId)
    local job = policeJob(src)
    if not job or job.grade < cfg.NoticeRank then return false, 'not_police' end
    local def = pitchDef(pitchId)
    if not def then return false, 'unknown_pitch' end
    local owner = NexoroDB.single('SELECT owner_id FROM nexoro_pitches WHERE id = ?', { def.id })
    if not owner or not owner.owner_id then return false, 'not_occupied' end
    local now = E.now()
    local deadline = now + cfg.NoticeDays * 86400
    local officer = core().GetCharacter(src)
    NexoroDB.insert('INSERT INTO nexoro_pitch_notices (pitch_id, issued_by, issued_at, deadline) VALUES (?,?,?,?)',
        { def.id, officer and (officer.firstName .. ' ' .. officer.lastName) or 'Police', now, deadline })
    local occupant = core().GetSourceByCharacterId(owner.owner_id)
    if occupant then core().Notify(occupant, ('A notice to move on from %s has been served. Deadline in %d days.'):format(def.label, cfg.NoticeDays), 'warning', 15000) end
    core().Log('encampments', 'notice', src, { pitch = def.id })
    return true, { deadline = deadline }
end

-- A warrant can only follow a notice whose deadline has passed. It lets police open the gate and enter.
function E.IssueWarrant(src, pitchId, reason)
    local job = policeJob(src)
    if not job or job.grade < cfg.WarrantRank then return false, 'not_authorised' end
    local def = pitchDef(pitchId)
    if not def then return false, 'unknown_pitch' end
    if type(reason) ~= 'string' or #reason < 5 or #reason > 200 then return false, 'invalid_reason' end
    local expired = NexoroDB.scalar("SELECT 1 FROM nexoro_pitch_notices WHERE pitch_id = ? AND status = 'active' AND deadline <= ?", { def.id, E.now() })
    if not expired then return false, 'no_expired_notice' end
    local now = E.now()
    local officer = core().GetCharacter(src)
    NexoroDB.insert('INSERT INTO nexoro_pitch_warrants (pitch_id, issued_by, reason, issued_at, expires_at) VALUES (?,?,?,?,?)',
        { def.id, officer and (officer.firstName .. ' ' .. officer.lastName) or 'Police', reason, now, now + cfg.WarrantHours * 3600 })
    core().Log('encampments', 'warrant', src, { pitch = def.id })
    return true, { hours = cfg.WarrantHours }
end

function E.HasWarrant(pitchId)
    return NexoroDB.scalar('SELECT 1 FROM nexoro_pitch_warrants WHERE pitch_id = ? AND expires_at > ?', { pitchId, E.now() }) ~= nil
end

-- Gates: the occupant may open or close their own pitch's gate. Police with a live warrant may too.
function E.ToggleGate(src, gateId)
    local g = gateDef(gateId)
    if not g then return false, 'unknown_gate' end
    local p = E.getCoords(src)
    if not p or distance(p, g) > g.radius then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local owns = NexoroDB.scalar('SELECT 1 FROM nexoro_pitches WHERE id = ? AND owner_id = ?', { g.pitch, c.id }) ~= nil
    local warranted = policeJob(src) ~= nil and E.HasWarrant(g.pitch)
    if not owns and not warranted then return false, 'no_access' end
    gateOpen[g.id] = not gateOpen[g.id]
    TriggerClientEvent('nexoro_encampments:gate', -1, { id = g.id, open = gateOpen[g.id] == true })
    core().Log('encampments', 'gate', src, { gate = g.id, open = gateOpen[g.id] == true, by = owns and 'occupant' or 'warrant' })
    return true, { open = gateOpen[g.id] == true }
end

function E.GateState(gateId) return gateOpen[gateId] == true end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_encampments:claim', function(src, p) return E.Claim(src, arg(p, 'pitch')) end, 5)
    cb('nexoro_encampments:vacate', function(src) return E.Vacate(src) end, 5)
    cb('nexoro_encampments:notice', function(src, p) return E.ServeNotice(src, arg(p, 'pitch')) end, 10)
    cb('nexoro_encampments:warrant', function(src, p) return E.IssueWarrant(src, arg(p, 'pitch'), arg(p, 'reason')) end, 5)
    cb('nexoro_encampments:gate', function(src, p) return E.ToggleGate(src, arg(p, 'gate')) end, 30)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Claim', E.Claim)
exports('ServeNotice', E.ServeNotice)
exports('IssueWarrant', E.IssueWarrant)
exports('HasWarrant', E.HasWarrant)
