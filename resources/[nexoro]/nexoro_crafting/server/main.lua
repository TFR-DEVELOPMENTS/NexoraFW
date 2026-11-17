local cfg = Config.Crafting
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroCrafting = {}
local C = NexoroCrafting
C.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function findStation(id)
    for _, s in ipairs(cfg.Stations) do if s.id == id then return s end end
    return nil
end
local function findRecipe(id)
    for _, r in ipairs(cfg.Recipes) do if r.id == id then return r end end
    return nil
end

local function atStation(src, station)
    local p = C.getCoords(src)
    if not p then return false end
    return math.sqrt((p.x - station.x) ^ 2 + (p.y - station.y) ^ 2 + (p.z - station.z) ^ 2) <= station.radius + 2.0
end

-- Lists the recipes and what the player is missing for each one.
function C.Recipes(src, stationId)
    local station = findStation(stationId)
    if not station then return false, 'unknown_station' end
    if not atStation(src, station) then return false, 'too_far' end
    local out = {}
    for _, r in ipairs(cfg.Recipes) do
        local missing = {}
        for _, ing in ipairs(r.ingredients) do
            local have = exports.nexoro_inventory:GetItemCount(src, ing.item) or 0
            if have < ing.amount then missing[#missing + 1] = ing.item .. ' x' .. (ing.amount - have) end
        end
        out[#out + 1] = { id = r.id, label = r.label, time = r.time, canMake = #missing == 0, missing = table.concat(missing, ', ') }
    end
    return true, { station = station.label, recipes = out }
end

-- Takes the ingredients, gives the result. If the result will not fit, everything is put back.
function C.Craft(src, stationId, recipeId)
    local station = findStation(stationId)
    if not station then return false, 'unknown_station' end
    if not atStation(src, station) then return false, 'too_far' end
    local recipe = findRecipe(recipeId)
    if not recipe then return false, 'unknown_recipe' end
    for _, ing in ipairs(recipe.ingredients) do
        if (exports.nexoro_inventory:GetItemCount(src, ing.item) or 0) < ing.amount then return false, 'missing_ingredients' end
    end
    local taken = {}
    for _, ing in ipairs(recipe.ingredients) do
        local ok, why = exports.nexoro_inventory:RemoveItem(src, ing.item, ing.amount)
        if not ok then
            for _, t in ipairs(taken) do exports.nexoro_inventory:AddItem(src, t.item, t.amount) end
            return false, why
        end
        taken[#taken + 1] = ing
    end
    local ok, why = exports.nexoro_inventory:AddItem(src, recipe.result.item, recipe.result.amount)
    if not ok then
        for _, t in ipairs(taken) do exports.nexoro_inventory:AddItem(src, t.item, t.amount) end
        return false, why
    end
    core().Log('crafting', 'craft', src, { recipe = recipe.id })
    return true, { made = recipe.result.item, amount = recipe.result.amount }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_crafting:recipes', function(src, p) return C.Recipes(src, arg(p, 'station')) end)
    cb('nexoro_crafting:craft', function(src, p) return C.Craft(src, arg(p, 'station'), arg(p, 'recipe')) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Craft', C.Craft)
exports('Recipes', C.Recipes)
