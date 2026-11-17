Nexoro = Nexoro or {}
local U = Nexoro.Utils
local API = {}
Nexoro.API = API

local NOTIFY_TYPES = {
    success = true, error = true, warning = true, info = true, emergency = true,
    job = true, banking = true, inventory = true, staff = true,
}

local function snapshot(src)
    local p = Nexoro.Players[src]
    if not p then return nil end
    return {
        source = p.source, playerId = p.playerId, license = p.license, name = p.name,
        identifiers = U.DeepCopy(p.identifiers), staffRank = p.staffRank,
        hasCharacter = p.character ~= nil, characterId = p.character and p.character.id or nil, onDuty = p.duty,
    }
end

local function inventory(fn, ...)
    if GetResourceState('nexoro_inventory') ~= 'started' then return nil, 'inventory_unavailable' end
    local ok, a, b = pcall(function(...) return exports['nexoro_inventory'][fn](exports['nexoro_inventory'], ...) end, ...)
    if not ok then return nil, 'inventory_error' end
    return a, b
end

-- Read-only snapshots (copies; editing them changes nothing).
API.GetPlayer = snapshot

function API.GetPlayerByIdentifier(identifier)
    if type(identifier) ~= 'string' then return nil end
    for src, p in pairs(Nexoro.Players) do
        for _, id in pairs(p.identifiers) do
            if id == identifier then return snapshot(src) end
        end
    end
    return nil
end

function API.GetCharacter(src)
    local p = Nexoro.Players[src]
    return p and p.character and U.DeepCopy(p.character) or nil
end

function API.GetSourceByCharacterId(characterId)
    for src, p in pairs(Nexoro.Players) do
        if p.character and p.character.id == characterId then return src end
    end
    return nil
end

API.GetPlayerMoney = Nexoro.GetPlayerMoney
API.AddMoney = Nexoro.AddMoney
API.RemoveMoney = Nexoro.RemoveMoney
API.GetJob = Nexoro.GetJob
API.SetJob = Nexoro.SetJob
API.SetDuty = Nexoro.SetDuty
API.SavePlayer = Nexoro.SavePlayer
API.SetMetadata = Nexoro.SetMetadata
API.GetMetadata = Nexoro.GetMetadata
API.LoadCharacter = Nexoro.LoadCharacter
API.UnloadCharacter = Nexoro.UnloadCharacter
API.RegisterJob = Nexoro.RegisterJob
API.RefreshJobs = Nexoro.LoadJobs
API.RegisterCallback = Nexoro.RegisterCallback
API.RegisterConnectHook = Nexoro.RegisterConnectHook
API.HasPermission = Nexoro.Permissions.Has
API.CanActOn = Nexoro.Permissions.CanActOn
API.SetStaffRank = Nexoro.Permissions.SetRank
API.Log = Nexoro.Log
API.RateLimit = Nexoro.Security.RateLimit
API.FormatGBP = U.FormatGBP
API.IsReady = function() return Nexoro.Ready end

function API.Notify(src, message, ntype, duration)
    if type(message) ~= 'string' or not Nexoro.Players[src] then return false end
    ntype = NOTIFY_TYPES[ntype] and ntype or 'info'
    duration = U.Clamp(U.ToInt(duration) or 5000, 1000, 30000)
    TriggerClientEvent('nexoro:client:notify', src, { message = message:sub(1, 300), type = ntype, duration = duration })
    return true
end

-- Inventory lives in nexoro_inventory (Phase 2). Until then these return nil, 'inventory_unavailable'.
function API.GetInventory(src) return inventory('GetInventory', src) end
function API.AddItem(src, item, amount) return inventory('AddItem', src, item, amount) end
function API.RemoveItem(src, item, amount) return inventory('RemoveItem', src, item, amount) end


API.ReloadBalances = Nexoro.ReloadBalances
API.GetPlayers = Nexoro.GetPlayersSummary
API.PublicCharacter = Nexoro.PublicCharacter
API.ToPence = U.ToPence
API.RegisterSecureEvent = Nexoro.RegisterSecureEvent
API.GetStaffLevel = Nexoro.Permissions.GetLevel
API.GetStaffRanks = Nexoro.Permissions.GetRanks
API.InvokeCallback = Nexoro.InvokeCallback

-- Permissions attached to a job grade (used for department ranks such as "can cuff").
function API.GetGradePermissions(jobName, grade)
    local job = Nexoro.Jobs[jobName]
    local g = job and job.grades[tonumber(grade)]
    local out = {}
    if g and type(g.permissions) == 'table' then for i, p in ipairs(g.permissions) do out[i] = p end end
    return out
end

function API.GetJobs()
    local list = {}
    for name, job in pairs(Nexoro.Jobs) do
        local grades = {}
        for grade, g in pairs(job.grades) do grades[#grades + 1] = { grade = grade, label = g.label, salary = g.salaryPence / 100 } end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        list[#list + 1] = { name = name, label = job.label, category = job.category, whitelisted = job.whitelisted, grades = grades }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function API.GetSourceByCitizenId(citizenId)
    for src, p in pairs(Nexoro.Players) do
        if p.character and p.character.citizenId == citizenId then return src end
    end
    return nil
end

exports('GetCore', function() return API end)
for name, fn in pairs(API) do exports(name, fn) end
