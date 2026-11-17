local cfg = Config.Hud
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroHud = {}
local state = {}       -- [src] = { hunger, thirst, stress } as floats (so fractional decay works)
local writing = false  -- ignore our own metadata writes

local function clamp(v) if v < 0 then return 0 end if v > 100 then return 100 end return v end

local function readNeeds(src)
    local C = core()
    return {
        hunger = tonumber(C.GetMetadata(src, 'hunger')) or 100.0,
        thirst = tonumber(C.GetMetadata(src, 'thirst')) or 100.0,
        stress = tonumber(C.GetMetadata(src, 'stress')) or 0.0,
    }
end

local function push(src)
    local s = state[src]
    if not s then return end
    TriggerClientEvent('nexoro_hud:needs', src, { hunger = math.floor(s.hunger + 0.5), thirst = math.floor(s.thirst + 0.5), stress = math.floor(s.stress + 0.5) })
end

local function persist(src, key, value)
    writing = true
    core().SetMetadata(src, key, math.floor(value + 0.5))
    writing = false
end

function NexoroHud.GetNeeds(src) return state[src] and { hunger = state[src].hunger, thirst = state[src].thirst, stress = state[src].stress } or nil end

-- One decay step for one player. Writes metadata only when the whole-number value changes.
function NexoroHud.Tick(src)
    local s = state[src]
    if not s then return false end
    local minutes = cfg.TickSeconds / 60
    local before = { hunger = math.floor(s.hunger + 0.5), thirst = math.floor(s.thirst + 0.5), stress = math.floor(s.stress + 0.5) }
    s.hunger = clamp(s.hunger - cfg.HungerPerMinute * minutes)
    s.thirst = clamp(s.thirst - cfg.ThirstPerMinute * minutes)
    s.stress = clamp(s.stress - cfg.StressRecoveryPerMinute * minutes)
    for _, key in ipairs({ 'hunger', 'thirst', 'stress' }) do
        if math.floor(s[key] + 0.5) ~= before[key] then persist(src, key, s[key]) end
    end
    if s.hunger <= 0 or s.thirst <= 0 then TriggerClientEvent('nexoro_hud:starving', src, cfg.StarvationDamage) end
    push(src)
    return true
end

function NexoroHud.AddStress(src, amount)
    local s = state[src]
    amount = tonumber(amount)
    if not s or not amount or amount ~= amount then return false end
    s.stress = clamp(s.stress + amount)
    persist(src, 'stress', s.stress)
    push(src)
    return true
end

function NexoroHud.SetNeed(src, key, value)
    local s = state[src]
    value = tonumber(value)
    if not s or not s[key] or not value or value ~= value then return false end
    s[key] = clamp(value)
    persist(src, key, s[key])
    push(src)
    return true
end

function NexoroHud.Load(src)
    state[src] = readNeeds(src)
    push(src)
end

AddEventHandler('nexoro:server:characterLoaded', function(src)
    CreateThread(function() NexoroHud.Load(src) end)
end)
AddEventHandler('nexoro:server:characterUnloaded', function(src) state[src] = nil end)
AddEventHandler('nexoro:server:playerDropped', function(src) state[src] = nil end)

-- Items (water, sandwich...) change metadata directly; keep the HUD in step.
AddEventHandler('nexoro:server:metadataChanged', function(src, key, value)
    if writing or not state[src] or (key ~= 'hunger' and key ~= 'thirst' and key ~= 'stress') then return end
    state[src][key] = clamp(tonumber(value) or state[src][key])
    push(src)
end)

CreateThread(function()
    while true do
        Wait(cfg.TickSeconds * 1000)
        for src in pairs(state) do
            NexoroHud.Tick(src)
            Wait(50)
        end
    end
end)

-- Players already in game when this resource (re)starts.
CreateThread(function()
    Wait(1000)
    local ok, players = pcall(function() return core().GetPlayers() end)
    if not ok then return end
    for _, p in ipairs(players) do
        if p.hasCharacter then state[p.source] = readNeeds(p.source); push(p.source) end
    end
end)

exports('GetNeeds', NexoroHud.GetNeeds)
exports('AddStress', NexoroHud.AddStress)
exports('SetNeed', NexoroHud.SetNeed)
