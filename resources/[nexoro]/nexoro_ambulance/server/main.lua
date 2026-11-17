local cfg = Config.Ambulance
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroAmbulance = {}
local A = NexoroAmbulance
A.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
A.isDead = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return IsPedDeadOrDying(ped, true)
end
A.now = os.time

local lastRevive = {}

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

local function near(src, t)
    local a, b = A.getCoords(src), A.getCoords(t)
    if not a or not b then return false end
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) <= cfg.InteractDistance
end

local function targetOf(target)
    local t = toInt(target)
    if not t or not core().GetCharacter(t) then return nil, 'target_not_found' end
    return t
end

local function record(src, kind, characterId, detail)
    return NexoroDB.insert('INSERT INTO nexoro_medical_records (character_id, kind, detail, staff) VALUES (?,?,?,?)',
        { characterId, kind, (detail or ''):sub(1, 300), staffName(src):sub(1, 100) })
end

function A.Revive(src, target)
    if not can(src, 'medical.revive') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if t == src then return false, 'cannot_target_self' end
    if not near(src, t) then return false, 'too_far' end
    local now = A.now()
    if lastRevive[t] and now - lastRevive[t] < cfg.ReviveCooldownSeconds then return false, 'recently_revived' end
    if not A.isDead(t) then return false, 'target_not_dead' end
    lastRevive[t] = now
    pcall(function() exports.nexoro_death:Clear(t) end)   -- ends the bleed-out timer
    TriggerClientEvent('nexoro_ambulance:revive', t, { health = cfg.ReviveHealth })
    record(src, 'revive', core().GetCharacter(t).id, 'Revived on scene')
    core().Log('medical', 'revive', src, { target = t })
    return true
end

-- Uses one bandage from the responder's own inventory.
function A.Bandage(src, target)
    if not can(src, 'medical.treat') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not near(src, t) then return false, 'too_far' end
    local ok, err = exports.nexoro_inventory:RemoveItem(src, 'bandage', 1)
    if not ok then return false, err == 'not_enough' and 'no_supplies' or err end
    TriggerClientEvent('nexoro:client:heal', t, cfg.BandageHeal)
    record(src, 'treatment', core().GetCharacter(t).id, 'Bandaged')
    return true
end

function A.Assess(src, target, notes)
    if not can(src, 'medical.treat') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    if not near(src, t) then return false, 'too_far' end
    local text = cleanText(notes, 3, 300)
    if not text then return false, 'invalid_notes' end
    local id = record(src, 'assessment', core().GetCharacter(t).id, text)
    return true, { recordId = id }
end

local function hospitalNear(pos)
    for _, h in ipairs(cfg.Hospitals) do
        if math.sqrt((pos.x - h.x) ^ 2 + (pos.y - h.y) ^ 2 + (pos.z - h.z) ^ 2) <= h.radius then return h end
    end
    return nil
end

function A.Admit(src, target, ward)
    if not can(src, 'medical.admit') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    local pos = A.getCoords(t)
    if not pos or not hospitalNear(pos) then return false, 'not_at_hospital' end
    local wardOk = false
    for _, w in ipairs(cfg.Wards) do if w == ward then wardOk = true end end
    if not wardOk then return false, 'invalid_ward' end
    if core().GetMetadata(t, 'admitted') then return false, 'already_admitted' end
    local billed = false
    if cfg.BillPatients then
        local ok = core().RemoveMoney(t, cfg.AdmissionFeePounds, 'bank', 'hospital admission')
        billed = ok == true
    end
    core().SetMetadata(t, 'admitted', ward)
    record(src, 'admission', core().GetCharacter(t).id, ward .. (cfg.BillPatients and (billed and ' - billed' or ' - unpaid') or ''))
    core().Log('medical', 'admit', src, { target = t, ward = ward })
    return true, { ward = ward, billed = billed }
end

function A.Discharge(src, target)
    if not can(src, 'medical.admit') then return false, 'forbidden' end
    local t, why = targetOf(target)
    if not t then return false, why end
    local ward = core().GetMetadata(t, 'admitted')
    if not ward then return false, 'not_admitted' end
    core().SetMetadata(t, 'admitted', nil)
    record(src, 'discharge', core().GetCharacter(t).id, 'Discharged from ' .. tostring(ward))
    return true
end

function A.Records(src, citizenId)
    if not can(src, 'medical.mdt') then return false, 'forbidden' end
    if not exports.nexoro_identity:IsValidCitizenId(citizenId) then return false, 'invalid_citizen_id' end
    local row = NexoroDB.single('SELECT id, first_name, last_name FROM nexoro_characters WHERE citizen_id = ?', { citizenId })
    if not row then return false, 'citizen_not_found' end
    return true, {
        name = row.first_name .. ' ' .. row.last_name,
        records = NexoroDB.query("SELECT kind, detail, staff, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date FROM nexoro_medical_records WHERE character_id = ? ORDER BY id DESC LIMIT 30", { row.id }) or {},
    }
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 40, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_ambulance:revive', function(src, p) return A.Revive(src, arg(p, 'target')) end, 20)
    cb('nexoro_ambulance:bandage', function(src, p) return A.Bandage(src, arg(p, 'target')) end, 20)
    cb('nexoro_ambulance:assess', function(src, p) return A.Assess(src, arg(p, 'target'), arg(p, 'notes')) end, 20)
    cb('nexoro_ambulance:admit', function(src, p) return A.Admit(src, arg(p, 'target'), arg(p, 'ward')) end, 10)
    cb('nexoro_ambulance:discharge', function(src, p) return A.Discharge(src, arg(p, 'target')) end, 10)
    cb('nexoro_ambulance:records', function(src, p) return A.Records(src, arg(p, 'citizenId')) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Revive', A.Revive)
exports('Admit', A.Admit)
exports('Discharge', A.Discharge)
