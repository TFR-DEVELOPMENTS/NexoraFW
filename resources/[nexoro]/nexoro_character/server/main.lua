local cfg = Config.Character
local Core

local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n then return nil end
    return math.tointeger(n)
end

local function decodeAppearance(raw)
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok then return nil end
    local valid, clean = NexoroAppearance.Validate(data)
    return valid and clean or nil
end

---------------------------------------------------------------------------
-- Character list
---------------------------------------------------------------------------

local function listCharacters(src)
    local C = core()
    local player = C.GetPlayer(src)
    if not player then return false, 'no_player' end
    if player.hasCharacter then return false, 'already_loaded' end

    SetPlayerRoutingBucket(src, cfg.SelectionBucketBase + src)

    local rows = NexoroDB.query([[
        SELECT c.id, c.slot, c.citizen_id, c.first_name, c.last_name, DATE_FORMAT(c.dob, '%d/%m/%Y') AS dob, c.gender,
               c.nationality, c.height_cm, COALESCE(j.label, c.job) AS job_label,
               DATE_FORMAT(c.last_played, '%d/%m/%Y %H:%i') AS last_played, a.data AS appearance
        FROM nexoro_characters c
        LEFT JOIN nexoro_jobs j ON j.name = c.job
        LEFT JOIN nexoro_character_appearance a ON a.character_id = c.id
        WHERE c.player_id = ? ORDER BY c.slot]], { player.playerId }) or {}
    local extra = NexoroDB.scalar('SELECT extra_slots FROM nexoro_players WHERE id = ?', { player.playerId }) or 0

    local characters = {}
    for _, r in ipairs(rows) do
        characters[#characters + 1] = {
            id = r.id, slot = r.slot, citizenId = r.citizen_id, firstName = r.first_name, lastName = r.last_name,
            dob = r.dob, gender = r.gender, nationality = r.nationality, height = r.height_cm, job = r.job_label,
            lastPlayed = r.last_played, appearance = decodeAppearance(r.appearance),
        }
    end
    return true, { characters = characters, slots = cfg.Slots + extra, options = exports.nexoro_identity:GetOptions() }
end

---------------------------------------------------------------------------
-- Create / delete / select
---------------------------------------------------------------------------

local function createCharacter(src, payload)
    local C = core()
    local player = C.GetPlayer(src)
    if not player or player.hasCharacter then return false, 'invalid_state' end
    if type(payload) ~= 'table' then return false, 'invalid_request' end

    local valid, clean = exports.nexoro_identity:ValidateCharacter(payload.identity)
    if not valid then return false, clean end

    local appearance
    if payload.appearance == nil then
        local _, def = NexoroAppearance.Default()
        appearance = def
    else
        local okApp, result = NexoroAppearance.Validate(payload.appearance)
        if not okApp then return false, result end
        appearance = result
    end

    local used = {}
    for _, row in ipairs(NexoroDB.query('SELECT slot FROM nexoro_characters WHERE player_id = ?', { player.playerId }) or {}) do used[row.slot] = true end
    local maxSlots = cfg.Slots + (NexoroDB.scalar('SELECT extra_slots FROM nexoro_players WHERE id = ?', { player.playerId }) or 0)
    local slot
    for i = 1, maxSlots do
        if not used[i] then slot = i; break end
    end
    if not slot then return false, 'no_free_slot' end

    local cash = math.floor(cfg.StartingMoney.cash * 100 + 0.5)
    local bank = math.floor(cfg.StartingMoney.bank * 100 + 0.5)
    local appearanceJson = json.encode(appearance)

    for _ = 1, 5 do
        local citizenId = exports.nexoro_identity:GenerateCitizenId()
        local committed = NexoroDB.transaction({
            {
                query = 'INSERT INTO nexoro_characters (player_id, slot, citizen_id, first_name, last_name, dob, gender, nationality, height_cm, biography, cash_pence, bank_pence) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
                values = { player.playerId, slot, citizenId, clean.firstName, clean.lastName, clean.dob, clean.gender, clean.nationality, clean.height, clean.biography, cash, bank },
            },
            { query = 'INSERT INTO nexoro_character_appearance (character_id, data) VALUES (LAST_INSERT_ID(), ?)', values = { appearanceJson } },
        })
        if committed then
            local id = NexoroDB.scalar('SELECT id FROM nexoro_characters WHERE citizen_id = ?', { citizenId })
            C.Log('character', 'created', src, { characterId = id, slot = slot, citizenId = citizenId })
            return true, { id = id }
        end
        -- Either a citizen ID clash (retry with a new ID) or a concurrent request took the slot.
        if NexoroDB.scalar('SELECT 1 FROM nexoro_characters WHERE player_id = ? AND slot = ?', { player.playerId, slot }) then
            return false, 'slot_taken'
        end
    end
    return false, 'create_failed'
end

local function deleteCharacter(src, payload)
    local C = core()
    local player = C.GetPlayer(src)
    if not player or player.hasCharacter then return false, 'invalid_state' end
    local id = type(payload) == 'table' and toInt(payload.id)
    if not id then return false, 'invalid_request' end

    -- Ownership is part of the query: a player can never delete someone else's character.
    local row = NexoroDB.single(
        'SELECT id, citizen_id, first_name, last_name, job, cash_pence, bank_pence FROM nexoro_characters WHERE id = ? AND player_id = ?',
        { id, player.playerId })
    if not row then return false, 'not_found' end
    if payload.citizenId ~= row.citizen_id then return false, 'confirmation_mismatch' end

    local affected = NexoroDB.update('DELETE FROM nexoro_characters WHERE id = ? AND player_id = ?', { id, player.playerId })
    if affected ~= 1 then return false, 'database_error' end
    C.Log('character', 'deleted', src, {
        characterId = row.id, citizenId = row.citizen_id, name = row.first_name .. ' ' .. row.last_name,
        job = row.job, cashPence = row.cash_pence, bankPence = row.bank_pence,
    })
    TriggerEvent('nexoro:server:characterDeleted', src, row.id, row.citizen_id)
    return listCharacters(src)
end

local function selectCharacter(src, payload)
    local C = core()
    local id = type(payload) == 'table' and toInt(payload.id)
    if not id then return false, 'invalid_request' end
    local ok, err = C.LoadCharacter(src, id)
    if not ok then return false, err or 'load_failed' end

    SetPlayerRoutingBucket(src, 0)
    local character = C.GetCharacter(src)
    local appearance = decodeAppearance(NexoroDB.scalar('SELECT data FROM nexoro_character_appearance WHERE character_id = ?', { character.id }))
    if not appearance then
        local _, def = NexoroAppearance.Default()
        appearance = def
    end
    local spawn = character.position or cfg.DefaultSpawn
    return true, {
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, heading = spawn.heading or 0.0 },
        appearance = appearance, health = character.health, armour = character.armour,
    }
end

---------------------------------------------------------------------------
-- Appearance and outfits (only for the currently loaded character)
---------------------------------------------------------------------------

local function getAppearance(src)
    local character = core().GetCharacter(src)
    if not character then return false, 'no_character' end
    local appearance = decodeAppearance(NexoroDB.scalar('SELECT data FROM nexoro_character_appearance WHERE character_id = ?', { character.id }))
    return appearance ~= nil, appearance or 'not_found'
end

local function saveAppearance(src, payload)
    local character = core().GetCharacter(src)
    if not character then return false, 'no_character' end
    local ok, clean = NexoroAppearance.Validate(type(payload) == 'table' and payload.appearance or nil)
    if not ok then return false, clean end
    local _, err = NexoroDB.update(
        'INSERT INTO nexoro_character_appearance (character_id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { character.id, json.encode(clean) })
    if err then return false, 'database_error' end
    return true
end

local function listOutfits(src)
    local character = core().GetCharacter(src)
    if not character then return false, 'no_character' end
    local outfits = {}
    for _, row in ipairs(NexoroDB.query('SELECT id, name, data FROM nexoro_character_outfits WHERE character_id = ? ORDER BY name', { character.id }) or {}) do
        local okJson, data = pcall(json.decode, row.data)
        if okJson then
            local valid, clean = NexoroAppearance.ValidateOutfit(data)
            if valid then outfits[#outfits + 1] = { id = row.id, name = row.name, components = clean.components, props = clean.props } end
        end
    end
    return true, outfits
end

local function saveOutfit(src, payload)
    local character = core().GetCharacter(src)
    if not character then return false, 'no_character' end
    if type(payload) ~= 'table' or type(payload.name) ~= 'string' then return false, 'invalid_request' end

    local name = trim(payload.name:gsub('[%c]', ''))
    if #name < 1 or #name > 30 or not name:match("^[%w '%-]+$") then return false, 'invalid_name' end
    local ok, outfit = NexoroAppearance.ValidateOutfit(payload.appearance)
    if not ok then return false, outfit end

    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_character_outfits WHERE character_id = ?', { character.id }) or 0
    if count >= cfg.MaxOutfits then return false, 'outfit_limit' end
    if NexoroDB.scalar('SELECT 1 FROM nexoro_character_outfits WHERE character_id = ? AND name = ?', { character.id, name }) then
        return false, 'name_taken'
    end
    local _, err = NexoroDB.insert('INSERT INTO nexoro_character_outfits (character_id, name, data) VALUES (?, ?, ?)', { character.id, name, json.encode(outfit) })
    if err then return false, 'database_error' end
    return listOutfits(src)
end

local function deleteOutfit(src, payload)
    local character = core().GetCharacter(src)
    if not character then return false, 'no_character' end
    local id = type(payload) == 'table' and toInt(payload.id)
    if not id then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_character_outfits WHERE id = ? AND character_id = ?', { id, character.id })
    return listOutfits(src)
end

---------------------------------------------------------------------------
-- Registration (re-run whenever nexoro_core restarts)
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    C.RegisterCallback('nexoro_character:list', listCharacters, { rateLimit = { max = 10, windowMs = 30000 } })
    C.RegisterCallback('nexoro_character:create', createCharacter, { rateLimit = { max = 3, windowMs = 60000 } })
    C.RegisterCallback('nexoro_character:delete', deleteCharacter, { rateLimit = { max = 3, windowMs = 60000 } })
    C.RegisterCallback('nexoro_character:select', selectCharacter, { rateLimit = { max = 5, windowMs = 30000 } })
    C.RegisterCallback('nexoro_character:getAppearance', getAppearance, { requireCharacter = true, rateLimit = { max = 5, windowMs = 30000 } })
    C.RegisterCallback('nexoro_character:saveAppearance', saveAppearance, { requireCharacter = true, rateLimit = { max = 10, windowMs = 60000 } })
    C.RegisterCallback('nexoro_character:listOutfits', listOutfits, { requireCharacter = true, rateLimit = { max = 10, windowMs = 30000 } })
    C.RegisterCallback('nexoro_character:saveOutfit', saveOutfit, { requireCharacter = true, rateLimit = { max = 10, windowMs = 60000 } })
    C.RegisterCallback('nexoro_character:deleteOutfit', deleteOutfit, { requireCharacter = true, rateLimit = { max = 10, windowMs = 60000 } })
end

AddEventHandler('nexoro:core:ready', register)

CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

RegisterCommand('logout', function(source)
    if source == 0 then return end
    local C = core()
    if not C.RateLimit(source, 'logout', 2, 30000) then return end
    if C.UnloadCharacter(source, 'logout') then TriggerClientEvent('nexoro:character:openSelect', source) end
end, false)
