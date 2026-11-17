local cfg = Config.Tablet
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroTablet = {}
local T = NexoroTablet

local function started(res) return GetResourceState(res) == 'started' end

local function appAllowed(src, app)
    if app.unit then
        return started('nexoro_dispatch') and exports.nexoro_dispatch:IsUnit(src) == true
    end
    return app.perm ~= nil and exports.nexoro_emergency:HasPerm(src, app.perm, false)
end

local function hasTablet(src)
    local ok, has = pcall(function() return exports.nexoro_inventory:HasItem(src, cfg.Item, 1) end)
    return ok and has == true
end

-- Apps this player may open, in a stable order.
function T.Apps(src)
    if not hasTablet(src) then return false, 'no_tablet' end
    local out = {}
    for id, app in pairs(cfg.Apps) do
        if appAllowed(src, app) then out[#out + 1] = { id = id, label = app.label } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    if #out == 0 then return false, 'forbidden' end
    return true, out
end

-- Runs one callback on behalf of the tablet. The app must allow both the app and the call.
function T.Relay(src, appId, call, payload)
    if not hasTablet(src) then return false, 'no_tablet' end
    local app = type(appId) == 'string' and cfg.Apps[appId]
    if not app then return false, 'unknown_app' end
    if not appAllowed(src, app) then return false, 'forbidden' end
    local allowed = false
    for _, c in ipairs(app.calls) do if c == call then allowed = true end end
    if not allowed then return false, 'call_not_in_app' end
    local ok, a, b = pcall(core().InvokeCallback, call, src, payload)
    if not ok then
        print(('^1[Nexoro][tablet] relay %s failed: %s^7'):format(tostring(call), tostring(a)))
        return false, 'server_error'
    end
    return a, b
end

local function register()
    Core = nil
    local C = core()
    C.RegisterCallback('nexoro_tablet:apps', function(src) return T.Apps(src) end,
        { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
    C.RegisterCallback('nexoro_tablet:relay', function(src, p)
        p = type(p) == 'table' and p or {}
        return T.Relay(src, p.app, p.call, p.payload)
    end, { requireCharacter = true, rateLimit = { max = 60, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Apps', T.Apps)
exports('Relay', T.Relay)
