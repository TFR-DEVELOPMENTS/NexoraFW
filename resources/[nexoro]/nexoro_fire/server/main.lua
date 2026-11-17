local cfg = Config.Fire
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroFire = {}
local F = NexoroFire
F.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
F.now = os.time

local hazards, nextHazard = {}, 0

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
local function staffName(src)
    local c = core().GetCharacter(src)
    return c and (c.firstName .. ' ' .. c.lastName) or 'Unknown'
end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function inRange(src, pos, range)
    local p = F.getCoords(src)
    return p ~= nil and distance(p, pos) <= range
end

local function incident(id)
    id = toInt(id)
    if not id then return nil, 'invalid_incident' end
    local row = NexoroDB.single('SELECT id, kind, status, x, y, z, extricated FROM nexoro_fire_incidents WHERE id = ?', { id })
    if not row then return nil, 'not_found' end
    return row
end

---------------------------------------------------------------------------
-- Hazard zones (held in memory; they expire on their own and reset on restart)
---------------------------------------------------------------------------

function F.ListHazards()
    local now = F.now()
    local out = {}
    for id, h in pairs(hazards) do
        if h.expires <= now then hazards[id] = nil
        else out[#out + 1] = { id = h.id, x = h.x, y = h.y, z = h.z, radius = h.radius, expires = h.expires } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function broadcastHazards()
    local list = F.ListHazards()
    for _, p in ipairs(core().GetPlayers()) do TriggerClientEvent('nexoro_fire:hazards', p.source, list) end
end

function F.clearHazardsNear(pos, radius)
    local removed = 0
    for id, h in pairs(hazards) do
        if distance(h, pos) <= radius then hazards[id] = nil; removed = removed + 1 end
    end
    if removed > 0 then broadcastHazards() end
    return removed
end

---------------------------------------------------------------------------
-- Incidents
---------------------------------------------------------------------------

function F.Create(src, kind, notes)
    if not can(src, 'fire.mdt') then return false, 'forbidden' end
    if type(kind) ~= 'string' or not cfg.Kinds[kind] then return false, 'invalid_kind' end
    local pos = F.getCoords(src)
    if not pos then return false, 'no_position' end
    local text = ''
    if notes ~= nil and notes ~= '' then
        text = cleanText(notes, 1, 300)
        if not text then return false, 'invalid_notes' end
    end
    local id = NexoroDB.insert('INSERT INTO nexoro_fire_incidents (kind, x, y, z, notes, opened_by) VALUES (?,?,?,?,?,?)',
        { kind, pos.x, pos.y, pos.z, text, staffName(src):sub(1, 100) })
    if not id then return false, 'database_error' end
    core().Log('fire', 'incident_created', src, { id = id, kind = kind })
    return true, { id = id }
end

function F.Attend(src, id)
    if not can(src, 'fire.mdt') then return false, 'forbidden' end
    local row, why = incident(id)
    if not row then return false, why end
    if row.status ~= 'open' then return false, 'invalid_state' end
    NexoroDB.update("UPDATE nexoro_fire_incidents SET status = 'attending' WHERE id = ? AND status = 'open'", { row.id })
    return true
end

function F.Close(src, id, outcome)
    if not can(src, 'fire.mdt') then return false, 'forbidden' end
    local row, why = incident(id)
    if not row then return false, why end
    if row.status == 'closed' then return false, 'invalid_state' end
    local text = cleanText(outcome, 3, 300)
    if not text then return false, 'invalid_outcome' end
    NexoroDB.update("UPDATE nexoro_fire_incidents SET status = 'closed', notes = ?, closed_by = ?, closed_at = NOW() WHERE id = ?",
        { text, staffName(src):sub(1, 100), row.id })
    return true
end

function F.Extinguish(src, id)
    if not can(src, 'fire.extinguish') then return false, 'forbidden' end
    local row, why = incident(id)
    if not row then return false, why end
    if row.kind ~= 'fire' then return false, 'wrong_incident_type' end
    if row.status == 'closed' then return false, 'invalid_state' end
    local pos = { x = row.x, y = row.y, z = row.z }
    if not inRange(src, pos, cfg.InteractDistance) then return false, 'too_far' end
    NexoroDB.update("UPDATE nexoro_fire_incidents SET status = 'controlled' WHERE id = ?", { row.id })
    local cleared = F.clearHazardsNear(pos, cfg.ExtinguishRadius)
    core().Log('fire', 'extinguished', src, { id = row.id, hazardsCleared = cleared })
    return true, { hazardsCleared = cleared }
end

function F.Extricate(src, id)
    if not can(src, 'fire.extricate') then return false, 'forbidden' end
    local row, why = incident(id)
    if not row then return false, why end
    if row.kind ~= 'rta' then return false, 'wrong_incident_type' end
    if row.status == 'closed' then return false, 'invalid_state' end
    if not inRange(src, { x = row.x, y = row.y, z = row.z }, cfg.InteractDistance) then return false, 'too_far' end
    NexoroDB.update('UPDATE nexoro_fire_incidents SET extricated = extricated + 1 WHERE id = ?', { row.id })
    -- Report the stored count, not a value computed from the row read before the update.
    local count = NexoroDB.scalar('SELECT extricated FROM nexoro_fire_incidents WHERE id = ?', { row.id })
    return true, { extricated = count }
end

function F.Incidents(src)
    if not can(src, 'fire.mdt') then return false, 'forbidden' end
    return true, NexoroDB.query(
        "SELECT id, kind, status, notes, extricated, DATE_FORMAT(created_at, '%H:%i') AS time FROM nexoro_fire_incidents WHERE status <> 'closed' ORDER BY id DESC LIMIT 50") or {}
end

function F.CreateHazard(src, radius, minutes)
    if not can(src, 'fire.hazard') then return false, 'forbidden' end
    local pos = F.getCoords(src)
    if not pos then return false, 'no_position' end
    local r = toInt(radius)
    if not r or r < cfg.HazardMinRadius or r > cfg.HazardMaxRadius then return false, 'invalid_radius' end
    local m = toInt(minutes)
    if not m or m < 1 or m > cfg.HazardMaxMinutes then return false, 'invalid_duration' end
    nextHazard = nextHazard + 1
    hazards[nextHazard] = { id = nextHazard, x = pos.x, y = pos.y, z = pos.z, radius = r, expires = F.now() + m * 60 }
    broadcastHazards()
    return true, { id = nextHazard }
end

function F.ClearHazard(src, id)
    if not can(src, 'fire.hazard') then return false, 'forbidden' end
    local n = toInt(id)
    if not n or not hazards[n] then return false, 'not_found' end
    hazards[n] = nil
    broadcastHazards()
    return true
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 40, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_fire:create', function(src, p) return F.Create(src, arg(p, 'kind'), arg(p, 'notes')) end, 20)
    cb('nexoro_fire:attend', function(src, p) return F.Attend(src, arg(p, 'id')) end, 20)
    cb('nexoro_fire:close', function(src, p) return F.Close(src, arg(p, 'id'), arg(p, 'outcome')) end, 20)
    cb('nexoro_fire:extinguish', function(src, p) return F.Extinguish(src, arg(p, 'id')) end, 20)
    cb('nexoro_fire:extricate', function(src, p) return F.Extricate(src, arg(p, 'id')) end, 20)
    cb('nexoro_fire:hazard', function(src, p) return F.CreateHazard(src, arg(p, 'radius'), arg(p, 'minutes')) end, 10)
    cb('nexoro_fire:clearHazard', function(src, p) return F.ClearHazard(src, arg(p, 'id')) end, 10)
    cb('nexoro_fire:incidents', function(src) return F.Incidents(src) end, 30)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerReady', function(src) TriggerClientEvent('nexoro_fire:hazards', src, F.ListHazards()) end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Create', F.Create)
exports('CreateHazard', F.CreateHazard)
exports('ListHazards', F.ListHazards)
