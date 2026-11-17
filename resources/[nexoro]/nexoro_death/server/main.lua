local cfg = Config.Death
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroDeath = {}
local X = NexoroDeath
-- Server-side death check. Overridable in tests.
X.isDead = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return IsPedDeadOrDying(ped, true)
end
X.now = os.time

local downed = {}     -- [src] = server time the player went down

-- Called by the client when it sees the player go down. The server only accepts it if the ped really is dead.
function X.Report(src)
    if not core().GetCharacter(src) then return false, 'no_character' end
    if downed[src] then return true, { startedAt = downed[src], seconds = cfg.BleedOutSeconds } end
    if not X.isDead(src) then return false, 'not_dead' end
    downed[src] = X.now()
    core().Log('medical', 'downed', src, {})
    return true, { startedAt = downed[src], seconds = cfg.BleedOutSeconds }
end

-- Lets a downed player respawn once the bleed-out time has really passed, measured on the server.
function X.Bleedout(src)
    local started = downed[src]
    if not started then return false, 'not_downed' end
    if X.now() - started < cfg.BleedOutSeconds - cfg.Tolerance then return false, 'too_early' end
    downed[src] = nil
    if not X.isDead(src) then return false, 'not_dead' end
    core().Log('medical', 'bleedout', src, {})
    return true
end

-- Emergency services revive, or anything else that ends the downed state.
function X.Clear(src) downed[src] = nil end
function X.IsDowned(src) return downed[src] ~= nil end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
    end
    cb('nexoro_death:report', function(src) return X.Report(src) end)
    cb('nexoro_death:bleedout', function(src) return X.Bleedout(src) end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:characterUnloaded', function(src) downed[src] = nil end)
AddEventHandler('nexoro:server:playerDropped', function(src) downed[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Clear', X.Clear)
exports('IsDowned', X.IsDowned)
