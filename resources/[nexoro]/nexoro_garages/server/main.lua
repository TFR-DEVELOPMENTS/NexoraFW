local cfg = Config
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroGarages = {}
NexoroGarages.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function near(src, garage)
    local def = cfg.Garages[garage]
    if not def then return nil, 'unknown_garage' end
    local pos = NexoroGarages.getCoords(src)
    if not pos then return nil, 'no_position' end
    if math.sqrt((pos.x - def.x) ^ 2 + (pos.y - def.y) ^ 2 + (pos.z - def.z) ^ 2) > def.radius + 6.0 then return nil, 'too_far' end
    return def
end

local function listAt(src, p)
    local garage = type(p) == 'table' and p.garage or nil
    local def, why = near(src, garage)
    if not def then return false, why end
    local ok, all = exports.nexoro_vehicles:ListFor(src)
    if not ok then return false, all end
    local out = {}
    for _, v in ipairs(all) do
        if v.mine then
            if def.type == 'impound' and v.status == 'impounded' then out[#out + 1] = v
            elseif def.type == 'public' and v.status == 'stored' and v.garage == garage then out[#out + 1] = v
            elseif def.type == 'public' and v.status == 'out' then out[#out + 1] = v end
        end
    end
    return true, { garage = { id = garage, label = def.label, type = def.type }, vehicles = out }
end

local function retrieve(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.garage)
    if not def then return false, why end
    local index = math.tointeger(tonumber(p.spawnIndex or 1)) or 1
    local spawn = def.spawns[index]
    if not spawn then return false, 'invalid_spawn' end
    local ok, data = exports.nexoro_vehicles:Spawn(src, p.plate, p.garage)
    if not ok then return false, data end
    return true, { vehicle = data, spawn = spawn }
end

local function store(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.garage)
    if not def then return false, why end
    if def.type ~= 'public' then return false, 'cannot_store_here' end
    return exports.nexoro_vehicles:Store(src, p.plate, p.garage, p.state)
end

local function release(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.garage)
    if not def then return false, why end
    if def.type ~= 'impound' then return false, 'not_an_impound_lot' end
    return exports.nexoro_vehicles:ReleaseImpound(src, p.plate, p.garage, p.account)
end

local function register()
    Core = nil
    local C = core()
    local opts = { requireCharacter = true, rateLimit = { max = 12, windowMs = 10000 } }
    C.RegisterCallback('nexoro_garages:list', listAt, opts)
    C.RegisterCallback('nexoro_garages:retrieve', retrieve, opts)
    C.RegisterCallback('nexoro_garages:store', store, opts)
    C.RegisterCallback('nexoro_garages:release', release, opts)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)
