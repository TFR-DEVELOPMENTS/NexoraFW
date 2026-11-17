local cfg = Config.Inventory
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

local items, usable = {}, {}
local cache, byOwner = {}, {}

---------------------------------------------------------------------------
-- Item registry
---------------------------------------------------------------------------

local function registerItem(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' or not def.name:match('^[a-z0-9_]+$') or #def.name > 50 then return false, 'invalid_name' end
    if type(def.label) ~= 'string' or def.label == '' then return false, 'invalid_label' end
    local weight = math.tointeger(tonumber(def.weight or 0) or -1)
    if not weight or weight < 0 or weight > 1000000 then return false, 'invalid_weight' end
    local stack = def.stack ~= false
    items[def.name] = {
        name = def.name, label = def.label, weight = weight, stack = stack, maxStack = stack and (def.maxStack or cfg.DefaultMaxStack) or 1,
        consume = def.consume ~= false, description = def.description or '',
    }
    if type(def.onUse) == 'function' then usable[def.name] = def.onUse end
    return true
end

for name, def in pairs(Config.Items) do
    def.name = name
    registerItem(def)
end

---------------------------------------------------------------------------
-- Persistence and cache
---------------------------------------------------------------------------

local function decodeMeta(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and type(data) == 'table' and data or {}
end

local function loadInventory(ownerType, ownerId, defaults)
    local key = ownerType .. ':' .. tostring(ownerId)
    if byOwner[key] then return cache[byOwner[key]] end
    defaults = defaults or {}
    local row = NexoroDB.single('SELECT id, slots, max_weight_g FROM nexoro_inventories WHERE owner_type = ? AND owner_id = ?', { ownerType, tostring(ownerId) })
    if not row then
        NexoroDB.update('INSERT IGNORE INTO nexoro_inventories (owner_type, owner_id, label, slots, max_weight_g) VALUES (?,?,?,?,?)',
            { ownerType, tostring(ownerId), defaults.label or '', defaults.slots or cfg.PlayerSlots, defaults.maxWeight or math.floor(cfg.PlayerMaxWeightKg * 1000) })
        row = NexoroDB.single('SELECT id, slots, max_weight_g FROM nexoro_inventories WHERE owner_type = ? AND owner_id = ?', { ownerType, tostring(ownerId) })
    end
    if not row then return nil end
    if byOwner[key] then return cache[byOwner[key]] end
    local inv = { id = row.id, key = key, slots = row.slots, maxWeight = row.max_weight_g, items = {}, busy = false }
    for _, r in ipairs(NexoroDB.query('SELECT slot, item, amount, metadata FROM nexoro_inventory_items WHERE inventory_id = ?', { row.id }) or {}) do
        inv.items[r.slot] = { item = r.item, amount = r.amount, metadata = decodeMeta(r.metadata) }
    end
    cache[inv.id], byOwner[key] = inv, inv.id
    return inv
end

local function forget(ownerType, ownerId)
    local key = ownerType .. ':' .. tostring(ownerId)
    local id = byOwner[key]
    if id then cache[id] = nil; byOwner[key] = nil end
end

local function inventoryForPlayer(src)
    local c = core().GetCharacter(src)
    if not c then return nil, 'no_character' end
    local inv = loadInventory('character', c.id)
    if not inv then return nil, 'database_error' end
    return inv
end

---------------------------------------------------------------------------
-- Planning: every change is computed on a copy, saved in ONE transaction, then applied to memory.
---------------------------------------------------------------------------

local function copyMeta(m) local c = {}; for k, v in pairs(m or {}) do c[k] = v end; return c end
local function sameMeta(a, b)
    a, b = a or {}, b or {}
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function newPlan(inv) return { inv = inv, changes = {} } end
local function get(plan, slot)
    local ch = plan.changes[slot]
    if ch == false then return nil end
    if ch ~= nil then return ch end
    return plan.inv.items[slot]
end
local function put(plan, slot, entry) plan.changes[slot] = entry or false end

local function planWeight(plan)
    local total = 0
    for slot = 1, plan.inv.slots do
        local e = get(plan, slot)
        if e and items[e.item] then total = total + items[e.item].weight * e.amount end
    end
    return total
end

local function commit(plan)
    local queries = {}
    for slot, entry in pairs(plan.changes) do
        if entry == false then
            queries[#queries + 1] = { query = 'DELETE FROM nexoro_inventory_items WHERE inventory_id = ? AND slot = ?', values = { plan.inv.id, slot } }
        else
            queries[#queries + 1] = {
                query = 'INSERT INTO nexoro_inventory_items (inventory_id, slot, item, amount, metadata) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE item = VALUES(item), amount = VALUES(amount), metadata = VALUES(metadata)',
                values = { plan.inv.id, slot, entry.item, entry.amount, next(entry.metadata or {}) and json.encode(entry.metadata) or '' },
            }
        end
    end
    if #queries == 0 then return true end
    if not NexoroDB.transaction(queries) then return false end
    for slot, entry in pairs(plan.changes) do plan.inv.items[slot] = entry or nil end
    return true
end

local function locked(inv, fn)
    local waited = 0
    while inv.busy and waited < 200 do Wait(10); waited = waited + 1 end
    if inv.busy then return false, 'busy' end
    inv.busy = true
    local ok, a, b = pcall(fn)
    inv.busy = false
    if not ok then print(('^1[Nexoro] inventory error: %s^7'):format(tostring(a))); return false, 'server_error' end
    return a, b
end

local function planAdd(plan, name, amount, metadata)
    local def = items[name]
    if not def then return false, 'unknown_item' end
    amount = math.tointeger(tonumber(amount) or 0)
    if not amount or amount < 1 or amount > 10000 then return false, 'invalid_amount' end
    if planWeight(plan) + def.weight * amount > plan.inv.maxWeight then return false, 'too_heavy' end
    local remaining = amount
    if def.maxStack > 1 then
        for slot = 1, plan.inv.slots do
            local e = get(plan, slot)
            if e and e.item == name and e.amount < def.maxStack and sameMeta(e.metadata, metadata) then
                local add = math.min(remaining, def.maxStack - e.amount)
                put(plan, slot, { item = name, amount = e.amount + add, metadata = copyMeta(e.metadata) })
                remaining = remaining - add
                if remaining == 0 then break end
            end
        end
    end
    for slot = 1, plan.inv.slots do
        if remaining == 0 then break end
        if not get(plan, slot) then
            local add = math.min(remaining, def.maxStack)
            put(plan, slot, { item = name, amount = add, metadata = copyMeta(metadata) })
            remaining = remaining - add
        end
    end
    if remaining > 0 then return false, 'no_space' end
    return true
end

local function planRemove(plan, name, amount)
    amount = math.tointeger(tonumber(amount) or 0)
    if not amount or amount < 1 or amount > 100000 then return false, 'invalid_amount' end
    local have = 0
    for slot = 1, plan.inv.slots do
        local e = get(plan, slot)
        if e and e.item == name then have = have + e.amount end
    end
    if have < amount then return false, 'not_enough' end
    local remaining = amount
    for slot = 1, plan.inv.slots do
        local e = get(plan, slot)
        if e and e.item == name and remaining > 0 then
            local take = math.min(remaining, e.amount)
            if take == e.amount then put(plan, slot, nil)
            else put(plan, slot, { item = name, amount = e.amount - take, metadata = copyMeta(e.metadata) }) end
            remaining = remaining - take
        end
    end
    return true
end

local function weightOf(inv)
    local total = 0
    for _, e in pairs(inv.items) do if items[e.item] then total = total + items[e.item].weight * e.amount end end
    return total
end

local function view(inv)
    local list = {}
    for slot, e in pairs(inv.items) do
        local def = items[e.item] or { label = e.item, weight = 0, description = '', maxStack = 1 }
        list[#list + 1] = { slot = slot, item = e.item, label = def.label, amount = e.amount, weight = def.weight, description = def.description, stackable = def.maxStack > 1, metadata = e.metadata }
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return { id = inv.id, slots = inv.slots, maxWeight = inv.maxWeight, weight = weightOf(inv), items = list }
end

local function pushUpdate(src, inv)
    TriggerClientEvent('nexoro_inventory:update', src, view(inv))
end

---------------------------------------------------------------------------
-- Public operations
---------------------------------------------------------------------------

local function mutate(inv, build)
    return locked(inv, function()
        local plan = newPlan(inv)
        local ok, err = build(plan)
        if not ok then return false, err end
        if not commit(plan) then return false, 'database_error' end
        return true
    end)
end

local function addItemTo(inv, name, amount, metadata)
    return mutate(inv, function(plan) return planAdd(plan, name, amount, metadata) end)
end
local function removeItemFrom(inv, name, amount)
    return mutate(inv, function(plan) return planRemove(plan, name, amount) end)
end

local function addItem(src, name, amount, metadata)
    local inv, err = inventoryForPlayer(src)
    if not inv then return false, err end
    local ok, why = addItemTo(inv, name, amount, metadata)
    if ok then pushUpdate(src, inv); core().Log('inventory', 'add', src, { item = name, amount = amount }) end
    return ok, why
end

local function removeItem(src, name, amount)
    local inv, err = inventoryForPlayer(src)
    if not inv then return false, err end
    local ok, why = removeItemFrom(inv, name, amount)
    if ok then pushUpdate(src, inv); core().Log('inventory', 'remove', src, { item = name, amount = amount }) end
    return ok, why
end

local function getCount(src, name)
    local inv = inventoryForPlayer(src)
    if not inv then return 0 end
    local total = 0
    for _, e in pairs(inv.items) do if e.item == name then total = total + e.amount end end
    return total
end

local function moveItem(src, from, to, amount)
    local inv, err = inventoryForPlayer(src)
    if not inv then return false, err end
    from, to = math.tointeger(tonumber(from) or 0), math.tointeger(tonumber(to) or 0)
    if not from or not to or from < 1 or to < 1 or from > inv.slots or to > inv.slots then return false, 'invalid_slot' end
    if from == to then return true end
    local ok, why = mutate(inv, function(plan)
        local a = get(plan, from)
        if not a then return false, 'empty_slot' end
        amount = math.tointeger(tonumber(amount or a.amount) or 0)
        if not amount or amount < 1 or amount > a.amount then return false, 'invalid_amount' end
        local def = items[a.item]
        local b = get(plan, to)
        if not b then
            put(plan, to, { item = a.item, amount = amount, metadata = copyMeta(a.metadata) })
            if amount == a.amount then put(plan, from, nil) else put(plan, from, { item = a.item, amount = a.amount - amount, metadata = copyMeta(a.metadata) }) end
        elseif def and b.item == a.item and def.maxStack > 1 and sameMeta(a.metadata, b.metadata) then
            local moved = math.min(amount, def.maxStack - b.amount)
            if moved <= 0 then return false, 'stack_full' end
            put(plan, to, { item = b.item, amount = b.amount + moved, metadata = copyMeta(b.metadata) })
            if moved == a.amount then put(plan, from, nil) else put(plan, from, { item = a.item, amount = a.amount - moved, metadata = copyMeta(a.metadata) }) end
        else
            if amount ~= a.amount then return false, 'invalid_move' end
            put(plan, to, { item = a.item, amount = a.amount, metadata = copyMeta(a.metadata) })
            put(plan, from, { item = b.item, amount = b.amount, metadata = copyMeta(b.metadata) })
        end
        return true
    end)
    if ok then pushUpdate(src, inv) end
    return ok, why
end

local function useItem(src, slot)
    local inv, err = inventoryForPlayer(src)
    if not inv then return false, err end
    slot = math.tointeger(tonumber(slot) or 0)
    local entry = slot and inv.items[slot]
    if not entry then return false, 'empty_slot' end
    local def = items[entry.item]
    local handler = usable[entry.item]
    if not def or not handler then return false, 'not_usable' end
    local okCall, result = pcall(handler, src, core(), entry)
    if not okCall then print(('^1[Nexoro] item handler error (%s): %s^7'):format(entry.item, tostring(result))); return false, 'server_error' end
    if result == false then return false, 'cancelled' end
    if def.consume then
        -- re-check the slot still holds the item (it may have changed while the handler ran)
        local current = inv.items[slot]
        if not current or current.item ~= entry.item then return false, 'item_changed' end
        local ok = mutate(inv, function(plan)
            local e = get(plan, slot)
            if e.amount == 1 then put(plan, slot, nil) else put(plan, slot, { item = e.item, amount = e.amount - 1, metadata = copyMeta(e.metadata) }) end
            return true
        end)
        if not ok then return false, 'database_error' end
    end
    core().Log('inventory', 'use', src, { item = entry.item })
    pushUpdate(src, inv)
    return true
end

local function clearInventory(src)
    local inv, err = inventoryForPlayer(src)
    if not inv then return false, err end
    local ok, why = mutate(inv, function(plan)
        for slot in pairs(inv.items) do put(plan, slot, nil) end
        return true
    end)
    if ok then pushUpdate(src, inv) end
    return ok, why
end

local function getInventory(src)
    local inv = inventoryForPlayer(src)
    return inv and view(inv) or nil
end

-- Stashes, boots, gloveboxes, evidence lockers, etc: any owner type and id.
local function stash(ownerType, ownerId, opts)
    if type(ownerType) ~= 'string' or not ownerType:match('^[a-z_]+$') or ownerType == 'character' then return nil end
    opts = opts or {}
    return loadInventory(ownerType, ownerId, { label = opts.label, slots = opts.slots, maxWeight = opts.maxWeight })
end

---------------------------------------------------------------------------
-- Registration, lifecycle, exports
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    C.RegisterCallback('nexoro_inventory:get', function(src)
        local inv, err = inventoryForPlayer(src)
        if not inv then return false, err end
        return true, view(inv)
    end, { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } })
    C.RegisterCallback('nexoro_inventory:move', function(src, p)
        if type(p) ~= 'table' then return false, 'invalid_request' end
        return moveItem(src, p.from, p.to, p.amount)
    end, { requireCharacter = true, rateLimit = { max = 40, windowMs = 10000 } })
    C.RegisterCallback('nexoro_inventory:use', function(src, p)
        if type(p) ~= 'table' then return false, 'invalid_request' end
        return useItem(src, p.slot)
    end, { requireCharacter = true, rateLimit = { max = 10, windowMs = 5000 } })
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:characterLoaded', function(src) CreateThread(function() inventoryForPlayer(src) end) end)
AddEventHandler('nexoro:server:characterUnloaded', function(_, characterId) forget('character', characterId) end)
AddEventHandler('nexoro:server:characterDeleted', function(_, characterId)
    forget('character', characterId)
    NexoroDB.update('DELETE FROM nexoro_inventories WHERE owner_type = ? AND owner_id = ?', { 'character', tostring(characterId) })
end)

CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('RegisterItem', registerItem)
exports('RegisterUsableItem', function(name, fn) if items[name] and type(fn) == 'function' then usable[name] = fn; return true end return false end)
exports('GetItemDefinition', function(name) return items[name] end)
exports('GetInventory', getInventory)
exports('AddItem', addItem)
exports('RemoveItem', removeItem)
exports('HasItem', function(src, name, amount) return getCount(src, name) >= (amount or 1) end)
exports('GetItemCount', getCount)
exports('MoveItem', moveItem)
exports('UseItem', useItem)
exports('ClearInventory', clearInventory)
exports('AddItemToStash', function(ownerType, ownerId, name, amount, metadata, opts)
    local inv = stash(ownerType, ownerId, opts)
    if not inv then return false, 'invalid_stash' end
    return addItemTo(inv, name, amount, metadata)
end)
exports('RemoveItemFromStash', function(ownerType, ownerId, name, amount)
    local inv = stash(ownerType, ownerId)
    if not inv then return false, 'invalid_stash' end
    return removeItemFrom(inv, name, amount)
end)
exports('GetStash', function(ownerType, ownerId, opts) local inv = stash(ownerType, ownerId, opts); return inv and view(inv) or nil end)
