local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'warning', duration = 8000 }) end

local function teleport(p)
    local ped = PlayerPedId()
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (p.heading or 0.0) + 0.0)
end

RegisterNetEvent('nexoro_prison:enter', function(data)
    if type(data) ~= 'table' or type(data.cell) ~= 'table' then return end
    teleport(data.cell)
    notify('You are in prison. Keep out of trouble until your sentence ends.', 'warning')
end)

RegisterNetEvent('nexoro_prison:release', function(data)
    if type(data) ~= 'table' or type(data.release) ~= 'table' then return end
    teleport(data.release)
end)
