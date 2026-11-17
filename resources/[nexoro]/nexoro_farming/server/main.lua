local cfg = Config.Farming
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroFarming = {}
local F = NexoroFarming
F.now = os.time
F.random = function(lo, hi) return math.random(lo, hi) end
F.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function plotOf(id)
    for _, p in ipairs(cfg.Plots) do if p.id == id then return p end end
    return nil
end

local function near(src, plot)
    local p = F.getCoords(src)
    if not p then return false end
    return math.sqrt((p.x - plot.x) ^ 2 + (p.y - plot.y) ^ 2 + (p.z - plot.z) ^ 2) <= plot.radius + 2.0
end

function F.Plant(src, plotId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local plot = plotOf(plotId)
    if not plot then return false, 'unknown_plot' end
    if not near(src, plot) then return false, 'too_far' end
    if NexoroDB.scalar('SELECT 1 FROM nexoro_farm_plots WHERE plot_id = ?', { plot.id }) then return false, 'occupied' end
    local removed, why = exports.nexoro_inventory:RemoveItem(src, cfg.Seed, 1)
    if not removed then return false, why end
    local affected = NexoroDB.update('INSERT IGNORE INTO nexoro_farm_plots (plot_id, character_id, crop, planted_at) VALUES (?,?,?,?)',
        { plot.id, c.id, cfg.Crop, F.now() })
    if affected ~= 1 then
        exports.nexoro_inventory:AddItem(src, cfg.Seed, 1)
        return false, 'occupied'
    end
    core().Log('farming', 'planted', src, { plot = plot.id })
    return true, { ready_in = cfg.GrowthMinutes * 60 }
end

-- Harvests a ready crop. Only the planter can harvest, and a full inventory keeps the crop in the ground.
function F.Harvest(src, plotId)
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local plot = plotOf(plotId)
    if not plot then return false, 'unknown_plot' end
    if not near(src, plot) then return false, 'too_far' end
    local row = NexoroDB.single('SELECT character_id, crop, planted_at FROM nexoro_farm_plots WHERE plot_id = ?', { plot.id })
    if not row then return false, 'empty' end
    if row.character_id ~= c.id then return false, 'not_yours' end
    local now = F.now()
    local readyAt = row.planted_at + cfg.GrowthMinutes * 60
    if now < readyAt then return false, 'not_ready', readyAt - now end
    local amount = F.random(cfg.YieldMin, cfg.YieldMax)
    local ok, why = exports.nexoro_inventory:AddItem(src, row.crop, amount)
    if not ok then return false, why end
    NexoroDB.update('DELETE FROM nexoro_farm_plots WHERE plot_id = ? AND character_id = ?', { plot.id, c.id })
    core().Log('farming', 'harvested', src, { plot = plot.id, amount = amount })
    return true, { crop = row.crop, amount = amount }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_farming:plant', function(src, p) return F.Plant(src, arg(p, 'plot')) end, 20)
    cb('nexoro_farming:harvest', function(src, p) return F.Harvest(src, arg(p, 'plot')) end, 20)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Plant', F.Plant)
exports('Harvest', F.Harvest)
