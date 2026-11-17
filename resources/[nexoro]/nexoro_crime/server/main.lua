local cfg = Config.Crime
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroCrime = {}
local C = NexoroCrime
C.now = os.time
C.random = function(lo, hi) return math.random(lo, hi) end
C.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
-- A network vehicle's position and plate, read on the server. Tests replace this.
C.vehicleOf = function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return nil end
    local c = GetEntityCoords(veh)
    return { x = c.x, y = c.y, z = c.z, plate = GetVehicleNumberPlateText(veh) }
end
C.isOnline = function(characterId) return core().GetSourceByCharacterId(characterId) ~= nil end

local lastTheft = {}     -- [plate] = time
local lastRob = {}       -- [propertyId] = time
local fenceDay = {}      -- [characterId] = { day = n, pence = n }

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function alarm(description, pos)
    TriggerEvent('nexoro:server:alarm', { description = description, x = pos.x, y = pos.y, z = pos.z })
end
local function hasLockpick(src) return (exports.nexoro_inventory:GetItemCount(src, cfg.LockpickItem) or 0) >= 1 end

-- Steals a car that is out on the street and belongs to someone else.
function C.Steal(src, netId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if not hasLockpick(src) then return false, 'no_lockpick' end
    local me = C.getCoords(src)
    local v = C.vehicleOf(tonumber(netId) or -1)
    if not me or not v or not v.plate or distance(me, v) > cfg.Theft.CaptureRadius then return false, 'too_far' end
    local row = NexoroDB.single('SELECT id, owner_id, model, status FROM nexoro_vehicles WHERE plate = ?', { v.plate })
    if not row then return false, 'not_registered' end
    if row.owner_id == c.id then return false, 'own_vehicle' end
    if row.status ~= 'out' then return false, 'not_on_street' end
    local now = C.now()
    if lastTheft[v.plate] and now - lastTheft[v.plate] < cfg.Theft.CooldownMinutes * 60 then return false, 'cooldown' end
    local used, why = exports.nexoro_inventory:RemoveItem(src, cfg.LockpickItem, 1)
    if not used then return false, why end
    lastTheft[v.plate] = now
    alarm(('Vehicle theft reported (%s)'):format(v.plate), me)
    if C.random(1, 100) > cfg.Theft.SuccessChance then return false, 'failed' end
    NexoroDB.insert('INSERT INTO nexoro_vehicle_thefts (plate, thief_id, stolen_at) VALUES (?,?,?)', { v.plate, c.id, now })
    core().Log('crime', 'vehicle_stolen', src, { plate = v.plate })
    local owner = core().GetSourceByCharacterId(row.owner_id)
    if owner then core().Notify(owner, ('Your vehicle %s has been stolen.'):format(v.plate), 'error', 10000) end
    return true, { plate = v.plate, model = row.model }
end

-- A constable on duty recovers a stolen car. It is marked recovered, and the owner is told.
function C.Recover(src, plate)
    local job = core().GetJob(src)
    if not job or job.name ~= 'caledonia_police' or job.onDuty ~= true then return false, 'not_police' end
    local theft = NexoroDB.single('SELECT id, thief_id FROM nexoro_vehicle_thefts WHERE plate = ? AND recovered_at IS NULL ORDER BY id DESC LIMIT 1', { tostring(plate) })
    if not theft then return false, 'no_open_theft' end
    NexoroDB.update('UPDATE nexoro_vehicle_thefts SET recovered_at = ? WHERE id = ?', { C.now(), theft.id })
    return true
end

-- Breaks into a house whose owner is away, and takes up to MaxStacks stacks from its stash.
function C.Rob(src, houseId)
    local house
    for _, h in ipairs(cfg.Robbery.Houses) do if h.id == houseId then house = h end end
    if not house then return false, 'unknown_house' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local me = C.getCoords(src)
    if not me or distance(me, house) > 4.0 then return false, 'too_far' end
    if not hasLockpick(src) then return false, 'no_lockpick' end
    local prop = NexoroDB.single('SELECT owner_id FROM nexoro_properties WHERE id = ?', { house.id })
    if not prop or not prop.owner_id then return false, 'nothing_to_steal' end
    if C.isOnline(prop.owner_id) then return false, 'occupied' end
    local now = C.now()
    if lastRob[house.id] and now - lastRob[house.id] < cfg.Robbery.CooldownMinutes * 60 then return false, 'cooldown' end
    local stash = exports.nexoro_inventory:GetStash('property', house.id, { slots = 40, maxWeight = 60000 })
    if not stash or #stash.items == 0 then return false, 'empty' end
    exports.nexoro_inventory:RemoveItem(src, cfg.LockpickItem, 1)
    lastRob[house.id] = now
    alarm(('Burglary reported at %s'):format(house.label), me)
    local taken, stacks = {}, 0
    for _, entry in ipairs(stash.items) do
        if stacks >= cfg.Robbery.MaxStacks then break end
        local n = math.min(entry.amount, cfg.Robbery.MaxPerStack)
        local out = exports.nexoro_inventory:RemoveItemFromStash('property', house.id, entry.item, n)
        if out then
            local ok = exports.nexoro_inventory:AddItem(src, entry.item, n)
            if not ok then exports.nexoro_inventory:AddItemToStash('property', house.id, entry.item, n, nil, { slots = 40, maxWeight = 60000 })
            else taken[#taken + 1] = { item = entry.item, amount = n }; stacks = stacks + 1 end
        end
    end
    if #taken == 0 then return false, 'no_space' end
    core().Log('crime', 'burglary', src, { house = house.id })
    return true, { taken = taken }
end

local function fenceDayOf(characterId)
    local day = C.now() // 86400
    local rec = fenceDay[characterId]
    if not rec or rec.day ~= day then rec = { day = day, pence = 0 }; fenceDay[characterId] = rec end
    return rec
end

local function atFence(src)
    local p = C.getCoords(src)
    if not p then return false end
    local f = cfg.Fence
    return distance(p, f) <= f.radius + 2.0
end

-- The fence pays a share of the pawn price for stolen goods. Each character has a daily cap.
function C.FenceSell(src, item, amount)
    if not atFence(src) then return false, 'too_far' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local price = cfg.Fence.Buys[item]
    if not price then return false, 'not_wanted' end
    local n = math.tointeger(tonumber(amount)) or 0
    if n < 1 or n > 50 then return false, 'invalid_amount' end
    local pence = math.floor(core().ToPence(price) * cfg.Fence.Share + 0.5) * n
    local rec = fenceDayOf(c.id)
    if rec.pence + pence > core().ToPence(cfg.Fence.DailyCapPounds) then return false, 'daily_cap' end
    if (exports.nexoro_inventory:GetItemCount(src, item) or 0) < n then return false, 'not_enough' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, item, n)
    if not removed then return false, why end
    core().AddMoney(src, pence / 100, 'cash', 'fence')
    rec.pence = rec.pence + pence
    if C.random(1, 100) <= cfg.Fence.AlarmChance then alarm('Suspicious sale reported at the back-room fence', C.getCoords(src)) end
    return true, { received = core().FormatGBP(pence) }
end

function C.FenceBuy(src, item, amount)
    if not atFence(src) then return false, 'too_far' end
    local price = cfg.Fence.Sells[item]
    if not price then return false, 'not_for_sale' end
    local n = math.tointeger(tonumber(amount)) or 0
    if n < 1 or n > 10 then return false, 'invalid_amount' end
    local pence = core().ToPence(price) * n
    local ok, why = core().RemoveMoney(src, pence / 100, 'cash', 'fence buy')
    if not ok then return false, why end
    local added, awhy = exports.nexoro_inventory:AddItem(src, item, n)
    if not added then core().AddMoney(src, pence / 100, 'cash', 'refund'); return false, awhy end
    return true, { paid = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_crime:steal', function(src, p) return C.Steal(src, arg(p, 'netId')) end, 5)
    cb('nexoro_crime:recover', function(src, p) return C.Recover(src, arg(p, 'plate')) end, 10)
    cb('nexoro_crime:rob', function(src, p) return C.Rob(src, arg(p, 'house')) end, 5)
    cb('nexoro_crime:fenceSell', function(src, p) return C.FenceSell(src, arg(p, 'item'), arg(p, 'amount')) end, 10)
    cb('nexoro_crime:fenceBuy', function(src, p) return C.FenceBuy(src, arg(p, 'item'), arg(p, 'amount')) end, 10)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Steal', C.Steal)
exports('Rob', C.Rob)
exports('FenceSell', C.FenceSell)
