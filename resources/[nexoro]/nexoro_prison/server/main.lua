local cfg = Config.Prison
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroPrison = {}
local P = NexoroPrison
P.now = os.time

local function serving(characterId)
    return NexoroDB.single("SELECT id, minutes, ends_at FROM nexoro_prison_sentences WHERE character_id = ? AND status = 'serving' ORDER BY id DESC LIMIT 1", { characterId })
end

-- Starts a sentence. Cuffs come off on the way in. The clock runs on the server.
function P.Sentence(src, minutes, offence)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local m = math.tointeger(tonumber(minutes))
    if not m or m < 1 or m > cfg.MaxMinutes then return false, 'invalid_sentence' end
    if serving(c.id) then return false, 'already_serving' end
    local now = P.now()
    local ends = now + m * 60
    local id = NexoroDB.insert(
        'INSERT INTO nexoro_prison_sentences (character_id, minutes, offence, started_at, ends_at) VALUES (?,?,?,?,?)',
        { c.id, m, tostring(offence or ''):sub(1, 120), now, ends })
    if not id then return false, 'database_error' end
    core().SetMetadata(src, 'cuffed', nil)
    core().SetMetadata(src, 'inPrison', id)
    TriggerClientEvent('nexoro_prison:enter', src, { cell = cfg.Cell, endsAt = ends })
    core().Notify(src, ('You have been sentenced to %d minutes in prison.'):format(m), 'warning', 10000)
    core().Log('prison', 'sentenced', src, { id = id, minutes = m })
    return true, { id = id, endsAt = ends }
end

local function release(row)
    local affected = NexoroDB.update("UPDATE nexoro_prison_sentences SET status = 'served', released_at = ? WHERE id = ? AND status = 'serving'", { P.now(), row.id })
    if affected ~= 1 then return false end
    local cid = NexoroDB.scalar('SELECT character_id FROM nexoro_prison_sentences WHERE id = ?', { row.id })
    local src = cid and core().GetSourceByCharacterId(cid)
    if src then
        core().SetMetadata(src, 'inPrison', nil)
        TriggerClientEvent('nexoro_prison:release', src, { release = cfg.Release })
        core().Notify(src, 'Your sentence is over. You have been released.', 'info', 10000)
    end
    core().Log('prison', 'released', src or 0, { id = row.id })
    return true
end

-- Releases everyone whose sentence has run out. Returns how many were released.
function P.Tick()
    local rows = NexoroDB.query("SELECT id FROM nexoro_prison_sentences WHERE status = 'serving' AND ends_at <= ?", { P.now() }) or {}
    local n = 0
    for _, r in ipairs(rows) do if release(r) then n = n + 1 end end
    return n
end

-- Seconds left on the current sentence (0 when not in prison).
function P.Remaining(src)
    local c = core().GetCharacter(src)
    if not c then return 0 end
    local row = serving(c.id)
    if not row then return 0 end
    return math.max(0, row.ends_at - P.now())
end

-- Police arrests with a sentence come through here.
AddEventHandler('nexoro:server:arrested', function(src, minutes, offence)
    local m = tonumber(minutes) or 0
    if m > 0 then P.Sentence(src, m, offence) end
end)

-- Still serving time when they log back in: put them back in their cell.
AddEventHandler('nexoro:server:characterLoaded', function(src)
    CreateThread(function()
        local c = core().GetCharacter(src)
        local row = c and serving(c.id)
        if row then TriggerClientEvent('nexoro_prison:enter', src, { cell = cfg.Cell, endsAt = row.ends_at }) end
    end)
end)

local function register()
    Core = nil
    core().RegisterCallback('nexoro_prison:remaining', function(src) return true, P.Remaining(src) end,
        { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(cfg.TickSeconds * 1000)
        P.Tick()
    end
end)

exports('Sentence', P.Sentence)
exports('Remaining', P.Remaining)
