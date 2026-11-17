Nexoro.Notify = function(src, text, kind, ms) TriggerClientEvent('nexoro:client:notify', src, { message = tostring(text), type = kind or 'info', duration = ms or 5000 }) end
local cfg = Config.Framework

local function missingDependencies()
    local missing = {}
    for _, resource in ipairs(cfg.RequiredResources) do
        if GetResourceState(resource) ~= 'started' then missing[#missing + 1] = resource end
    end
    return missing
end

CreateThread(function()
    print(('^3[Nexoro] %s %s starting...^7'):format(cfg.Name, cfg.Version))
    local missing = missingDependencies()
    if #missing > 0 then
        print(('^1[Nexoro] cannot start. Missing or stopped resources: %s^7'):format(table.concat(missing, ', ')))
        print('^1[Nexoro] ensure them BEFORE nexoro_core in server.cfg.^7')
        return
    end
    if not NexoroDB.WaitReady(60000) then
        print('^1[Nexoro] database did not become ready within 60s (see nexoro_database output). Players cannot join.^7')
        return
    end

    Nexoro.LoadJobs()
    Nexoro.Ready = true
    Nexoro.InitClaimCode()
    for _, id in ipairs(GetPlayers()) do Nexoro.RecoverPlayer(tonumber(id)) end
    TriggerEvent('nexoro:core:ready')
    print('^2[Nexoro] core ready.^7')

    -- Autosave, staggered so saves never spike the database.
    while true do
        Wait(cfg.AutosaveMinutes * 60 * 1000)
        for src, player in pairs(Nexoro.Players) do
            if player.character then Nexoro.SavePlayer(src) end
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(Nexoro.Players) do Nexoro.SavePlayer(src) end
    Nexoro.FlushLogs()
end)

-- Session state used by client resources after a restart.
Nexoro.RegisterCallback('nexoro_core:getSessionState', function(src)
    local player = Nexoro.Players[src]
    return true, { characterLoaded = player.character ~= nil, character = Nexoro.PublicCharacter(src) }
end, { rateLimit = { max = 5, windowMs = 10000 } })

-- Console-only administration. Bootstrap the first owner with: nexoro_setrank <serverId> owner
RegisterCommand('nexoro_setrank', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args[1])
    local rank = args[2]
    if not target or not Nexoro.Players[target] then return print('usage: nexoro_setrank <serverId> <rank|none>') end
    if rank == 'none' then rank = nil end
    local ok, err = Nexoro.Permissions.SetRank(target, rank, 'console')
    print(ok and 'rank updated' or ('failed: ' .. tostring(err)))
end, true)

RegisterCommand('nexoro_status', function(source)
    if source ~= 0 then return end
    local count, loaded = 0, 0
    for _, p in pairs(Nexoro.Players) do count = count + 1; if p.character then loaded = loaded + 1 end end
    print(('Nexoro %s | ready=%s | players=%d | characters loaded=%d'):format(cfg.Version, tostring(Nexoro.Ready), count, loaded))
end, true)

-- Plain-English health check for server owners. Console only: nexoro_doctor
RegisterCommand('nexoro_doctor', function(source)
    if source ~= 0 then return end
    local problems, warnings = 0, 0
    local function line(level, text, fix)
        if level == 'fail' then problems = problems + 1 end
        if level == 'warn' then warnings = warnings + 1 end
        local colour = level == 'ok' and '^2' or (level == 'warn' and '^3' or '^1')
        local tag = level == 'ok' and 'OK  ' or (level == 'warn' and 'WARN' or 'FAIL')
        print(('%s[%s]^7 %s'):format(colour, tag, text))
        if fix then print('       -> ' .. fix) end
    end

    print('^5Nexoro doctor^7')
    for _, resource in ipairs({ 'oxmysql', 'nexoro_database', 'nexoro_core', 'nexoro_identity', 'nexoro_loading', 'nexoro_ui', 'nexoro_notifications', 'nexoro_character', 'nexoro_banking', 'nexoro_inventory', 'nexoro_chat', 'nexoro_phone', 'nexoro_hud', 'nexoro_menu', 'nexoro_death', 'nexoro_map', 'nexoro_world', 'nexoro_driving', 'nexoro_shops', 'nexoro_crafting', 'nexoro_courts', 'nexoro_prison', 'nexoro_housing', 'nexoro_taxi', 'nexoro_licences', 'nexoro_businesses', 'nexoro_postal', 'nexoro_fishing', 'nexoro_transport', 'nexoro_pawn', 'nexoro_auctions', 'nexoro_robbery', 'nexoro_farming', 'nexoro_gambling', 'nexoro_lottery', 'nexoro_scratchcards', 'nexoro_supplydrop', 'nexoro_crews', 'nexoro_hunting', 'nexoro_encampments', 'nexoro_scrapping', 'nexoro_traveller_site', 'nexoro_crime', 'nexoro_markets', 'nexoro_civilian', 'nexoro_devtools', 'nexoro_vehicles', 'nexoro_garages', 'nexoro_dealerships', 'nexoro_emergency', 'nexoro_police', 'nexoro_ambulance', 'nexoro_fire', 'nexoro_dispatch', 'nexoro_tablet', 'nexoro_lighting', 'nexoro_admin' }) do
        if GetResourceState(resource) == 'started' then line('ok', resource .. ' is running')
        else line('fail', resource .. ' is not running', 'Add "ensure ' .. resource .. '" to server.cfg (oxmysql and nexoro_database must come first).') end
    end
    if GetResourceState('chat') == 'started' then
        line('fail', 'the default FiveM chat resource is running', 'Remove "ensure chat" from server.cfg. Nexoro chat (nexoro_chat) replaces it.')
    end
    if GetResourceState('spawnmanager') == 'started' then
        line('warn', 'spawnmanager is running', 'Remove "ensure spawnmanager" (and basic-gamemode) from server.cfg. Nexoro handles spawning itself.')
    end
    if GetConvar('mysql_connection_string', '') == '' then
        line('fail', 'mysql_connection_string is not set', 'Set it in server.cfg: set mysql_connection_string "mysql://user:password@localhost/dbname"')
    else
        line('ok', 'database connection string is set (not shown)')
    end
    local dbOk, status = pcall(function() return exports.nexoro_database:GetStatus() end)
    if dbOk and status and status.ready then line('ok', 'database connected and migrations applied')
    else line('fail', 'database is not ready: ' .. tostring(dbOk and status and status.error or 'nexoro_database not running'), 'Check the nexoro_database messages above in the console.') end
    if GetConvar('onesync', 'off') == 'off' then
        line('fail', 'OneSync is off', 'Set "set onesync on" in server.cfg. Nexoro needs it for server-side entity checks.')
    else
        line('ok', 'OneSync is enabled')
    end
    local jobCount = 0
    for _ in pairs(Nexoro.Jobs) do jobCount = jobCount + 1 end
    line(jobCount > 0 and 'ok' or 'fail', ('%d job(s) loaded'):format(jobCount), jobCount == 0 and 'The nexoro_jobs table is empty. Re-run migrations with: nexoro_migrate' or nil)

    local ownerCount = #Config.Staff.Owners
    local row = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_staff_assignments WHERE rank_name = ?', { 'owner' }) or 0
    if ownerCount == 0 and row == 0 then
        line('warn', 'no owner is configured yet', 'Join the server, then run in this console: nexoro_setrank <your server id> owner')
    else
        line('ok', 'an owner is configured')
    end
    print(problems == 0 and '^2No problems found.^7' or ('^1' .. problems .. ' problem(s) need fixing.^7'))
    if warnings > 0 then print(('^3%d warning(s).^7'):format(warnings)) end
end, true)

RegisterCommand('claimowner', function(source, args)
    if source == 0 then return end
    if not Nexoro.Security.RateLimit(source, 'claimowner', 3, 60000) then return end
    local ok, why = Nexoro.ClaimOwner(source, args[1])
    local text = ok and 'You are now the owner of this server.' or
        (why == 'no_claim_code' and 'There is no owner code to claim: an owner already exists.' or 'That code is not correct.')
    Nexoro.Notify(source, text, ok and 'success' or 'error', 8000)
end, false)

RegisterCommand('mystaff', function(source)
    if source == 0 then return end
    local p = Nexoro.Players[source]
    local rank = p and p.staffRank
    local label = rank and Nexoro.Permissions.GetRankDefinition(rank).label or 'not staff'
    Nexoro.Notify(source, ('Your staff rank: %s.'):format(label), 'info', 6000)
end, false)
