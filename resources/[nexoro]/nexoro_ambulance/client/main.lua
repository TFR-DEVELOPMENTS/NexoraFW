-- Server-approved revive: brings the player back on the spot with the given health.
RegisterNetEvent('nexoro_ambulance:revive', function(data)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ClearPedTasksImmediately(PlayerPedId())
    SetEntityHealth(PlayerPedId(), math.max(120, math.floor(tonumber(data and data.health) or 150)))
    TriggerEvent('nexoro:notify', { message = 'You have been treated by paramedics.', type = 'success' })
end)
