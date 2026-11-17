local cfg = Config.Hunting
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroHunting = {}
local H = NexoroHunting
H.now = os.time
H.random = function(n) return math.random(1, n) end
H.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local lastHunt = {}

local function spotOf(id)
    for _, s in ipairs(cfg.Spots) do if s.id == id then return s end end
    return nil
end

local function pickCatch()
    local total = 0
    for _, c in ipairs(cfg.Catches) do total = total + c.weight end
    local roll = H.random(total)
    local acc = 0
    for _, c in ipairs(cfg.Catches) do
        acc = acc + c.weight
        if roll <= acc then return c.item end
    end
    return nil
end

-- Hunting needs the licence, being in the spot, and a rest between tries. Nothing caught is a valid outcome.
function H.Hunt(src, spotId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local spot = spotOf(spotId)
    if not spot then return false, 'unknown_spot' end
    if not exports.nexoro_licences:Has(c.id, 'hunting') then return false, 'no_licence' end
    local p = H.getCoords(src)
    if not p or math.sqrt((p.x - spot.x) ^ 2 + (p.y - spot.y) ^ 2 + (p.z - spot.z) ^ 2) > spot.radius then return false, 'too_far' end
    local now = H.now()
    if lastHunt[src] and now - lastHunt[src] < cfg.CooldownSeconds then
        return false, 'cooldown', cfg.CooldownSeconds - (now - lastHunt[src])
    end
    lastHunt[src] = now
    local item = pickCatch()
    if not item then return true, { item = nil } end
    local ok, why = exports.nexoro_inventory:AddItem(src, item, 1)
    if not ok then return false, why end
    core().Log('hunting', 'catch', src, { item = item, spot = spotId })
    return true, { item = item, label = (exports.nexoro_inventory:GetItemDefinition(item) or {}).label or item }
end

local function register()
    Core = nil
    core().RegisterCallback('nexoro_hunting:hunt', function(src, p)
        return H.Hunt(src, type(p) == 'table' and p.spot or nil)
    end, { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src) lastHunt[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Hunt', H.Hunt)
