local cfg = Config.SupplyDrop
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroSupplyDrop = {}
local S = NexoroSupplyDrop
S.now = os.time
S.random = function(lo, hi) return math.random(lo, hi) end
S.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
-- In-game clock from nexoro_world. Tests replace this.
S.clock = function()
    if GetResourceState('nexoro_world') ~= 'started' then return nil, nil end
    local ok, state = pcall(function() return exports.nexoro_world:GetState() end)
    if not ok or type(state) ~= 'table' then return nil, nil end
    return state.hour, state.minute
end

local announced, dropped = {}, {}
local crates = {}
local nextId = 0

local function dayKey()
    return S.now() // 86400
end

-- Called on every tick with the current in-game time. Announces and drops at the set times, once each per day.
function S.Schedule(hour, minute)
    if hour == nil then return {} end
    local nowMin = hour * 60 + minute
    local events = {}
    for _, t in ipairs(cfg.Times) do
        local key = dayKey() .. ':' .. t.label
        if nowMin >= t.minutes - cfg.AnnounceMinutes and not announced[key] then
            announced[key] = true
            S.Announce(t)
            events[#events + 1] = 'announce:' .. t.label
        end
        if nowMin >= t.minutes and not dropped[key] then
            dropped[key] = true
            S.Drop()
            events[#events + 1] = 'drop:' .. t.label
        end
    end
    return events
end

function S.Announce(t)
    local team = cfg.TeamLabel and (' for ' .. cfg.TeamLabel) or ''
    local message = ('A supply drop%s will land at %s at %s. Get there first.'):format(team, cfg.Location.label, t.label)
    TriggerClientEvent('nexoro:notify', -1, { message = message, type = 'emergency', duration = 12000 })
    TriggerClientEvent('nexoro_supplydrop:announce', -1, { label = t.label, location = cfg.Location.label, x = cfg.Location.x, y = cfg.Location.y, z = cfg.Location.z })
end

function S.Drop()
    nextId = nextId + 1
    local crate = { id = nextId, x = cfg.Location.x, y = cfg.Location.y, z = cfg.Location.z,
        expires = S.now() + cfg.CrateLifetimeMinutes * 60, team = cfg.Team }
    crates[nextId] = crate
    TriggerClientEvent('nexoro_supplydrop:spawn', -1, { id = crate.id, x = crate.x, y = crate.y, z = crate.z, team = cfg.TeamLabel })
    core().Log('supplydrop', 'dropped', 0, { crate = crate.id })
    return crate.id
end

-- Removes crates nobody claimed in time.
function S.Expire()
    local now = S.now()
    local removed = 0
    for id, c in pairs(crates) do
        if c.expires <= now then
            crates[id] = nil
            removed = removed + 1
            TriggerClientEvent('nexoro_supplydrop:gone', -1, { id = id, reason = 'expired' })
        end
    end
    return removed
end

local function onTeam(src)
    if not cfg.Team then return true end
    local job = core().GetJob(src)
    return job ~= nil and job.name == cfg.Team and job.onDuty == true
end

local function rollLoot()
    local total = 0
    for _, l in ipairs(cfg.Loot) do total = total + l.weight end
    local roll = S.random(1, total)
    local acc = 0
    for _, l in ipairs(cfg.Loot) do
        acc = acc + l.weight
        if roll <= acc then return l end
    end
    return cfg.Loot[#cfg.Loot]
end

-- Claims a crate. Only the team can open it, only one player gets the loot, and only when standing at it.
function S.Claim(src, id)
    local crate = crates[math.tointeger(tonumber(id)) or -1]
    if not crate or crate.expires <= S.now() then return false, 'gone' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if not onTeam(src) then return false, 'not_team' end
    local p = S.getCoords(src)
    if not p or math.sqrt((p.x - crate.x) ^ 2 + (p.y - crate.y) ^ 2 + (p.z - crate.z) ^ 2) > cfg.ClaimRadius + 2.0 then return false, 'too_far' end
    local loot = rollLoot()
    if loot.kind == 'cash' then
        local pence = S.random(loot.min, loot.max)
        core().AddMoney(src, pence / 100, 'cash', 'supply drop')
        crates[crate.id] = nil
        TriggerClientEvent('nexoro_supplydrop:gone', -1, { id = crate.id, reason = 'claimed' })
        core().Log('supplydrop', 'claimed', src, { crate = crate.id, cash = pence })
        return true, { received = core().FormatGBP(pence) }
    end
    local ok, why = exports.nexoro_inventory:AddItem(src, loot.item, loot.amount)
    if not ok then return false, why end
    crates[crate.id] = nil
    TriggerClientEvent('nexoro_supplydrop:gone', -1, { id = crate.id, reason = 'claimed' })
    core().Log('supplydrop', 'claimed', src, { crate = crate.id, item = loot.item })
    return true, { item = loot.item, amount = loot.amount }
end

function S.List()
    local out = {}
    for _, c in pairs(crates) do out[#out + 1] = { id = c.id, x = c.x, y = c.y, z = c.z } end
    return out
end

local function register()
    Core = nil
    core().RegisterCallback('nexoro_supplydrop:claim', function(src, p)
        return S.Claim(src, type(p) == 'table' and p.id or nil)
    end, { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
    core().RegisterCallback('nexoro_supplydrop:list', function() return true, S.List() end,
        { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerReady', function(src)
    for _, c in pairs(crates) do
        TriggerClientEvent('nexoro_supplydrop:spawn', src, { id = c.id, x = c.x, y = c.y, z = c.z, team = cfg.TeamLabel })
    end
end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(cfg.TickSeconds * 1000)
        local h, m = S.clock()
        S.Schedule(h, m)
        S.Expire()
    end
end)

exports('Claim', S.Claim)
