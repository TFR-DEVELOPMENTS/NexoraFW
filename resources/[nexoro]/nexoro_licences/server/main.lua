local cfg = Config.Licences
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroLicences = {}
local L = NexoroLicences
L.now = os.time
L.random = function(n) return math.random(1, n) end
L.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local sessions = {}   -- [src] = { answers = {correct indices}, questions = {...} }

local function atOffice(src)
    local p = L.getCoords(src)
    if not p then return false end
    local o = cfg.Office
    return math.sqrt((p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2) <= o.radius + 2.0
end

function L.Has(characterId, kind)
    return NexoroDB.scalar('SELECT 1 FROM nexoro_licences WHERE character_id = ? AND kind = ?', { characterId, kind }) ~= nil
end

local function grant(characterId, kind)
    NexoroDB.update('INSERT IGNORE INTO nexoro_licences (character_id, kind, issued_at) VALUES (?,?,?)', { characterId, kind, L.now() })
end

-- Fishing licence: bought outright at the office.
-- Buys a simple licence (fishing or hunting) at the office.
function L.BuySimple(src, kind)
    -- weapon is not here: it has its own purchase with the criminal record check.
    local defs = { fishing = cfg.Fishing, hunting = cfg.Hunting }
    local def = defs[kind]
    if not def then return false, 'unknown_licence' end
    if not atOffice(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if L.Has(c.id, kind) then return false, 'already_licensed' end
    local ok, why = core().RemoveMoney(src, def.feePounds, 'bank', kind .. ' licence')
    if not ok then return false, why end
    grant(c.id, kind)
    core().Log('licences', kind .. '_bought', src, {})
    return true, { fee = core().FormatGBP(core().ToPence(def.feePounds)) }
end

function L.BuyFishing(src) return L.BuySimple(src, 'fishing') end
function L.BuyHunting(src) return L.BuySimple(src, 'hunting') end

-- Starts a driving test: takes the fee and picks the questions. Answers are kept on the server.
function L.ApplyDriving(src)
    if not atOffice(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if L.Has(c.id, 'driving') then return false, 'already_licensed' end
    local ok, why = core().RemoveMoney(src, cfg.Driving.feePounds, 'bank', 'driving test')
    if not ok then return false, why end
    local pool = {}
    for i, q in ipairs(cfg.Driving.bank) do pool[i] = i end
    local picked, questions, correct = {}, {}, {}
    for _ = 1, cfg.Driving.questionsPerTest do
        local k = L.random(#pool)
        local idx = table.remove(pool, k)
        picked[#picked + 1] = idx
        local q = cfg.Driving.bank[idx]
        questions[#questions + 1] = { q = q.q, options = q.options }
        correct[#correct + 1] = q.answer
    end
    sessions[src] = { correct = correct }
    return true, { questions = questions }
end

function L.SubmitDriving(src, answers)
    local s = sessions[src]
    if not s then return false, 'no_test' end
    if type(answers) ~= 'table' then return false, 'invalid_answers' end
    local score = 0
    for i, want in ipairs(s.correct) do
        local a = math.tointeger(tonumber(answers[i]))
        if a == want then score = score + 1 end
    end
    sessions[src] = nil
    local c = core().GetCharacter(src)
    if score >= cfg.Driving.passMark then
        grant(c.id, 'driving')
        local okAdd = exports.nexoro_inventory:AddItem(src, cfg.Driving.item, 1)
        core().Log('licences', 'driving_passed', src, { score = score })
        return true, { passed = true, score = score, of = #s.correct, card = okAdd == true }
    end
    core().Log('licences', 'driving_failed', src, { score = score })
    return true, { passed = false, score = score, of = #s.correct }
end

-- Weapon licence: refused to anyone with an arrest on record (fines do not count).
function L.BuyWeapon(src)
    if not atOffice(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if L.Has(c.id, 'weapon') then return false, 'already_licensed' end
    local arrests = NexoroDB.scalar("SELECT COUNT(*) FROM nexoro_police_records WHERE character_id = ? AND kind = 'arrest'", { c.id }) or 0
    if arrests > 0 then return false, 'criminal_record' end
    local ok, why = core().RemoveMoney(src, cfg.Weapon.feePounds, 'bank', 'weapon licence')
    if not ok then return false, why end
    grant(c.id, 'weapon')
    core().Log('licences', 'weapon_bought', src, {})
    return true, { fee = core().FormatGBP(core().ToPence(cfg.Weapon.feePounds)) }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_licences:buyFishing', function(src) return L.BuyFishing(src) end, 5)
    cb('nexoro_licences:buyHunting', function(src) return L.BuyHunting(src) end, 5)
    cb('nexoro_licences:buyWeapon', function(src) return L.BuyWeapon(src) end, 5)
    cb('nexoro_licences:applyDriving', function(src) return L.ApplyDriving(src) end, 5)
    cb('nexoro_licences:submitDriving', function(src, p) return L.SubmitDriving(src, arg(p, 'answers')) end, 5)
    cb('nexoro_licences:mine', function(src)
        local c = core().GetCharacter(src)
        if not c then return false, 'no_character' end
        return true, { driving = L.Has(c.id, 'driving'), fishing = L.Has(c.id, 'fishing'), hunting = L.Has(c.id, 'hunting'), weapon = L.Has(c.id, 'weapon') }
    end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src) sessions[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Has', L.Has)
