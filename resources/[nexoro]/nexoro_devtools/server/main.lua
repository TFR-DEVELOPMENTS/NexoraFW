local cfg = Config.DevTools
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroDev = {}
local D = NexoroDev

-- Dependencies that tests replace with stand-ins.
D.convar = function(name, default) return GetConvar(name, default) end
D.resourceState = function(name) return GetResourceState(name) end
D.listResources = function()
    local out = {}
    local n = GetNumResources()
    for i = 0, n - 1 do out[#out + 1] = GetResourceByFindIndex(i) end
    return out
end

D.token = nil

function D.Enabled()
    return D.convar(cfg.ConvarName, 'false') == 'true'
end

-- Generates the token the console must send to reset the database. Printed once at startup.
function D.MakeToken()
    if not D.Enabled() then D.token = nil; return nil end
    D.token = tostring(math.random(100000000, 999999999))
    print(('^3[Nexoro dev] Database reset token: %s  (type: nexoro_dbreset %s, then restart)^7'):format(D.token, D.token))
    return D.token
end

-- Player commands: dev mode on and the caller has the dev permission.
function D.Authorised(src)
    if not D.Enabled() then return false, 'dev_mode_off' end
    if src == 0 then return false, 'console' end
    if not core().HasPermission(src, cfg.Permission) then return false, 'not_authorised' end
    return true
end

-- Runs a health check over the database and the resources. Returns a list of results.
-- deps.query(sql, params) -> scalar. deps.resources() -> names of Nexoro resources and their states.
function D.SelfCheck(deps)
    deps = deps or {}
    local results = {}
    local function add(name, ok, detail) results[#results + 1] = { name = name, ok = ok == true, detail = detail or '' } end

    local okDb, pong = pcall(deps.query, 'SELECT 1', {})
    add('database reachable', okDb and pong == 1, okDb and '' or 'could not reach MariaDB')

    for _, t in ipairs(cfg.CoreTables) do
        local okT, n = pcall(deps.query, 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { t })
        add('table ' .. t, okT and n == 1, okT and (n == 1 and '' or 'missing: migrations did not run') or 'query failed')
    end

    local okOwner, owners = pcall(deps.query, "SELECT COUNT(*) FROM nexoro_staff_assignments WHERE rank_name = 'owner'", {})
    add('an owner exists', okOwner and (owners or 0) > 0, okOwner and ((owners or 0) > 0 and '' or 'nobody is owner yet: join, or use /claimowner') or 'query failed')

    local stopped, started = {}, 0
    for _, r in ipairs(deps.resources() or {}) do
        if r.name:sub(1, #cfg.ResourcePrefix) == cfg.ResourcePrefix then
            if r.state == 'started' then started = started + 1 else stopped[#stopped + 1] = r.name .. ' (' .. r.state .. ')' end
        end
    end
    add('Nexoro resources started', #stopped == 0, #stopped == 0 and (started .. ' started') or ('not started: ' .. table.concat(stopped, ', ')))

    local passed = 0
    for _, r in ipairs(results) do if r.ok then passed = passed + 1 end end
    return { passed = passed, total = #results, results = results }
end

-- Drops every Nexoro table. Console only, dev mode only, and only with the token printed at startup.
-- The migrations run again the next time the server starts (restart after a reset).
function D.ResetDatabase(src, token, deps)
    if src ~= 0 then return false, 'console_only' end
    if not D.Enabled() then return false, 'dev_mode_off' end
    if not D.token or tostring(token) ~= D.token then return false, 'wrong_token' end
    deps = deps or {}
    local tables = deps.tables() or {}
    if deps.execute then
        deps.execute('SET FOREIGN_KEY_CHECKS = 0')
        for _, t in ipairs(tables) do deps.execute('DROP TABLE IF EXISTS `' .. t .. '`') end
        deps.execute('SET FOREIGN_KEY_CHECKS = 1')
    end
    D.token = nil
    return true, { dropped = #tables }
end

-- Quick test setup for the player doing the testing: money, items, job and a healthy character.
function D.Give(src, what, amount, account)
    local ok, why = D.Authorised(src)
    if not ok then return false, why end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local n = math.tointeger(tonumber(amount)) or 0
    if what == 'money' then
        if n <= 0 or n > 1000000 then return false, 'invalid_amount' end
        core().AddMoney(src, n, account == 'bank' and 'bank' or 'cash', 'dev give')
        return true
    end
    if what == 'item' then
        if n <= 0 or n > 100 then return false, 'invalid_amount' end
        return exports.nexoro_inventory:AddItem(src, tostring(account), n)
    end
    return false, 'unknown_kind'
end

function D.Teleport(src, name)
    local ok, why = D.Authorised(src)
    if not ok then return false, why end
    local loc = cfg.Locations[name]
    if not loc then return false, 'unknown_location' end
    TriggerClientEvent('nexoro_devtools:teleport', src, { x = loc.x, y = loc.y, z = loc.z })
    return true, { label = loc.label }
end

function D.Heal(src)
    local ok, why = D.Authorised(src)
    if not ok then return false, why end
    TriggerClientEvent('nexoro_devtools:heal', src)
    return true
end

function D.SetJob(src, job, grade)
    local ok, why = D.Authorised(src)
    if not ok then return false, why end
    local g = math.tointeger(tonumber(grade)) or 0
    local okJob, err = core().SetJob(src, tostring(job), g)
    return okJob ~= false, err
end

local function register()
    Core = nil
    D.MakeToken()
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

local function say(src, text, kind)
    if src == 0 then print(text) else TriggerClientEvent('nexoro:notify', src, { message = text, type = kind or 'info' }) end
end

RegisterCommand('devmoney', function(src, args)
    local ok, why = D.Give(src, 'money', args[1], args[2] or 'cash')
    say(src, ok and 'Money added.' or ('Dev: ' .. tostring(why)), ok and 'success' or 'error')
end, false)

RegisterCommand('devitem', function(src, args)
    local ok, why = D.Give(src, 'item', args[2], args[1])
    say(src, ok and 'Item added.' or ('Dev: ' .. tostring(why)), ok and 'success' or 'error')
end, false)

RegisterCommand('devtp', function(src, args)
    local ok, r = D.Teleport(src, args[1])
    say(src, ok and ('Teleported to %s.'):format(r.label) or ('Dev: ' .. tostring(r)), ok and 'success' or 'error')
end, false)

RegisterCommand('devheal', function(src)
    local ok, why = D.Heal(src)
    say(src, ok and 'Healed.' or ('Dev: ' .. tostring(why)), ok and 'success' or 'error')
end, false)

RegisterCommand('devjob', function(src, args)
    local ok, why = D.SetJob(src, args[1], args[2])
    say(src, ok and ('Job set to %s.'):format(args[1] or '?') or ('Dev: ' .. tostring(why)), ok and 'success' or 'error')
end, false)

RegisterCommand('devselfcheck', function(src)
    local ok, why = D.Authorised(src)
    if src ~= 0 and not ok then return say(src, 'Dev: ' .. tostring(why), 'error') end
    local report = D.SelfCheck({
        query = function(sql, params) return NexoroDB.scalar(sql, params) end,
        resources = function()
            local out = {}
            for _, name in ipairs(D.listResources()) do out[#out + 1] = { name = name, state = D.resourceState(name) } end
            return out
        end,
    })
    for _, r in ipairs(report.results) do
        print(('[Nexoro self-check] %s %s %s'):format(r.ok and 'PASS' or 'FAIL', r.name, r.detail))
    end
    say(src, ('Self-check: %d of %d passed. Details are in the server console.'):format(report.passed, report.total), report.passed == report.total and 'success' or 'warning')
end, false)

RegisterCommand('nexoro_dbreset', function(src, args)
    local ok, r = D.ResetDatabase(src, args[1], {
        tables = function()
            local out = {}
            for _, row in ipairs(NexoroDB.query("SHOW TABLES LIKE 'nexoro_%'", {}) or {}) do
                for _, v in pairs(row) do out[#out + 1] = v end
            end
            return out
        end,
        execute = function(sql) NexoroDB.update(sql, {}) end,
    })
    if ok then print(('[Nexoro dev] Dropped %d tables. Restart the server to rebuild the database.'):format(r.dropped))
    else print('[Nexoro dev] Reset refused: ' .. tostring(r)) end
end, true)

exports('Authorised', D.Authorised)
exports('SelfCheck', D.SelfCheck)
