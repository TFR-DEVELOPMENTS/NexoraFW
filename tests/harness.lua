-- Offline test harness: runs the real Nexoro Lua files against a real MariaDB, with FiveM natives stubbed.
local cjson = require('cjson')
cjson.encode_sparse_array(true, 1, 1)

local H = {}
H.root = os.getenv('NEXORO_ROOT') or '.'
H.res = H.root .. '/resources/[nexoro]'
H.socket = os.getenv('NEXORO_TEST_SOCKET') or '/tmp/mdb.sock'
H.dbname = 'nexoro_test'

---------------------------------------------------------------- MariaDB via CLI
local function shell(cmd)
    local p = io.popen(cmd .. ' 2>&1; echo "@@EXIT:$?"')
    local out = p:read('a'); p:close()
    local code = tonumber(out:match('@@EXIT:(%d+)%s*$'))
    return out:gsub('@@EXIT:%d+%s*$', ''), code
end

local function quote(v)
    local t = type(v)
    if t == 'number' then
        assert(v == v and v ~= math.huge and v ~= -math.huge, 'non-finite number in SQL params')
        if math.type(v) == 'integer' then return tostring(v) end
        return string.format('%.17g', v)
    end
    if t == 'boolean' then return v and '1' or '0' end
    if t == 'nil' then return 'NULL' end
    local s = tostring(v):gsub('\\', '\\\\'):gsub("'", "\\'"):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('%z', '\\0')
    return "'" .. s .. "'"
end

local function bind(sql, params)
    params = params or {}
    local i, n = 0, 0
    for _ in pairs(params) do n = n + 1 end
    local out = sql:gsub('%?', function()
        i = i + 1
        return quote(params[i])
    end)
    assert(i == n or i == #params, ('param count mismatch (%d placeholders, %d params): %s'):format(i, n, sql:sub(1, 80)))
    return out
end

local function run(sql)
    local f = io.open('/tmp/nexoro_test.sql', 'w'); f:write(sql); f:close()
    return shell(('mariadb -S %s -D %s -B --raw < /tmp/nexoro_test.sql'):format(H.socket, H.dbname))
end

local function parse(out)
    local rows, header = {}, nil
    for line in out:gmatch('[^\n]+') do
        local cols = {}
        for field in (line .. '\t'):gmatch('(.-)\t') do cols[#cols + 1] = field end
        if not header then header = cols
        else
            local row = {}
            for i, name in ipairs(header) do
                local v = cols[i]
                if v == 'NULL' then v = nil
                elseif v and v:match('^%-?%d+$') and #v < 16 and not v:match('^0%d') then v = math.tointeger(tonumber(v))
                elseif v and v:match('^%-?%d+%.%d+$') then v = tonumber(v) end
                row[name] = v
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function failed(out, code) return code ~= 0 or out:match('^ERROR') ~= nil end

H.DB = {}
function H.DB.query(sql, params)
    local out, code = run(bind(sql, params))
    if failed(out, code) then return nil, out end
    return parse(out)
end
function H.DB.single(sql, params) local r, e = H.DB.query(sql, params); if not r then return nil, e end return r[1] end
function H.DB.scalar(sql, params)
    local r, e = H.DB.query(sql, params)
    if not r then return nil, e end
    local row = r[1]; if not row then return nil end
    for _, v in pairs(row) do return v end
end
function H.DB.update(sql, params)
    local out, code = run(bind(sql, params) .. '; SELECT ROW_COUNT() AS n')
    if failed(out, code) then return nil, out end
    return parse(out)[1].n
end
function H.DB.insert(sql, params)
    local out, code = run(bind(sql, params) .. '; SELECT LAST_INSERT_ID() AS n')
    if failed(out, code) then return nil, out end
    return parse(out)[1].n
end
function H.DB.transaction(queries)
    local parts = { 'START TRANSACTION;' }
    for _, q in ipairs(queries) do parts[#parts + 1] = bind(q.query, q.values) .. ';' end
    parts[#parts + 1] = 'COMMIT;'
    local out, code = run(table.concat(parts, '\n'))
    return not failed(out, code)
end
function H.DB.IsReady() return true end
function H.DB.WaitReady() return true end

function H.resetDatabase()
    shell(('mariadb -S %s -e "DROP DATABASE IF EXISTS %s; CREATE DATABASE %s CHARACTER SET utf8mb4"'):format(H.socket, H.dbname, H.dbname))
end

---------------------------------------------------------------- FiveM stubs
H.events = { net = {}, handlers = {} }
H.sent = {}      -- TriggerClientEvent log
H.localEvents = {}
H.dropped = {}
H.registry = {}  -- exports registry
H.clock = 0
function H.advance(ms) H.clock = H.clock + ms end

local function makeExports(resName)
    return setmetatable({}, {
        __call = function(_, name, fn) H.registry[resName] = H.registry[resName] or {}; H.registry[resName][name] = fn end,
        __index = function(_, other)
            return setmetatable({}, { __index = function(_, fn)
                return function(_, ...)
                    local r = H.registry[other]
                    if not r or not r[fn] then error(('export %s:%s not registered'):format(other, fn)) end
                    return r[fn](...)
                end
            end })
        end,
    })
end

function H.newEnv(resName)
    local env = setmetatable({}, { __index = _G })
    env.exports = makeExports(resName)
    env.json = { encode = cjson.encode, decode = cjson.decode }
    env.GetCurrentResourceName = function() return resName end
    return env
end

H.players = {}  -- [src] = { name, identifiers }
function H.addPlayerStub(src, name, identifiers) H.players[src] = { name = name, identifiers = identifiers } end

local function installGlobals()
    _G.GetGameTimer = function() H.clock = H.clock + 1; return H.clock end
    _G.Wait = function() end
    _G.CreateThread = function() end
    _G.SetTimeout = function() end
    _G.RegisterNetEvent = function(name, fn) if fn then H.events.net[name] = fn end end
    _G.AddEventHandler = function(name, fn) H.events.handlers[name] = H.events.handlers[name] or {}; table.insert(H.events.handlers[name], fn) end
    _G.RegisterCommand = function() end
    _G.TriggerEvent = function(name, ...) H.localEvents[#H.localEvents + 1] = { name, ... } end
    _G.TriggerClientEvent = function(name, target, ...) H.sent[#H.sent + 1] = { name = name, target = target, args = table.pack(...) } end
    _G.DropPlayer = function(src, reason) H.dropped[#H.dropped + 1] = { src, reason } end
    _G.IsPlayerAceAllowed = function() return false end
    H.coords = {}
    H.resourceCalls = {}
    _G.GetPlayerPed = function(src) return H.coords[src] and (1000 + src) or 0 end
    _G.DoesEntityExist = function(e) return e ~= 0 end
    _G.GetEntityCoords = function(e) local c = H.coords[e - 1000]; return { x = c.x, y = c.y, z = c.z } end
    _G.SetEntityCoords = function(e, x, y, z) H.coords[e - 1000] = { x = x, y = y, z = z } end
    _G.GetPlayerPing = function() return 42 end
    _G.GetHashKey = function(str) local h = 5381 for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end return h end
    _G.GetConvarInt = function(_, default) return default end
    H.convars = H.convars or {}
    _G.GetConvar = function(name, default) return H.convars[name] or default end
    _G.StopResource = function(n) H.resourceCalls[#H.resourceCalls + 1] = 'stop:' .. n end
    _G.StartResource = function(n) H.resourceCalls[#H.resourceCalls + 1] = 'start:' .. n end
    _G.GetResourceState = function(name) return H.resourceStates and H.resourceStates[name] or 'started' end
    _G.GetNumResources = function() return 0 end
    _G.GetResourceByFindIndex = function() return nil end
    _G.SetPlayerRoutingBucket = function() end
    _G.GetPlayerName = function(src) return H.players[src] and H.players[src].name end
    _G.GetNumPlayerIdentifiers = function(src) return #H.players[src].identifiers end
    _G.GetPlayerIdentifier = function(src, i) return H.players[src].identifiers[i + 1] end
    _G.Player = function() return { state = { set = function() end } } end
    _G.LoadResourceFile = function(res, path)
        local f = io.open(('%s/%s/%s'):format(H.res, res, path), 'rb')
        if not f then return nil end
        local data = f:read('a'); f:close(); return data
    end
    _G.print = function(...) if os.getenv('NEXORO_TEST_VERBOSE') then io.write(table.concat({ ... }, ' '), '\n') end end
end
installGlobals()

function H.loadFiles(env, resName, files)
    for _, file in ipairs(files) do
        local path = ('%s/%s/%s'):format(H.res, resName, file)
        local f = assert(io.open(path, 'rb'), 'missing ' .. path)
        local chunk, err = load(f:read('a'), '@' .. path, 't', env)
        f:close()
        assert(chunk, err)
        chunk()
    end
end

-- Simulate a client callback request through the real core event handler.
function H.callServer(src, name, ...)
    H.sent = {}
    _G.source = src
    local reqId = (H.reqId or 0) + 1
    H.reqId = reqId
    H.events.net['nexoro:server:callback'](name, reqId, ...)
    for _, e in ipairs(H.sent) do
        if e.name == 'nexoro:client:callback' and e.target == src and e.args[1] == reqId then
            return table.unpack(e.args, 2, e.args.n)
        end
    end
    return 'NO_REPLY'
end

function H.fireNet(src, name, ...)
    _G.source = src
    if H.events.net[name] then H.events.net[name](...) end
end

function H.fireHandlers(src, name, ...)
    _G.source = src
    for _, fn in ipairs(H.events.handlers[name] or {}) do fn(...) end
end

-- Tiny assertion library
H.passed, H.failed, H.current = 0, 0, ''
function H.section(name) H.current = name; io.write('\n== ' .. name .. '\n') end
function H.check(cond, label, detail)
    label = label or ('(unlabelled check at ' .. (debug.getinfo(2, 'l') or {}).currentline .. ')')
    if cond then H.passed = H.passed + 1; io.write('  ok   ' .. label .. '\n')
    else H.failed = H.failed + 1; io.write('  FAIL ' .. label .. (detail and ('  -> ' .. tostring(detail)) or '') .. '\n') end
end
function H.eq(actual, expected, label)
    H.check(actual == expected, label, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end
return H
