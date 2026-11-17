local cfg = Config.Map
local incidents, hazardBlips, unitBlips = {}, {}, {}

-- Always-visible places
CreateThread(function()
    for _, b in ipairs(cfg.Static) do
        local blip = AddBlipForCoord(b.x, b.y, b.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.colour)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Incidents (only units and dispatchers receive these alerts)
RegisterNetEvent('nexoro_dispatch:alert', function(a)
    if type(a) ~= 'table' or type(a.id) ~= 'number' or type(a.x) ~= 'number' then return end
    if incidents[a.id] then RemoveBlip(incidents[a.id]) end
    local blip = AddBlipForCoord(a.x, a.y, a.z)
    SetBlipSprite(blip, cfg.IncidentSprite)
    SetBlipColour(blip, cfg.IncidentColour[a.priority] or 5)
    SetBlipFlashes(blip, a.priority == 1)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Incident %d - %s'):format(a.id, tostring(a.label or '')))
    EndTextCommandSetBlipName(blip)
    incidents[a.id] = blip
end)

RegisterNetEvent('nexoro_dispatch:closed', function(d)
    local blip = type(d) == 'table' and incidents[d.id]
    if blip then RemoveBlip(blip); incidents[d.id] = nil end
end)

-- Hazard zones: a red radius and a marker
RegisterNetEvent('nexoro_fire:hazards', function(list)
    if type(list) ~= 'table' then return end
    local seen = {}
    for _, h in ipairs(list) do
        seen[h.id] = true
        if not hazardBlips[h.id] then
            local ring = AddBlipForRadius(h.x, h.y, h.z, h.radius + 0.0)
            SetBlipColour(ring, 1)
            SetBlipAlpha(ring, 110)
            local marker = AddBlipForCoord(h.x, h.y, h.z)
            SetBlipSprite(marker, 436)
            SetBlipColour(marker, 1)
            SetBlipScale(marker, 0.7)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Hazard zone')
            EndTextCommandSetBlipName(marker)
            hazardBlips[h.id] = { ring, marker }
        end
    end
    for id, pair in pairs(hazardBlips) do
        if not seen[id] then RemoveBlip(pair[1]); RemoveBlip(pair[2]); hazardBlips[id] = nil end
    end
end)

-- Unit positions for emergency services
RegisterNetEvent('nexoro_map:units', function(list)
    if type(list) ~= 'table' then return end
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, u in ipairs(list) do
        if u.src ~= me then
            seen[u.src] = true
            local label = ('%s · %s'):format(u.callsign ~= '' and u.callsign or 'Unit', tostring(u.status))
            local entry = unitBlips[u.src]
            if entry and entry.label ~= label then RemoveBlip(entry.blip); entry = nil end
            if not entry then
                local blip = AddBlipForCoord(u.x, u.y, u.z)
                SetBlipSprite(blip, 1)
                SetBlipScale(blip, 0.8)
                SetBlipColour(blip, cfg.CategoryColour[u.category] or 0)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(label)
                EndTextCommandSetBlipName(blip)
                entry = { blip = blip, label = label }
                unitBlips[u.src] = entry
            end
            SetBlipCoords(entry.blip, u.x, u.y, u.z)
        end
    end
    for src, entry in pairs(unitBlips) do
        if not seen[src] then RemoveBlip(entry.blip); unitBlips[src] = nil end
    end
end)
