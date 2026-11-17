local cfg = Config.SupplyDrop
local crates = {}           -- [id] = { x, y, z, blip }
local announced = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

RegisterNetEvent('nexoro_supplydrop:announce', function(a)
    if type(a) ~= 'table' then return end
    announced = a
    SetNewWaypoint(a.x + 0.0, a.y + 0.0)
end)

RegisterNetEvent('nexoro_supplydrop:spawn', function(c)
    if type(c) ~= 'table' or crates[c.id] then return end
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 501); SetBlipColour(blip, 5); SetBlipScale(blip, 0.9); SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Supply drop'); EndTextCommandSetBlipName(blip)
    crates[c.id] = { x = c.x, y = c.y, z = c.z, blip = blip }
    notify('A supply drop has landed at ' .. cfg.Location.label .. '.', 'emergency')
end)

RegisterNetEvent('nexoro_supplydrop:gone', function(g)
    if type(g) ~= 'table' then return end
    local c = crates[g.id]
    if c then RemoveBlip(c.blip); crates[g.id] = nil end
end)

local function claim(id)
    CreateThread(function()
        local ok, r = NexoroCore.Callback('nexoro_supplydrop:claim', { id = id })
        if not ok then
            if r == 'not_team' then return notify(('Only %s can open this crate.'):format(cfg.TeamLabel or 'the team'), 'error') end
            return notify('Crate: ' .. tostring(r), 'error')
        end
        if r.received then notify(('Crate opened: %s found.'):format(r.received), 'success')
        else notify(('Crate opened: %d × %s.'):format(r.amount, r.item), 'success') end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for id, c in pairs(crates) do
                if #(pos - vector3(c.x, c.y, c.z)) < cfg.ClaimRadius then found = id; break end
            end
            if found then
                exports.nexoro_ui:ShowTextUI('Open supply crate: E', 'E')
                wait = 0
                if IsControlJustPressed(0, 38) then claim(found) end
            end
        end
        Wait(wait)
    end
end)
