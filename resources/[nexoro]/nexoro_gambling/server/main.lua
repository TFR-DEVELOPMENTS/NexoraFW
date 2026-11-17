local cfg = Config.Gambling

NexoroGambling = {}
local G = NexoroGambling
G.now = os.time

local function today()
    return G.now() // cfg.ResetSeconds
end

local function limitPence()
    return math.floor(cfg.DailyLimitPounds * 100 + 0.5)
end

-- Pence the character can still stake today.
function G.Remaining(characterId)
    local spent = NexoroDB.scalar('SELECT spent_pence FROM nexoro_gambling_daily WHERE character_id = ? AND day = ?', { characterId, today() }) or 0
    return math.max(0, limitPence() - spent)
end

-- Reserves a stake against today's limit. Refused if it would go over.
function G.Reserve(characterId, pence)
    if pence <= 0 then return false, 'invalid_stake' end
    if pence > G.Remaining(characterId) then return false, 'daily_limit' end
    NexoroDB.update('INSERT INTO nexoro_gambling_daily (character_id, day, spent_pence) VALUES (?,?,?) ON DUPLICATE KEY UPDATE spent_pence = spent_pence + ?',
        { characterId, today(), pence, pence })
    return true
end

-- Gives back a reservation when the stake could not be taken from the bank.
function G.Release(characterId, pence)
    NexoroDB.update('UPDATE nexoro_gambling_daily SET spent_pence = GREATEST(spent_pence - ?, 0) WHERE character_id = ? AND day = ?',
        { pence, characterId, today() })
end

exports('Remaining', G.Remaining)
exports('Reserve', G.Reserve)
exports('Release', G.Release)
