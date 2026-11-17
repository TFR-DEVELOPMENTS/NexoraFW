local cfg = Config.Scratch
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroScratch = {}
local S = NexoroScratch
S.random = function(n) return math.random(1, n) end
S.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function atCounter(src)
    local p = S.getCoords(src)
    if not p then return false end
    local o = cfg.Counter
    return math.sqrt((p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2) <= o.radius + 2.0
end

-- Rolls the prize from the weighted table.
function S.Roll()
    local total = 0
    for _, p in ipairs(cfg.Prizes) do total = total + p.weight end
    local roll = S.random(total)
    local acc = 0
    for _, p in ipairs(cfg.Prizes) do
        acc = acc + p.weight
        if roll <= acc then return p.prize end
    end
    return cfg.Prizes[#cfg.Prizes].prize
end

function S.Buy(src)
    if not atCounter(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local stake = core().ToPence(cfg.PricePounds)
    local ok, why = exports.nexoro_gambling:Reserve(c.id, stake)
    if not ok then return false, why end
    local took, tw = core().RemoveMoney(src, stake / 100, 'cash', 'scratchcard')
    if not took then exports.nexoro_gambling:Release(c.id, stake); return false, tw end
    local prize = S.Roll()
    local won = core().ToPence(prize)
    if won > 0 then core().AddMoney(src, won / 100, 'cash', 'scratchcard win') end
    core().Log('scratch', 'played', src, { prize = prize })
    return true, { prize = prize, won = core().FormatGBP(won), stake = core().FormatGBP(stake) }
end

local function register()
    Core = nil
    core().RegisterCallback('nexoro_scratch:buy', function(src)
        return S.Buy(src)
    end, { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Buy', S.Buy)
