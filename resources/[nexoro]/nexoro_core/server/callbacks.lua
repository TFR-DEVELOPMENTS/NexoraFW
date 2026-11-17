Nexoro = Nexoro or {}
Nexoro.Callbacks = {}

-- handler(source, ...) must return (ok, dataOrErrorCode). Runs server-side only.
-- opts = { rateLimit = {max, windowMs}, requireCharacter = bool, permission = 'nexoro.x.y' }
function Nexoro.RegisterCallback(name, handler, opts)
    Nexoro.Callbacks[name] = { handler = handler, opts = opts or {} }
end

local function fail(src, reqId, code)
    TriggerClientEvent('nexoro:client:callback', src, reqId, false, code)
end

RegisterNetEvent('nexoro:server:callback', function(name, reqId, ...)
    local src = source
    if type(name) ~= 'string' or #name > 64 or type(reqId) ~= 'number' then
        return Nexoro.Security.Violation(src, 'malformed_callback')
    end

    local entry = Nexoro.Callbacks[name]
    if not entry then return fail(src, reqId, 'unknown_callback') end

    local rl = entry.opts.rateLimit or Config.Security.CallbackRateLimit
    if not Nexoro.Security.RateLimit(src, 'cb:' .. name, rl.max, rl.windowMs) then
        Nexoro.Security.Violation(src, 'rate_limit:' .. name)
        return fail(src, reqId, 'rate_limited')
    end

    local player = Nexoro.Players[src]
    if not player then return fail(src, reqId, 'no_player') end
    if entry.opts.requireCharacter and not player.character then return fail(src, reqId, 'no_character') end
    if entry.opts.permission and not Nexoro.Permissions.Has(src, entry.opts.permission) then
        Nexoro.Security.Violation(src, 'forbidden:' .. name)
        return fail(src, reqId, 'forbidden')
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return table.pack(entry.handler(src, table.unpack(args, 1, args.n)))
    end)
    if not ok then
        print(('^1[Nexoro] callback %s failed: %s^7'):format(name, tostring(result)))
        return fail(src, reqId, 'server_error')
    end
    TriggerClientEvent('nexoro:client:callback', src, reqId, table.unpack(result, 1, result.n))
end)

-- Runs a registered callback for a trusted server-side caller (the tablet relay).
-- Keeps requireCharacter and permission checks. Rate limiting is the caller's job.
function Nexoro.InvokeCallback(name, src, ...)
    local entry = Nexoro.Callbacks[name]
    if not entry then return false, 'unknown_callback' end
    local player = Nexoro.Players[src]
    if not player then return false, 'no_player' end
    if entry.opts.requireCharacter and not player.character then return false, 'no_character' end
    if entry.opts.permission and not Nexoro.Permissions.Has(src, entry.opts.permission) then return false, 'forbidden' end
    return entry.handler(src, ...)
end
