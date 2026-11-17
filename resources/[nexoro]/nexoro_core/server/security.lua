Nexoro = Nexoro or {}
Nexoro.Security = {}

local buckets = {}
local violations = {}

-- Fixed-window limiter. Returns true while the player is under the limit.
function Nexoro.Security.RateLimit(src, key, max, windowMs)
    if src == 0 then return true end
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket then bucket = {}; buckets[src] = bucket end
    local entry = bucket[key]
    if not entry or now >= entry.resetAt then
        bucket[key] = { count = 1, resetAt = now + windowMs }
        return true
    end
    entry.count = entry.count + 1
    return entry.count <= max
end

function Nexoro.Security.Violation(src, reason)
    violations[src] = (violations[src] or 0) + 1
    Nexoro.Log('security', 'violation', src, { reason = reason, count = violations[src] })
    if violations[src] >= Config.Security.ViolationsBeforeKick then
        DropPlayer(src, 'Nexoro: too many invalid requests.')
    end
end

function Nexoro.Security.Clear(src)
    buckets[src] = nil
    violations[src] = nil
end

-- Registers a net event that only runs for a loaded player, is rate limited and cannot crash the server.
-- opts = { rateLimit = {max, windowMs}, requireCharacter = bool, permission = 'nexoro.x.y' }
function Nexoro.RegisterSecureEvent(name, opts, handler)
    opts = opts or {}
    RegisterNetEvent(name, function(...)
        local src = source
        local player = Nexoro.Players[src]
        if not player then return end
        local rl = opts.rateLimit or { max = 10, windowMs = 5000 }
        if not Nexoro.Security.RateLimit(src, 'ev:' .. name, rl.max, rl.windowMs) then
            Nexoro.Security.Violation(src, 'rate_limit:' .. name)
            return
        end
        if opts.requireCharacter and not player.character then return end
        if opts.permission and not Nexoro.Permissions.Has(src, opts.permission) then
            Nexoro.Security.Violation(src, 'forbidden:' .. name)
            return
        end
        local ok, err = pcall(handler, src, ...)
        if not ok then print(('^1[Nexoro] error in event %s: %s^7'):format(name, tostring(err))) end
    end)
end
