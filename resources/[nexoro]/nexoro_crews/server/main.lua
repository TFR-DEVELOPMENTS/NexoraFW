local cfg = Config.Crews
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroCrews = {}
local C = NexoroCrews
C.now = os.time

local invites = {}   -- [characterId] = { crewId, expires }

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function cleanName(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(s)
    if not len or len < cfg.NameMin or len > cfg.NameMax then return nil end
    return s
end

function C.CrewOf(characterId)
    return NexoroDB.single('SELECT c.id, c.name, c.leader_id FROM nexoro_crew_members m JOIN nexoro_crews c ON c.id = m.crew_id WHERE m.character_id = ?', { characterId })
end

-- True when two characters are in the same crew.
function C.SameCrew(a, b)
    local x, y = C.CrewOf(a), C.CrewOf(b)
    return x ~= nil and y ~= nil and x.id == y.id
end

function C.Create(src, name)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if C.CrewOf(c.id) then return false, 'already_in_crew' end
    local text = cleanName(name)
    if not text then return false, 'invalid_name' end
    if NexoroDB.scalar('SELECT 1 FROM nexoro_crews WHERE name = ?', { text }) then return false, 'name_taken' end
    local ok, why = core().RemoveMoney(src, cfg.CreationFeePounds, 'bank', 'crew registration')
    if not ok then return false, why end
    local id = NexoroDB.insert('INSERT INTO nexoro_crews (name, leader_id, created_at) VALUES (?,?,?)', { text, c.id, C.now() })
    if not id then core().AddMoney(src, cfg.CreationFeePounds, 'bank', 'refund: crew failed'); return false, 'database_error' end
    NexoroDB.update('INSERT INTO nexoro_crew_members (character_id, crew_id, joined_at) VALUES (?,?,?)', { c.id, id, C.now() })
    core().Log('crews', 'created', src, { crew = id, name = text })
    return true, { id = id, name = text }
end

function C.Invite(src, target)
    local me = core().GetCharacter(src)
    local crew = me and C.CrewOf(me.id)
    if not crew then return false, 'not_in_crew' end
    if crew.leader_id ~= me.id then return false, 'not_leader' end
    local t = toInt(target)
    local tc = t and core().GetCharacter(t)
    if not tc then return false, 'target_not_found' end
    if C.CrewOf(tc.id) then return false, 'target_in_crew' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_crew_members WHERE crew_id = ?', { crew.id }) or 0
    if count >= cfg.MaxMembers then return false, 'crew_full' end
    invites[tc.id] = { crewId = crew.id, expires = C.now() + cfg.InviteSeconds }
    core().Notify(t, ('You have been invited to join %s. Type /crew accept to join.'):format(crew.name), 'job', 20000)
    return true, { crew = crew.name }
end

function C.Accept(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if C.CrewOf(c.id) then return false, 'already_in_crew' end
    local inv = invites[c.id]
    if not inv or inv.expires < C.now() then return false, 'no_invite' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_crew_members WHERE crew_id = ?', { inv.crewId }) or 0
    if count >= cfg.MaxMembers then return false, 'crew_full' end
    invites[c.id] = nil
    NexoroDB.update('INSERT INTO nexoro_crew_members (character_id, crew_id, joined_at) VALUES (?,?,?)', { c.id, inv.crewId, C.now() })
    return true, { crew = C.CrewOf(c.id).name }
end

function C.Leave(src)
    local c = core().GetCharacter(src)
    local crew = c and C.CrewOf(c.id)
    if not crew then return false, 'not_in_crew' end
    if crew.leader_id == c.id then return false, 'leader_must_disband' end
    NexoroDB.update('DELETE FROM nexoro_crew_members WHERE character_id = ?', { c.id })
    return true
end

function C.Kick(src, characterId)
    local me = core().GetCharacter(src)
    local crew = me and C.CrewOf(me.id)
    if not crew then return false, 'not_in_crew' end
    if crew.leader_id ~= me.id then return false, 'not_leader' end
    local cid = toInt(characterId)
    if not cid or cid == me.id then return false, 'invalid_request' end
    local affected = NexoroDB.update('DELETE FROM nexoro_crew_members WHERE character_id = ? AND crew_id = ?', { cid, crew.id })
    if affected ~= 1 then return false, 'not_member' end
    local online = core().GetSourceByCharacterId(cid)
    if online then core().Notify(online, ('You have been removed from %s.'):format(crew.name), 'job') end
    return true
end

function C.Disband(src)
    local me = core().GetCharacter(src)
    local crew = me and C.CrewOf(me.id)
    if not crew then return false, 'not_in_crew' end
    if crew.leader_id ~= me.id then return false, 'not_leader' end
    NexoroDB.update('DELETE FROM nexoro_crews WHERE id = ?', { crew.id })
    return true
end

function C.Mine(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local crew = C.CrewOf(c.id)
    if not crew then return true, { crew = nil } end
    local members = NexoroDB.query('SELECT m.character_id AS id, ch.first_name, ch.last_name FROM nexoro_crew_members m JOIN nexoro_characters ch ON ch.id = m.character_id WHERE m.crew_id = ? ORDER BY ch.first_name', { crew.id }) or {}
    for _, m in ipairs(members) do m.name = m.first_name .. ' ' .. m.last_name; m.first_name = nil; m.last_name = nil end
    return true, { crew = { id = crew.id, name = crew.name, leader = crew.leader_id == c.id, members = members } }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_crews:create', function(src, p) return C.Create(src, arg(p, 'name')) end, 5)
    cb('nexoro_crews:invite', function(src, p) return C.Invite(src, arg(p, 'target')) end, 10)
    cb('nexoro_crews:accept', function(src) return C.Accept(src) end, 10)
    cb('nexoro_crews:leave', function(src) return C.Leave(src) end, 10)
    cb('nexoro_crews:kick', function(src, p) return C.Kick(src, arg(p, 'characterId')) end, 10)
    cb('nexoro_crews:disband', function(src) return C.Disband(src) end, 5)
    cb('nexoro_crews:mine', function(src) return C.Mine(src) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function() end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('CrewOf', C.CrewOf)
exports('SameCrew', C.SameCrew)
