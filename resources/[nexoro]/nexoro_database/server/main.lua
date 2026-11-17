local ready = false
local lastError = nil

exports('IsReady', function() return ready end)
exports('GetStatus', function() return { ready = ready, error = lastError } end)

local function waitForConnection()
    local deadline = GetGameTimer() + Config.ConnectTimeoutSeconds * 1000
    while GetGameTimer() < deadline do
        local ok, version = pcall(function() return MySQL.scalar.await('SELECT VERSION()') end)
        if ok and version then return version end
        Wait(1000)
    end
    return nil
end

local function boot()
    ready = false
    local version = waitForConnection()
    if not version then
        lastError = 'could not connect to the database (check oxmysql connection string)'
        print('^1[Nexoro][db] ' .. lastError .. '^7')
        return
    end
    print(('^2[Nexoro][db] connected, server version %s^7'):format(version))

    local ok, applied, err = NexoroMigrations.Run()
    if not ok then
        lastError = err
        print('^1[Nexoro][db] migration failed: ' .. tostring(err) .. '^7')
        print('^1[Nexoro][db] database NOT marked ready; dependent resources will refuse to start.^7')
        return
    end

    lastError = nil
    ready = true
    print(('^2[Nexoro][db] ready (%d new migration(s) applied)^7'):format(applied))
    TriggerEvent('nexoro:database:ready')
end

CreateThread(boot)

-- Console only: re-run migrations after adding a new nexoro_ resource.
RegisterCommand('nexoro_migrate', function(source)
    if source ~= 0 then return end
    CreateThread(boot)
end, true)
