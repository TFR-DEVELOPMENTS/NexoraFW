-- Nexoro database helper.
-- Include in any nexoro_* resource manifest:
--   server_scripts { '@oxmysql/lib/MySQL.lua', '@nexoro_database/lib/db.lua', ... }
-- Every query MUST use "?" placeholders. Never concatenate user input into SQL.

NexoroDB = NexoroDB or {}

local SLOW_QUERY_MS = 200

local function run(kind, sql, params)
    local started = GetGameTimer()
    local ok, result = pcall(function()
        return MySQL[kind].await(sql, params or {})
    end)
    local took = GetGameTimer() - started
    if took >= SLOW_QUERY_MS then
        print(('^3[Nexoro][db] slow query (%d ms): %s^7'):format(took, sql:sub(1, 120)))
    end
    if not ok then
        print(('^1[Nexoro][db] query failed: %s | %s^7'):format(tostring(result), sql:sub(1, 160)))
        return nil, tostring(result)
    end
    return result
end

function NexoroDB.query(sql, params) return run('query', sql, params) end
function NexoroDB.single(sql, params) return run('single', sql, params) end
function NexoroDB.scalar(sql, params) return run('scalar', sql, params) end
function NexoroDB.insert(sql, params) return run('insert', sql, params) end   -- returns insertId
function NexoroDB.update(sql, params) return run('update', sql, params) end   -- returns affected rows

-- queries = { { query = 'SQL ?', values = { ... } }, ... }  -> true on commit, false on rollback
function NexoroDB.transaction(queries)
    local ok, result = pcall(function()
        return MySQL.transaction.await(queries)
    end)
    if not ok then
        print(('^1[Nexoro][db] transaction failed: %s^7'):format(tostring(result)))
        return false, tostring(result)
    end
    return result == true
end

function NexoroDB.IsReady()
    local ok, ready = pcall(function() return exports.nexoro_database:IsReady() end)
    return ok and ready == true
end

function NexoroDB.WaitReady(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 60000)
    while not NexoroDB.IsReady() do
        if GetGameTimer() > deadline then return false end
        Wait(100)
    end
    return true
end
