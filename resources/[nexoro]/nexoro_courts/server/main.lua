local cfg = Config.Courts
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroCourts = {}
local K = NexoroCourts
K.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function atOffice(src)
    local p = K.getCoords(src)
    if not p then return false end
    local o = cfg.Office
    return math.sqrt((p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2) <= o.radius + 2.0
end

-- Every penalty notice you have not paid yet. Works from anywhere: fines can be paid by phone.
function K.Fines(src)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local rows = NexoroDB.query(
        "SELECT id, detail, amount_pence, officer, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM nexoro_police_records WHERE character_id = ? AND kind = 'fine' AND status = 'outstanding' ORDER BY id",
        { c.id }) or {}
    local total = 0
    for _, r in ipairs(rows) do
        total = total + r.amount_pence
        r.amount = core().FormatGBP(r.amount_pence)
        r.amount_pence = nil
    end
    return true, { fines = rows, total = core().FormatGBP(total) }
end

function K.Pay(src, recordId, account)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local id = math.tointeger(tonumber(recordId))
    if not id then return false, 'invalid_request' end
    local row = NexoroDB.single("SELECT id, character_id, amount_pence, status FROM nexoro_police_records WHERE id = ? AND kind = 'fine'", { id })
    if not row or row.character_id ~= c.id then return false, 'not_found' end
    if row.status ~= 'outstanding' then return false, 'not_outstanding' end
    local acct = account == 'cash' and 'cash' or 'bank'
    local ok, why = core().RemoveMoney(src, row.amount_pence / 100, acct, 'fine paid: ' .. id)
    if not ok then return false, why end
    local affected = NexoroDB.update("UPDATE nexoro_police_records SET status = 'paid' WHERE id = ? AND status = 'outstanding'", { id })
    if affected ~= 1 then
        core().AddMoney(src, row.amount_pence / 100, acct, 'refund: fine already paid')
        return false, 'not_outstanding'
    end
    return true, { paid = core().FormatGBP(row.amount_pence) }
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_courts:fines', function(src) return K.Fines(src) end)
    cb('nexoro_courts:pay', function(src, p)
        if not atOffice(src) and not (type(p) == 'table' and p.byPhone == true) then return false, 'too_far' end
        return K.Pay(src, arg(p, 'id'), arg(p, 'account'))
    end, 10)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Fines', K.Fines)
exports('Pay', K.Pay)
