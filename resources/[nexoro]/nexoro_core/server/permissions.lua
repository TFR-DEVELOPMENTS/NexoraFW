Nexoro = Nexoro or {}
Nexoro.Permissions = {}
local P = Nexoro.Permissions
local U = Nexoro.Utils

local ranks = {}
for _, rank in ipairs(Config.Staff.Ranks) do ranks[rank.name] = rank end

function P.GetRankDefinition(name) return name and ranks[name] or nil end

-- Resolves the rank from config owners + database. Call after the player row exists.
function P.Refresh(player)
    player.staffRank = nil
    for _, owner in ipairs(Config.Staff.Owners) do
        for _, identifier in pairs(player.identifiers) do
            if identifier == owner then player.staffRank = 'owner'; return end
        end
    end
    local row = NexoroDB.single('SELECT rank_name FROM nexoro_staff_assignments WHERE player_id = ?', { player.playerId })
    if row and ranks[row.rank_name] then player.staffRank = row.rank_name end
end

-- Single permission check used by commands, callbacks and menus. Source 0 is the server console.
function P.Has(src, permission)
    if src == 0 then return true end
    local player = Nexoro.Players[src]
    if not player or type(permission) ~= 'string' then return false end
    local rank = player.staffRank and ranks[player.staffRank]
    if rank then
        for _, pattern in ipairs(rank.permissions) do
            if U.PermissionMatches(pattern, permission) then return true end
        end
    end
    if Config.Staff.UseAceFallback and IsPlayerAceAllowed(tostring(src), permission) then return true end
    return false
end

function P.GetLevel(src)
    local player = Nexoro.Players[src]
    local rank = player and player.staffRank and ranks[player.staffRank]
    return rank and rank.level or 0
end

-- Staff may only act on players of a strictly lower staff level (non-staff = level 0).
function P.CanActOn(actor, target)
    if actor == 0 then return true end
    return P.GetLevel(actor) > P.GetLevel(target)
end

-- Server-side only (console command / other server resources). Pass nil to remove staff status.
function P.SetRank(src, rankName, by)
    local player = Nexoro.Players[src]
    if not player then return false, 'no_player' end
    if rankName ~= nil and not ranks[rankName] then return false, 'unknown_rank' end
    local previous = player.staffRank
    if rankName == nil then
        NexoroDB.update('DELETE FROM nexoro_staff_assignments WHERE player_id = ?', { player.playerId })
    else
        NexoroDB.update('INSERT INTO nexoro_staff_assignments (player_id, rank_name, assigned_by) VALUES (?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE rank_name = VALUES(rank_name), assigned_by = VALUES(assigned_by), assigned_at = CURRENT_TIMESTAMP',
            { player.playerId, rankName, tostring(by or 'console') })
    end
    P.Refresh(player)
    Nexoro.Log('permissions', 'set_rank', src, { previous = previous, new = rankName, by = tostring(by or 'console') })
    return true
end

function P.GetRanks()
    local list = {}
    for _, rank in ipairs(Config.Staff.Ranks) do list[#list + 1] = { name = rank.name, label = rank.label, level = rank.level } end
    return list
end
