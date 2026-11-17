local cfg = Config
local inside = nil      -- garage id the player is standing in
local menuBusy = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local ERR = {
    not_stored = 'That vehicle is not in storage.', wrong_garage = 'That vehicle is stored at a different garage.', too_far = 'Move closer to the garage.',
    no_character = 'Choose a character first.', not_owner = 'You do not own that vehicle.', not_out = 'That vehicle is not out of the garage.',
    insufficient_funds = 'You cannot afford that.', not_impounded = 'That vehicle is not impounded.', rate_limited = 'Slow down a little.', cannot_store_here = 'You cannot park here.',
}
local function errText(e) return ERR[e] or 'That did not work.' end

local function spawnPointIndex(def)
    for i, p in ipairs(def.spawns) do
        if not IsAnyVehicleNearPoint(p.x, p.y, p.z, 3.0) then return i end
    end
    return nil
end

local function retrieve(id, v)
    local def = cfg.Garages[id]
    local index = spawnPointIndex(def)
    if not index then return notify('All bays are occupied. Try again in a moment.', 'warning') end
    local ok, data = NexoroCore.Callback('nexoro_garages:retrieve', { garage = id, plate = v.plate, spawnIndex = index })
    if not ok then return notify(errText(data), 'error') end
    exports.nexoro_vehicles:SpawnOwnedVehicle(data.vehicle, data.spawn, function(spawned)
        if not spawned then notify('The vehicle could not be spawned. It has returned to the garage.', 'error') end
    end)
end

local function openList(id)
    if menuBusy then return end
    menuBusy = true
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_garages:list', { garage = id })
        menuBusy = false
        if not ok then return notify(errText(data), 'error') end
        local options = {}
        for _, v in ipairs(data.vehicles) do
            local label = ('%s  [%s]'):format(v.model:upper(), v.plate)
            if v.status == 'out' then
                options[#options + 1] = { title = label, description = 'Currently out of the garage', icon = '•', disabled = true }
            elseif v.status == 'impounded' then
                options[#options + 1] = { title = label, description = ('Impounded: %s. Release fee %s'):format(v.impoundReason or '', v.impoundFee or ''), icon = '⚠', onSelect = function()
                    CreateThread(function()
                        local choice = NexoroUI.Input({ title = 'Release ' .. v.plate, submitLabel = 'Pay and release', fields = { { type = 'select', name = 'account', label = 'Pay with', options = { 'bank', 'cash' }, default = 'bank' } } })
                        if not choice then return end
                        local done, err = NexoroCore.Callback('nexoro_garages:release', { garage = id, plate = v.plate, account = choice.account })
                        if not done then return notify(errText(err), 'error') end
                        notify('Vehicle released. You can now retrieve it.', 'success')
                    end)
                end }
            else
                options[#options + 1] = { title = label, icon = '▶', description = ('Select to take it out. Fuel %d%% · Engine %d%% · Body %d%% · %.1f miles'):format(v.fuel, v.engine, v.body, v.miles),
                    onSelect = function() CreateThread(function() retrieve(id, v) end) end }
            end
        end
        if #options == 0 then options[1] = { title = 'No vehicles here', disabled = true } end
        NexoroUI.RegisterContext({ id = 'nexoro_garage_' .. id, title = data.garage.label, options = options })
        NexoroUI.ShowContext('nexoro_garage_' .. id)
    end)
end

local function store(id)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return notify('Drive the vehicle into the garage first.', 'warning') end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local state = exports.nexoro_vehicles:GetVehicleState(veh)
    CreateThread(function()
        local ok, err = NexoroCore.Callback('nexoro_garages:store', { garage = id, plate = plate, state = state })
        if not ok then return notify(errText(err), 'error') end
        TaskLeaveVehicle(ped, veh, 0)
        Wait(800)
        exports.nexoro_vehicles:ForgetVehicle(plate)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        notify('Vehicle stored.', 'success')
    end)
end

-- Blips
CreateThread(function()
    for id, def in pairs(cfg.Garages) do
        local blip = AddBlipForCoord(def.x, def.y, def.z)
        SetBlipSprite(blip, def.type == 'impound' and 68 or 357)
        SetBlipColour(blip, def.type == 'impound' and 1 or 38)
        SetBlipScale(blip, 0.7); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(def.label); EndTextCommandSetBlipName(blip)
    end
end)

-- Proximity prompt
CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local pos = GetEntityCoords(PlayerPedId())
            local found = nil
            for id, def in pairs(cfg.Garages) do
                if #(pos - vector3(def.x, def.y, def.z)) < def.radius then found = id; break end
            end
            if found ~= inside then
                inside = found
                if found then
                    local def = cfg.Garages[found]
                    local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
                    exports.nexoro_ui:ShowTextUI(def.type == 'impound' and def.label .. ': open' or (inVeh and 'Park vehicle' or def.label .. ': open'), 'E')
                else
                    exports.nexoro_ui:HideTextUI()
                end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then
                    local def = cfg.Garages[inside]
                    if def.type == 'public' and IsPedInAnyVehicle(PlayerPedId(), false) then store(inside) else openList(inside) end
                end
            end
        end
        Wait(wait)
    end
end)
