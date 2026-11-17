-- Teleport and heal for the dev tools (server sends the request; the client does the work).
RegisterNetEvent('nexoro_devtools:teleport', function(p)
    if type(p) ~= 'table' then return end
    SetEntityCoords(PlayerPedId(), p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
end)

RegisterNetEvent('nexoro_devtools:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)
