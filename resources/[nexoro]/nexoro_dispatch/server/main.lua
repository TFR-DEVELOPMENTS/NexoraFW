local cfg = Config.Dispatch
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroDispatch = {}
local D = NexoroDispatch
D.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
D.now = os.time

-- Units are on-duty emergency members. Held in memory: they are rebuilt from duty state on reconnect.
D.units = {}            -- [src] = { src, characterId, name, callsign, category, job, status, incidentId }
D.radio = {}            -- [src] = channel

local TRANSITIONS = {
    available = { unavailable = true },
    en_route = { on_scene = true, available = true },
    on_scene = { transporting = true, available = true },
    transporting = { on_scene = true, available = true },
    unavailable = { available = true },
}

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

local function started(res) return GetResourceState(res) == 'started' end
local function can(src, perm) return exports.nexoro_emergency:HasPerm(src, perm, false) end
local function operator(src) return can(src, 'dispatch.operate') end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

local function nameOf(src)
    local c = core().GetCharacter(src)
    return c and (c.firstName .. ' ' .. c.lastName) or 'Unknown'
end

local function unitCategory(src)
    local job = core().GetJob(src)
    if not job or not job.onDuty then return nil end
    if job.category == 'police' or job.category == 'ambulance' or job.category == 'fire' then return job.category end
    return nil
end

local function categoriesFor(kind) return cfg.KindCategories[kind] end

-- Radio channel a service talks on (police 101, ambulance 102, fire 103).
local function categoryChannel(cat)
    for ch, c in pairs(cfg.Radio.Channels) do if c == cat then return ch end end
    return nil
end

-- Automated radio traffic so units hear what is happening on their channel.
local function chatter(channel, text)
    if channel and started('nexoro_chat') then pcall(function() exports.nexoro_chat:RadioBroadcast(channel, text) end) end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------

function D.refreshUnit(src)
    local cat = unitCategory(src)
    if not cat then return D.removeUnit(src) end
    local c = core().GetCharacter(src)
    if not c then return end
    local u = D.units[src]
    if not u then
        D.units[src] = { src = src, characterId = c.id, name = nameOf(src), callsign = core().GetMetadata(src, 'callsign') or '', category = cat, job = core().GetJob(src).name, status = 'available', incidentId = nil }
    else
        u.category, u.callsign, u.name = cat, core().GetMetadata(src, 'callsign') or '', nameOf(src)
    end
end

local function releaseAssignment(u, status)
    if not u.incidentId then return end
    NexoroDB.update("UPDATE nexoro_dispatch_assignments SET status = ? WHERE incident_id = ? AND character_id = ? AND status <> 'released'",
        { status or 'released', u.incidentId, u.characterId })
    u.incidentId = nil
end

function D.removeUnit(src)
    local u = D.units[src]
    if not u then return end
    releaseAssignment(u, 'released')
    D.units[src] = nil
end

---------------------------------------------------------------------------
-- Incidents
---------------------------------------------------------------------------

local function incidentRow(id)
    id = toInt(id)
    if not id then return nil, 'invalid_incident' end
    local row = NexoroDB.single('SELECT id, source, kind, priority, status, description, x, y, z FROM nexoro_dispatch_incidents WHERE id = ?', { id })
    if not row then return nil, 'not_found' end
    return row
end

local function alertPayload(row)
    return { id = row.id, kind = row.kind, priority = row.priority, label = cfg.PriorityLabels[row.priority] or '', description = row.description, x = row.x, y = row.y, z = row.z }
end

function D.alert(row)
    local cats = categoriesFor(row.kind) or {}
    local payload = alertPayload(row)
    for _, u in pairs(D.units) do
        if cats[u.category] then TriggerClientEvent('nexoro_dispatch:alert', u.src, payload) end
    end
    for _, p in ipairs(core().GetPlayers()) do
        if operator(p.source) then TriggerClientEvent('nexoro_dispatch:alert', p.source, payload) end
    end
end

local function open(source, kind, priority, description, pos, caller, createdBy)
    local id = NexoroDB.insert(
        'INSERT INTO nexoro_dispatch_incidents (source, kind, priority, description, caller, x, y, z, created_by) VALUES (?,?,?,?,?,?,?,?,?)',
        { source, kind, priority, description or '', caller or '', pos.x, pos.y, pos.z, createdBy or 'Dispatch' })
    if not id then return nil, 'database_error' end
    local row = incidentRow(id)
    D.alert(row)
    core().Log('dispatch', 'incident_opened', nil, { id = id, source = source, kind = kind })
    return id
end

-- A call from the phone (999 / 101 / 111). The caller's position is taken from the server.
function D.onCall(src, number)
    local spec = cfg.Calls[tostring(number)]
    if not spec then return false, 'unknown_number' end
    local pos = D.getCoords(src) or { x = 0.0, y = 0.0, z = 0.0 }
    local caller = started('nexoro_phone') and (function()
        local ok, n = pcall(function() return exports.nexoro_phone:GetNumber(src) end)
        return ok and n or ''
    end)() or ''
    local id = open(tostring(number), spec.kind, spec.priority, ('Call to %s'):format(tostring(number)), pos, caller, 'Caller')
    return id ~= nil, id
end

AddEventHandler('nexoro:server:emergencyCall', function(src, number) D.onCall(src, number) end)

function D.Open(src, kind, priority, description)
    if not operator(src) then return false, 'forbidden' end
    if not categoriesFor(kind) then return false, 'invalid_kind' end
    local p = toInt(priority or 2)
    if not p or p < 1 or p > 3 then return false, 'invalid_priority' end
    local text = description == nil and '' or cleanText(description, 3, 300)
    if description ~= nil and description ~= '' and not text then return false, 'invalid_description' end
    local pos = D.getCoords(src) or { x = 0.0, y = 0.0, z = 0.0 }
    local id, why = open('manual', kind, p, text or '', pos, '', nameOf(src))
    if not id then return false, why end
    return true, { id = id }
end

function D.SetPriority(src, id, priority)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    if row.status == 'closed' then return false, 'invalid_state' end
    local p = toInt(priority)
    if not p or p < 1 or p > 3 then return false, 'invalid_priority' end
    NexoroDB.update('UPDATE nexoro_dispatch_incidents SET priority = ? WHERE id = ?', { p, row.id })
    return true
end

function D.Describe(src, id, text)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    local t = cleanText(text, 3, 300)
    if not t then return false, 'invalid_description' end
    NexoroDB.update('UPDATE nexoro_dispatch_incidents SET description = ? WHERE id = ?', { t, row.id })
    return true
end

function D.Assign(src, id, unitSrc)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    if row.status == 'closed' then return false, 'invalid_state' end
    local u = D.units[toInt(unitSrc) or -1]
    if not u then return false, 'unit_not_on_duty' end
    if not categoriesFor(row.kind)[u.category] then return false, 'wrong_service' end
    if u.status ~= 'available' then return false, 'unit_busy' end
    NexoroDB.update(
        "INSERT INTO nexoro_dispatch_assignments (incident_id, character_id, callsign, job, status) VALUES (?,?,?,?,'en_route') " ..
        "ON DUPLICATE KEY UPDATE status = 'en_route', callsign = VALUES(callsign), job = VALUES(job)",
        { row.id, u.characterId, u.callsign:sub(1, 12), u.job })
    u.status, u.incidentId = 'en_route', row.id
    if row.status == 'open' then NexoroDB.update("UPDATE nexoro_dispatch_incidents SET status = 'assigned' WHERE id = ?", { row.id }) end
    TriggerClientEvent('nexoro_dispatch:waypoint', u.src, {
        x = row.x, y = row.y, z = row.z, label = ('%s %d - %s'):format(cfg.WaypointLabelPrefix, row.id, row.description) })
    core().Notify(u.src, ('You have been assigned to incident %d.'):format(row.id), 'emergency', 8000)
    chatter(categoryChannel(u.category), ('%s, attend incident %d: %s.'):format(u.callsign ~= '' and u.callsign or 'Unit', row.id, row.description))
    core().Log('dispatch', 'assigned', src, { incident = row.id, unit = u.src })
    return true
end

function D.Unassign(src, id, unitSrc)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    local u = D.units[toInt(unitSrc) or -1]
    if not u or u.incidentId ~= row.id then return false, 'not_assigned' end
    releaseAssignment(u, 'released')
    u.status = 'available'
    core().Notify(u.src, ('You have been released from incident %d.'):format(row.id), 'emergency', 6000)
    return true
end

-- A unit reports its own status. Transitions are checked; leaving a job releases the unit.
function D.SetStatus(src, status)
    local u = D.units[src]
    if not u then return false, 'not_a_unit' end
    if type(status) ~= 'string' or not TRANSITIONS[u.status] or not TRANSITIONS[u.status][status] then return false, 'invalid_transition' end
    u.status = status
    chatter(categoryChannel(u.category), ('%s, now %s.'):format(u.callsign ~= '' and u.callsign or 'Unit', status))
    if u.incidentId then
        local stored = status == 'available' and 'released' or status
        NexoroDB.update("UPDATE nexoro_dispatch_assignments SET status = ? WHERE incident_id = ? AND character_id = ? AND status <> 'released'",
            { stored, u.incidentId, u.characterId })
        if status == 'available' then u.incidentId = nil end
    end
    return true
end

function D.Close(src, id, outcome)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    if row.status == 'closed' then return false, 'invalid_state' end
    local text = cleanText(outcome, 3, 300)
    if not text then return false, 'invalid_outcome' end
    NexoroDB.update("UPDATE nexoro_dispatch_incidents SET status = 'closed', description = CONCAT(description, ' | Outcome: ', ?), closed_at = NOW(), closed_by = ? WHERE id = ?",
        { text, nameOf(src):sub(1, 100), row.id })
    for _, u in pairs(D.units) do
        if u.incidentId == row.id then
            releaseAssignment(u, 'released')
            u.status = 'available'
        end
    end
    for _, p in ipairs(core().GetPlayers()) do TriggerClientEvent('nexoro_dispatch:closed', p.source, { id = row.id }) end
    return true
end

function D.List(src)
    if not (operator(src) or D.units[src]) then return false, 'forbidden' end
    local rows = NexoroDB.query(
        "SELECT id, source, kind, priority, status, description, x, y, z, created_by, DATE_FORMAT(created_at, '%H:%i') AS time FROM nexoro_dispatch_incidents WHERE status <> 'closed' ORDER BY priority, id DESC LIMIT 50") or {}
    for _, r in ipairs(rows) do
        r.label = cfg.PriorityLabels[r.priority] or ''
        r.units = NexoroDB.query(
            "SELECT callsign, job, status FROM nexoro_dispatch_assignments WHERE incident_id = ? AND status <> 'released' ORDER BY id", { r.id }) or {}
    end
    return true, rows
end

function D.Units(src)
    if not operator(src) then return false, 'forbidden' end
    local out = {}
    for _, u in pairs(D.units) do
        out[#out + 1] = { src = u.src, name = u.name, callsign = u.callsign, category = u.category, status = u.status, incidentId = u.incidentId }
    end
    table.sort(out, function(a, b) return a.category == b.category and a.callsign < b.callsign or a.category < b.category end)
    return true, out
end

function D.History(src, id)
    if not operator(src) then return false, 'forbidden' end
    local row, why = incidentRow(id)
    if not row then return false, why end
    return true, NexoroDB.query(
        "SELECT callsign, job, status, DATE_FORMAT(assigned_at, '%H:%i') AS assigned, DATE_FORMAT(updated_at, '%H:%i') AS updated FROM nexoro_dispatch_assignments WHERE incident_id = ? ORDER BY id",
        { row.id }) or {}
end

---------------------------------------------------------------------------
-- Radio
---------------------------------------------------------------------------

function D.RadioJoin(src, channel)
    local ch = toInt(channel)
    if not ch then return false, 'invalid_channel' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if ch >= 1 and ch <= cfg.Radio.PublicMax then
        local ok, has = pcall(function() return exports.nexoro_inventory:HasItem(src, 'radio', 1) end)
        if not ok or not has then return false, 'no_radio' end
    elseif cfg.Radio.Channels[ch] then
        local cat = cfg.Radio.Channels[ch]
        if unitCategory(src) ~= cat then return false, 'not_on_duty_service' end
    elseif ch == cfg.Radio.DispatchChannel then
        if not operator(src) then return false, 'forbidden' end
    else
        return false, 'invalid_channel'
    end
    D.radio[src] = ch
    Player(src).state:set('radioChannel', ch, true)
    if started('pma-voice') then pcall(function() exports['pma-voice']:setRadioChannel(src, ch) end) end
    return true, { channel = ch }
end

function D.RadioLeave(src)
    if not D.radio[src] then return false, 'not_on_radio' end
    D.radio[src] = nil
    Player(src).state:set('radioChannel', nil, true)
    if started('pma-voice') then pcall(function() exports['pma-voice']:setRadioChannel(src, 0) end) end
    return true
end

---------------------------------------------------------------------------
-- Lifecycle and registration
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_dispatch:open', function(src, p) return D.Open(src, arg(p, 'kind'), arg(p, 'priority'), arg(p, 'description')) end, 10)
    cb('nexoro_dispatch:priority', function(src, p) return D.SetPriority(src, arg(p, 'id'), arg(p, 'priority')) end, 20)
    cb('nexoro_dispatch:describe', function(src, p) return D.Describe(src, arg(p, 'id'), arg(p, 'text')) end, 20)
    cb('nexoro_dispatch:assign', function(src, p) return D.Assign(src, arg(p, 'id'), arg(p, 'unit')) end, 30)
    cb('nexoro_dispatch:unassign', function(src, p) return D.Unassign(src, arg(p, 'id'), arg(p, 'unit')) end, 30)
    cb('nexoro_dispatch:setStatus', function(src, p) return D.SetStatus(src, arg(p, 'status')) end, 30)
    cb('nexoro_dispatch:close', function(src, p) return D.Close(src, arg(p, 'id'), arg(p, 'outcome')) end, 20)
    cb('nexoro_dispatch:list', function(src) return D.List(src) end, 30)
    cb('nexoro_dispatch:units', function(src) return D.Units(src) end, 30)
    cb('nexoro_dispatch:history', function(src, p) return D.History(src, arg(p, 'id')) end, 30)
    cb('nexoro_dispatch:radioJoin', function(src, p) return D.RadioJoin(src, arg(p, 'channel')) end, 10)
    cb('nexoro_dispatch:radioLeave', function(src) return D.RadioLeave(src) end, 10)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:dutyChanged', function(src) D.refreshUnit(src) end)
AddEventHandler('nexoro:server:characterLoaded', function(src) D.refreshUnit(src) end)
AddEventHandler('nexoro:server:characterUnloaded', function(src) D.removeUnit(src); D.radio[src] = nil end)
AddEventHandler('nexoro:server:playerDropped', function(src) D.removeUnit(src); D.radio[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

-- Units on duty, for the map. Positions are read by the map resource, not stored here.
function D.UnitList()
    local out = {}
    for src, u in pairs(D.units) do
        out[#out + 1] = { src = src, callsign = u.callsign, category = u.category, status = u.status }
    end
    table.sort(out, function(a, b) return a.src < b.src end)
    return out
end

exports('UnitList', D.UnitList)
exports('Open', D.Open)
exports('Assign', D.Assign)
exports('SetStatus', D.SetStatus)
exports('RadioJoin', D.RadioJoin)
exports('GetRadioChannel', function(src) return D.radio[src] end)
exports('OnCall', D.onCall)
exports('IsUnit', function(src) return D.units[src] ~= nil end)
-- For other systems (robberies, alarms): raises an incident at a position without a caller.
exports('Alert', function(kind, pos, priority, description)
    if not categoriesFor(kind) then return false, 'invalid_kind' end
    local id = open('system', kind, toInt(priority) or 2, tostring(description or ''):sub(1, 300), pos or { x = 0.0, y = 0.0, z = 0.0 }, '', 'System')
    return id ~= nil, id
end)

-- Alarms from other resources (robberies, etc.) become police incidents at the scene.
AddEventHandler('nexoro:server:alarm', function(data)
    if type(data) ~= 'table' or type(data.x) ~= 'number' or type(data.y) ~= 'number' then return end
    local pos = { x = data.x + 0.0, y = data.y + 0.0, z = (tonumber(data.z) or 0) + 0.0 }
    open('alarm', 'police', 1, tostring(data.description or 'Alarm'):sub(1, 200), pos, '', 'Alarm')
end)
