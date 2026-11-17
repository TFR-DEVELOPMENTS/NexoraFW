local cfg = Config.Fishing
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroFishing = {}
local F = NexoroFishing
F.now = os.time
F.random = function(n) return math.random(1, n) end
F.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local lastCast = {}

local function spotOf(id)
    for _, s in ipairs(cfg.Spots) do if s.id == id then return s end end
    return nil
end

local function pickCatch()
    local total = 0
    for _, c in ipairs(cfg.Catches) do total = total + c.weight end
    local roll = F.random(total)
    local acc = 0
    for _, c in ipairs(cfg.Catches) do
        acc = acc + c.weight
        if roll <= acc then return c.item end
    end
    return cfg.Catches[#cfg.Catches].item
end

function F.Cast(src, spotId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local spot = spotOf(spotId)
    if not spot then return false, 'unknown_spot' end
    if not exports.nexoro_licences:Has(c.id, 'fishing') then return false, 'no_licence' end
    local p = F.getCoords(src)
    if not p or math.sqrt((p.x - spot.x) ^ 2 + (p.y - spot.y) ^ 2 + (p.z - spot.z) ^ 2) > spot.radius + 2.0 then return false, 'too_far' end
    local now = F.now()
    if lastCast[src] and now - lastCast[src] < cfg.CooldownSeconds then
        return false, 'cooldown', cfg.CooldownSeconds - (now - lastCast[src])
    end
    lastCast[src] = now
    local item = pickCatch()
    local ok, why = exports.nexoro_inventory:AddItem(src, item, 1)
    if not ok then return false, why end
    core().Log('fishing', 'catch', src, { item = item, spot = spotId })
    return true, { item = item, label = (exports.nexoro_inventory:GetItemDefinition(item) or {}).label or item }
end

local function register()
    Core = nil
    local K = core()
    K.RegisterCallback('nexoro_fishing:cast', function(src, p)
        return F.Cast(src, type(p) == 'table' and p.spot or nil)
    end, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src) lastCast[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Cast', F.Cast)
