Nexoro = Nexoro or {}
Nexoro.Players = {}      -- [source] = player
Nexoro.Pending = {}      -- [tempSource] = { row, identifiers, name } (between playerConnecting and playerJoining)
Nexoro.ConnectHooks = {} -- functions(source, identifiers, name) -> allowed (bool), reason (string)
Nexoro.Ready = false

local Players = Nexoro.Players
local U = Nexoro.Utils
local cfg = Config.Framework

local ACCOUNT_COLUMN = { cash = 'cash_pence', bank = 'bank_pence' }
local ACCOUNT_FIELD = { cash = 'cash', bank = 'bank' }

---------------------------------------------------------------------------
-- Identifiers and player rows
---------------------------------------------------------------------------

local function collectIdentifiers(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local full = GetPlayerIdentifier(src, i)
        local kind = full and full:match('^(%w+):')
        -- IP addresses are never stored.
        if kind and kind ~= 'ip' and #kind <= 16 and #full <= 80 then ids[kind] = full end
    end
    return ids
end

local function upsertPlayer(ids, name)
    name = tostring(name or 'Unknown'):sub(1, 100)
    local _, err = NexoroDB.query(
        'INSERT INTO nexoro_players (license, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), last_seen = CURRENT_TIMESTAMP',
        { ids.license, name })
    if err then return nil end
    local row = NexoroDB.single('SELECT id, extra_slots, active_character_id FROM nexoro_players WHERE license = ?', { ids.license })
    if not row then return nil end

    local placeholders, params = {}, {}
    for kind, value in pairs(ids) do
        placeholders[#placeholders + 1] = '(?,?,?)'
        params[#params + 1] = row.id
        params[#params + 1] = kind
        params[#params + 1] = value
    end
    NexoroDB.query(
        'INSERT INTO nexoro_player_identifiers (player_id, id_type, id_value) VALUES ' .. table.concat(placeholders, ',') ..
        ' ON DUPLICATE KEY UPDATE id_value = VALUES(id_value)', params)
    return row
end

-- The very first account on an empty server becomes owner. One conditional INSERT, so two
-- simultaneous first joins cannot both win. Skipped when owners are configured in config/staff.lua.
-- If nobody is owner yet, prints a one-time code in the server console. Typing /claimowner CODE
-- in game makes that player owner. The code is never sent to players.
function Nexoro.OwnerExists()
    return (NexoroDB.scalar("SELECT COUNT(*) FROM nexoro_staff_assignments WHERE rank_name = 'owner'") or 0) > 0
end

function Nexoro.InitClaimCode()
    Nexoro.ClaimCode = nil
    if #Config.Staff.Owners > 0 or GetConvar('nexoro_owner_license', '') ~= '' or Nexoro.OwnerExists() then return end
    Nexoro.ClaimCode = tostring(math.random(100000, 999999))
    print(('^3[Nexoro] There is no owner on this server yet. In game, type /claimowner %s to become owner.^7'):format(Nexoro.ClaimCode))
end

function Nexoro.ClaimOwner(src, code)
    if not Nexoro.Players[src] then return false, 'no_player' end
    if not Nexoro.ClaimCode then return false, 'no_claim_code' end
    if tostring(code) ~= Nexoro.ClaimCode then return false, 'wrong_code' end
    Nexoro.ClaimCode = nil
    Nexoro.Permissions.SetRank(src, 'owner', 'claim-code')
    Nexoro.Log('permissions', 'claimed_owner', src, {})
    return true
end

function Nexoro.ClaimFirstOwner(player)
    -- Owner by server convar: set nexoro_owner_license "license:xxxxxxxx" in server.cfg.
    local ownerLicense = GetConvar('nexoro_owner_license', '')
    if ownerLicense ~= '' and player.license == ownerLicense then
        if not player.staffRank then Nexoro.Permissions.SetRank(player.source, 'owner', 'convar') end
        return true
    end
    if #Config.Staff.Owners > 0 then return false end
    local affected = NexoroDB.update(
        "INSERT INTO nexoro_staff_assignments (player_id, rank_name, assigned_by) SELECT ?, 'owner', 'first-join' FROM DUAL " ..
        'WHERE NOT EXISTS (SELECT 1 FROM nexoro_staff_assignments)', { player.playerId })
    if affected ~= 1 then return false end
    Nexoro.Permissions.Refresh(player)
    Nexoro.Log('permissions', 'first_owner', player.source, { license = player.license })
    print(('^2[Nexoro] %s is the first player on this server and has been made owner.^7'):format(player.name))
    return true
end

local function createPlayer(src, row, ids, name)
    local now = os.time()
    local player = {
        source = src, playerId = row.id, license = ids.license, identifiers = ids, name = tostring(name or 'Unknown'):sub(1, 100),
        extraSlots = row.extra_slots or 0, character = nil, staffRank = nil, duty = false,
        joinedAt = now, lastSavedAt = now, spawned = false, loading = false, saving = false,
    }
    Players[src] = player
    Nexoro.Permissions.Refresh(player)
    Nexoro.ClaimFirstOwner(player)
    return player
end

function Nexoro.RegisterExistingPlayer(src)
    local ids = collectIdentifiers(src)
    if not ids.license then DropPlayer(src, 'Nexoro: a valid Rockstar licence is required.'); return nil end
    local row = upsertPlayer(ids, GetPlayerName(src))
    if not row then return nil end
    return createPlayer(src, row, ids, GetPlayerName(src)), row
end

function Nexoro.RegisterConnectHook(fn)
    Nexoro.ConnectHooks[#Nexoro.ConnectHooks + 1] = fn
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Nexoro: checking your details...')

    if not Nexoro.Ready then return deferrals.done('The server is still starting. Please reconnect in a moment.') end
    local ids = collectIdentifiers(src)
    if not ids.license then
        return deferrals.done('A valid Rockstar licence is required to join. Restart FiveM while signed in to Rockstar Games Launcher.')
    end
    for _, hook in ipairs(Nexoro.ConnectHooks) do
        local ok, allowed, reason = pcall(hook, src, ids, name)
        if ok and type(allowed) == 'table' then allowed, reason = allowed.allowed, allowed.reason end
        if ok and allowed == false then return deferrals.done(reason or 'You are not allowed to join this server.') end
    end
    local row = upsertPlayer(ids, name)
    if not row then return deferrals.done('Database error while loading your account. Please try again.') end
    Nexoro.Pending[src] = { row = row, identifiers = ids, name = name }
    deferrals.done()
end)

AddEventHandler('playerJoining', function(tempId)
    local src = source
    local pending = Nexoro.Pending[tonumber(tempId)]
    Nexoro.Pending[tonumber(tempId)] = nil
    if pending then
        createPlayer(src, pending.row, pending.identifiers, pending.name)
    else
        Nexoro.RegisterExistingPlayer(src)
    end
end)

---------------------------------------------------------------------------
-- Character state
---------------------------------------------------------------------------

function Nexoro.GetJob(src)
    local player = Players[src]
    local c = player and player.character
    if not c then return nil end
    local job = Nexoro.Jobs[c.job]
    local grade = job and job.grades[c.jobGrade]
    return {
        name = c.job, label = job and job.label or c.job, category = job and job.category or 'civilian',
        grade = c.jobGrade, gradeLabel = grade and grade.label or ('Grade ' .. c.jobGrade),
        salary = (grade and grade.salaryPence or 0) / 100, onDuty = player.duty,
    }
end

function Nexoro.PublicCharacter(src)
    local player = Players[src]
    local c = player and player.character
    if not c then return nil end
    return {
        citizenId = c.citizenId, firstName = c.firstName, lastName = c.lastName, dob = c.dob, gender = c.gender,
        nationality = c.nationality, height = c.height, job = Nexoro.GetJob(src), cash = c.cash / 100, bank = c.bank / 100,
    }
end

-- State bags are for CLIENT DISPLAY ONLY (HUD, name tags). The server never reads them back for decisions.
local function syncState(src)
    local player = Players[src]
    local c = player and player.character
    local state = Player(src).state
    if not c then
        state:set('nexoro:name', nil, true)
        state:set('nexoro:job', nil, true)
        return
    end
    state:set('nexoro:name', c.firstName .. ' ' .. c.lastName, true)
    state:set('nexoro:job', c.job, true)
end

local function loadCharacterInner(src, player, characterId)
    local row = NexoroDB.single([[
        SELECT id, citizen_id, first_name, last_name, DATE_FORMAT(dob, '%Y-%m-%d') AS dob, gender, nationality, height_cm,
               biography, cash_pence, bank_pence, job, job_grade, pos_x, pos_y, pos_z, pos_heading, health, armour
        FROM nexoro_characters WHERE id = ? AND player_id = ?]], { characterId, player.playerId })
    if not row then return nil, 'not_found' end

    local job, grade = row.job, row.job_grade
    local definition = Nexoro.Jobs[job]
    if not definition or not definition.grades[grade] then
        Nexoro.Log('character', 'invalid_job_reset', src, { job = job, grade = grade })
        job, grade = cfg.DefaultJob.name, cfg.DefaultJob.grade
    end

    local metadata = {}
    for _, m in ipairs(NexoroDB.query('SELECT meta_key, meta_value FROM nexoro_player_metadata WHERE character_id = ?', { row.id }) or {}) do
        local ok, value = pcall(json.decode, m.meta_value)
        if ok then metadata[m.meta_key] = value end
    end

    player.character = {
        id = row.id, citizenId = row.citizen_id, firstName = row.first_name, lastName = row.last_name, dob = row.dob,
        gender = row.gender, nationality = row.nationality, height = row.height_cm, biography = row.biography,
        cash = row.cash_pence, bank = row.bank_pence, job = job, jobGrade = grade,
        position = row.pos_x and { x = row.pos_x, y = row.pos_y, z = row.pos_z, heading = row.pos_heading or 0.0 } or nil,
        health = row.health, armour = row.armour, metadata = metadata,
    }
    player.duty = false
    player.spawned = false
    player.lastSavedAt = os.time()

    NexoroDB.update('UPDATE nexoro_players SET active_character_id = ? WHERE id = ?', { row.id, player.playerId })
    NexoroDB.update('UPDATE nexoro_characters SET last_played = CURRENT_TIMESTAMP WHERE id = ?', { row.id })

    syncState(src)
    Nexoro.Log('character', 'loaded', src, { characterId = row.id })
    TriggerEvent('nexoro:server:characterLoaded', src, Nexoro.PublicCharacter(src))
    TriggerClientEvent('nexoro:client:characterLoaded', src, Nexoro.PublicCharacter(src))
    return true
end

-- Loads one of the player's OWN characters (ownership is enforced in SQL).
function Nexoro.LoadCharacter(src, characterId)
    local player = Players[src]
    if not player then return nil, 'no_player' end
    if player.character then return nil, 'already_loaded' end
    if player.loading then return nil, 'busy' end
    characterId = U.ToInt(characterId)
    if not characterId or characterId < 1 then return nil, 'invalid_id' end

    player.loading = true
    local ok, result, err = pcall(loadCharacterInner, src, player, characterId)
    player.loading = false
    if not ok then
        print(('^1[Nexoro] LoadCharacter failed: %s^7'):format(tostring(result)))
        player.character = nil
        return nil, 'server_error'
    end
    return result, err
end

function Nexoro.SaveCharacter(src)
    local player = Players[src]
    local c = player and player.character
    if not c or player.saving then return false end
    player.saving = true
    local ok, err = pcall(function()
        local ped = GetPlayerPed(src)
        if player.spawned and ped and ped ~= 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            if U.IsFinite(coords.x) and U.IsFinite(coords.y) and U.IsFinite(coords.z) and coords.z > -150.0 then
                c.position = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                c.health = U.Clamp(GetEntityHealth(ped), 0, 400)
                c.armour = U.Clamp(GetPedArmour(ped), 0, 100)
                NexoroDB.update(
                    'UPDATE nexoro_characters SET pos_x = ?, pos_y = ?, pos_z = ?, pos_heading = ?, health = ?, armour = ? WHERE id = ?',
                    { c.position.x, c.position.y, c.position.z, c.position.heading, c.health, c.armour, c.id })
            end
        end
    end)
    player.saving = false
    if not ok then print(('^1[Nexoro] SaveCharacter failed: %s^7'):format(tostring(err))) end
    return ok
end

function Nexoro.SavePlayer(src)
    local player = Players[src]
    if not player then return false end
    Nexoro.SaveCharacter(src)
    local now = os.time()
    local delta = math.max(0, now - player.lastSavedAt)
    player.lastSavedAt = now
    NexoroDB.update('UPDATE nexoro_players SET playtime_seconds = playtime_seconds + ?, last_seen = CURRENT_TIMESTAMP WHERE id = ?', { delta, player.playerId })
    return true
end

function Nexoro.UnloadCharacter(src, reason)
    local player = Players[src]
    if not player or not player.character then return false end
    Nexoro.SavePlayer(src)
    local characterId = player.character.id
    player.character = nil
    player.spawned = false
    player.duty = false
    NexoroDB.update('UPDATE nexoro_players SET active_character_id = NULL WHERE id = ?', { player.playerId })
    Nexoro.Log('character', 'unloaded', src, { characterId = characterId, reason = reason })
    TriggerEvent('nexoro:server:characterUnloaded', src, characterId, reason)
    if GetPlayerName(src) then
        syncState(src)
        TriggerClientEvent('nexoro:client:characterUnloaded', src)
    end
    return true
end

---------------------------------------------------------------------------
-- Money (server-authoritative; the database row is the source of truth)
---------------------------------------------------------------------------

local function validateMoneyArgs(src, amount, account)
    local player = Players[src]
    local c = player and player.character
    if not c then return nil, 'no_character' end
    if type(account) ~= 'string' or not ACCOUNT_COLUMN[account] then return nil, 'invalid_account' end
    local pence, why = U.ToPence(amount)
    if not pence or pence <= 0 then return nil, 'invalid_amount' end
    if pence > math.floor(cfg.MaxSingleTransactionPounds * 100 + 0.5) then return nil, 'amount_too_large' end
    return c, pence, ACCOUNT_COLUMN[account], ACCOUNT_FIELD[account]
end

local function notifyMoney(src, account, c)
    TriggerClientEvent('nexoro:client:moneyUpdated', src, account, c[account] / 100)
end

function Nexoro.AddMoney(src, amount, account, reason)
    account = account or 'cash'
    local c, pence, column, field = validateMoneyArgs(src, amount, account)
    if not c then return false, pence end
    local cap = math.floor(cfg.MaxBalancePounds * 100 + 0.5)
    -- column/field come from a fixed whitelist above, never from the caller.
    local affected = NexoroDB.update(
        ('UPDATE nexoro_characters SET %s = %s + ? WHERE id = ? AND %s + ? <= ?'):format(column, column, column),
        { pence, c.id, pence, cap })
    if affected ~= 1 then return false, affected == 0 and 'balance_limit' or 'database_error' end
    c[field] = c[field] + pence
    Nexoro.Log('economy', 'add', src, { account = account, pence = pence, reason = reason, balance = c[field] })
    notifyMoney(src, field, c)
    return true, c[field] / 100
end

function Nexoro.RemoveMoney(src, amount, account, reason)
    account = account or 'cash'
    local c, pence, column, field = validateMoneyArgs(src, amount, account)
    if not c then return false, pence end
    local affected = NexoroDB.update(
        ('UPDATE nexoro_characters SET %s = %s - ? WHERE id = ? AND %s >= ?'):format(column, column, column),
        { pence, c.id, pence })
    if affected ~= 1 then return false, affected == 0 and 'insufficient_funds' or 'database_error' end
    c[field] = c[field] - pence
    Nexoro.Log('economy', 'remove', src, { account = account, pence = pence, reason = reason, balance = c[field] })
    notifyMoney(src, field, c)
    return true, c[field] / 100
end

function Nexoro.GetPlayerMoney(src, account)
    account = account or 'cash'
    local c = Players[src] and Players[src].character
    if not c or type(account) ~= 'string' or not ACCOUNT_FIELD[account] then return nil end
    return c[ACCOUNT_FIELD[account]] / 100
end

---------------------------------------------------------------------------
-- Jobs and metadata
---------------------------------------------------------------------------

function Nexoro.SetJob(src, jobName, grade)
    local player = Players[src]
    local c = player and player.character
    if not c then return false, 'no_character' end
    grade = U.ToInt(grade or 0)
    local job = type(jobName) == 'string' and Nexoro.Jobs[jobName] or nil
    if not job then return false, 'unknown_job' end
    if not grade or not job.grades[grade] then return false, 'unknown_grade' end

    local _, err = NexoroDB.update('UPDATE nexoro_characters SET job = ?, job_grade = ? WHERE id = ?', { jobName, grade, c.id })
    if err then return false, 'database_error' end
    local previous = c.job
    c.job, c.jobGrade, player.duty = jobName, grade, false
    Nexoro.Log('jobs', 'set_job', src, { previous = previous, job = jobName, grade = grade })
    syncState(src)
    TriggerEvent('nexoro:server:jobChanged', src, Nexoro.GetJob(src), previous)
    TriggerClientEvent('nexoro:client:jobUpdated', src, Nexoro.GetJob(src))
    return true
end

function Nexoro.SetDuty(src, onDuty)
    local player = Players[src]
    if not player or not player.character then return false end
    player.duty = onDuty == true
    TriggerEvent('nexoro:server:dutyChanged', src, player.duty)
    TriggerClientEvent('nexoro:client:jobUpdated', src, Nexoro.GetJob(src))
    return true
end

function Nexoro.SetMetadata(src, key, value)
    local player = Players[src]
    local c = player and player.character
    if not c then return false, 'no_character' end
    if type(key) ~= 'string' or not key:match('^[%w_%.]+$') or #key > 64 then return false, 'invalid_key' end
    if value == nil then
        NexoroDB.update('DELETE FROM nexoro_player_metadata WHERE character_id = ? AND meta_key = ?', { c.id, key })
        c.metadata[key] = nil
        TriggerEvent('nexoro:server:metadataChanged', src, key, nil)
        return true
    end
    local ok, encoded = pcall(json.encode, value)
    if not ok or #encoded > 4096 then return false, 'invalid_value' end
    NexoroDB.update(
        'INSERT INTO nexoro_player_metadata (character_id, meta_key, meta_value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE meta_value = VALUES(meta_value)',
        { c.id, key, encoded })
    c.metadata[key] = value
    TriggerEvent('nexoro:server:metadataChanged', src, key, value)
    return true
end

function Nexoro.GetMetadata(src, key)
    local c = Players[src] and Players[src].character
    return c and c.metadata[key] or nil
end

---------------------------------------------------------------------------
-- Client handshake, disconnect, restart recovery
---------------------------------------------------------------------------

RegisterNetEvent('nexoro:server:clientReady', function()
    local src = source
    if not Nexoro.Security.RateLimit(src, 'clientReady', 10, 30000) then return end
    local player = Players[src]
    if not player then return end -- the client retries until registration has finished
    TriggerClientEvent('nexoro:client:playerReady', src, {
        version = cfg.Version, characterLoaded = player.character ~= nil, character = Nexoro.PublicCharacter(src),
    })
    TriggerEvent('nexoro:server:playerReady', src)
end)

Nexoro.RegisterSecureEvent('nexoro:server:characterSpawned', { requireCharacter = true, rateLimit = { max = 3, windowMs = 10000 } }, function(src)
    Players[src].spawned = true
    TriggerEvent('nexoro:server:characterSpawned', src)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    Nexoro.Pending[src] = nil
    local player = Players[src]
    if not player then return end
    if player.character then
        Nexoro.SavePlayer(src)
        NexoroDB.update('UPDATE nexoro_players SET active_character_id = NULL WHERE id = ?', { player.playerId })
        TriggerEvent('nexoro:server:characterUnloaded', src, player.character.id, 'disconnect')
    end
    Nexoro.Log('player', 'dropped', src, { reason = tostring(reason):sub(1, 120) })
    TriggerEvent('nexoro:server:playerDropped', src, reason)
    Players[src] = nil
    Nexoro.Security.Clear(src)
end)

-- Rebuilds state for players who are already connected (nexoro_core restarted mid-session).
function Nexoro.RecoverPlayer(src)
    local player, row = Nexoro.RegisterExistingPlayer(src)
    if not player then return end
    if row.active_character_id then
        local ok = Nexoro.LoadCharacter(src, row.active_character_id)
        if ok then player.spawned = true end
    end
    TriggerClientEvent('nexoro:client:playerReady', src, {
        version = cfg.Version, characterLoaded = player.character ~= nil, character = Nexoro.PublicCharacter(src), recovered = true,
    })
end

---------------------------------------------------------------------------
-- Phase 2 additions
---------------------------------------------------------------------------

-- Re-reads both balances from the database (use after any multi-row SQL change such as transfers).
function Nexoro.ReloadBalances(src)
    local player = Players[src]
    local c = player and player.character
    if not c then return false end
    local row = NexoroDB.single('SELECT cash_pence, bank_pence FROM nexoro_characters WHERE id = ?', { c.id })
    if not row then return false end
    c.cash, c.bank = row.cash_pence, row.bank_pence
    TriggerClientEvent('nexoro:client:moneyUpdated', src, 'cash', c.cash / 100)
    TriggerClientEvent('nexoro:client:moneyUpdated', src, 'bank', c.bank / 100)
    return true
end

function Nexoro.GetPlayersSummary()
    local list = {}
    for src, p in pairs(Players) do
        local c = p.character
        local rank = p.staffRank and Nexoro.Permissions.GetRankDefinition(p.staffRank)
        list[#list + 1] = {
            source = src, name = p.name, license = p.license, staffRank = p.staffRank, staffLabel = rank and rank.label or nil,
            hasCharacter = c ~= nil, characterId = c and c.id or nil, citizenId = c and c.citizenId or nil,
            characterName = c and (c.firstName .. ' ' .. c.lastName) or nil,
            job = c and c.job or nil, jobGrade = c and c.jobGrade or nil, onDuty = p.duty,
            cash = c and c.cash / 100 or nil, bank = c and c.bank / 100 or nil,
            playtimeSeconds = os.time() - p.joinedAt,
        }
    end
    table.sort(list, function(a, b) return a.source < b.source end)
    return list
end
