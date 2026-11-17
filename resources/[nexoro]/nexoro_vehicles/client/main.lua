local cfg = Config.Vehicles
local tracked = {}          -- [plate] = { mileage = metres, lastReport = ms, wreckedSent = bool, bursts = {wheel index} }
local bodyLast = {}         -- [plate] = last body health, to detect hard impacts
local PUNCTURE_WHEELS = { 0, 1, 4, 5 }
local menuBusy = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local ERR = {
    not_owner = 'You do not own that vehicle.', no_access = 'You do not have a key for that vehicle.', not_out = 'That vehicle is not out of the garage.',
    insufficient_funds = 'You cannot afford that.', not_at_pump = 'You must be at a fuel pump.', not_at_station = 'You must be at an MOT station.',
    tank_full = 'The tank is already full.', invalid_plan = 'Choose an insurance plan.', not_insured = 'That vehicle is not insured.', not_wrecked = 'That vehicle is not wrecked.',
    key_limit = 'This vehicle already has the maximum number of shared keys.', target_not_found = 'That player was not found.', too_far = 'You must be standing next to the buyer.',
    not_stored = 'The vehicle must be in a garage to sell it.', finance_outstanding = 'Pay off the finance first.', invalid_price = 'Enter a valid price.',
    offer_expired = 'That offer has expired.', rate_limited = 'Slow down a little.', invalid_amount = 'Enter a valid amount.', vehicle_not_wrecked = 'The vehicle is not wrecked.',
}
local function errText(e) return ERR[e] or 'That did not work.' end

local function plateOf(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function nearestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local c = GetEntityCoords(ped)
    veh = GetClosestVehicle(c.x, c.y, c.z, 6.0, 0, 71)
    return veh ~= 0 and veh or nil
end

---------------------------------------------------------------------------
-- Properties (colours and mods)
---------------------------------------------------------------------------

local function getProps(veh)
    local t = tracked[plateOf(veh)]
    local p, s = GetVehicleColours(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    local props = { colours = { p, s }, pearl = pearl, wheelColour = wheel, wheelType = GetVehicleWheelType(veh), tint = GetVehicleWindowTint(veh), livery = GetVehicleLivery(veh), mods = {}, dirt = GetVehicleDirtLevel(veh), tyres = (t and t.bursts) or {} }
    for i = 0, 48 do props.mods[tostring(i)] = GetVehicleMod(veh, i) end
    return props
end

local function setProps(veh, props)
    if type(props) ~= 'table' then return end
    SetVehicleModKit(veh, 0)
    if props.wheelType then SetVehicleWheelType(veh, props.wheelType) end
    if props.dirt then SetVehicleDirtLevel(veh, props.dirt + 0.0) end
    for _, wheel in ipairs(props.tyres or {}) do SetVehicleTyreBurst(veh, wheel, false, 1000.0) end
    if props.colours then SetVehicleColours(veh, props.colours[1] or 0, props.colours[2] or 0) end
    if props.pearl then SetVehicleExtraColours(veh, props.pearl, props.wheelColour or 0) end
    if props.tint then SetVehicleWindowTint(veh, props.tint) end
    if props.livery and props.livery >= 0 then SetVehicleLivery(veh, props.livery) end
    for k, v in pairs(props.mods or {}) do
        local i = tonumber(k)
        if i and v and v >= 0 and v < GetNumVehicleMods(veh, i) then SetVehicleMod(veh, i, v, false) end
    end
end

---------------------------------------------------------------------------
-- Exports used by garages and dealerships
---------------------------------------------------------------------------

exports('SpawnOwnedVehicle', function(data, pos, cb)
    CreateThread(function()
        local hash = GetHashKey(data.model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return cb(false) end
        RequestModel(hash)
        local deadline = GetGameTimer() + 8000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
        if not HasModelLoaded(hash) then return cb(false) end
        local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, pos.h + 0.0, true, false)
        SetVehicleOnGroundProperly(veh)
        SetVehicleNumberPlateText(veh, data.plate)
        SetVehicleFuelLevel(veh, data.fuel + 0.0)
        SetVehicleEngineHealth(veh, data.engine + 0.0)
        SetVehicleBodyHealth(veh, data.body + 0.0)
        local ok, props = pcall(json.decode, data.props or '{}')
        if ok then setProps(veh, props) end
        SetVehicleDoorsLocked(veh, 1)
        SetModelAsNoLongerNeeded(hash)
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdExistsOnAllMachines(netId, true)
        TriggerServerEvent('nexoro_vehicles:spawned', data.plate, netId)
        local bursts = {}
        if ok and type(props) == 'table' and type(props.tyres) == 'table' then bursts = props.tyres end
        tracked[data.plate] = { mileage = data.mileage, lastReport = GetGameTimer(), bursts = bursts }
        cb(true)
    end)
end)

exports('GetVehicleState', function(veh)
    local plate = plateOf(veh)
    local t = tracked[plate]
    return { fuel = GetVehicleFuelLevel(veh), engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh), mileage = t and math.floor(t.mileage) or nil, props = getProps(veh) }
end)
exports('ForgetVehicle', function(plate) tracked[plate] = nil end)

---------------------------------------------------------------------------
-- Locks
---------------------------------------------------------------------------

local function toggleLock()
    local veh = nearestVehicle()
    if not veh then return end
    CreateThread(function()
        local ok, has = NexoroCore.Callback('nexoro_vehicles:access', { plate = plateOf(veh) })
        if not ok or not has then return notify('You do not have a key for this vehicle.', 'warning') end
        local locked = GetVehicleDoorLockStatus(veh) >= 2
        SetVehicleDoorsLocked(veh, locked and 1 or 2)
        PlaySoundFrontend(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', 'PI_Menu_Sounds', true)
        SetVehicleLights(veh, 2); Wait(150); SetVehicleLights(veh, 0); Wait(150); SetVehicleLights(veh, 2); Wait(150); SetVehicleLights(veh, 0)
        notify(locked and 'Vehicle unlocked.' or 'Vehicle locked.', 'info')
    end)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('vehicle_lock', 'Lock or unlock vehicle', cfg.LockKey, toggleLock)
end)

---------------------------------------------------------------------------
-- Fuel use, mileage, state reports
---------------------------------------------------------------------------

CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local dt = (now - last) / 1000.0
        last = now
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            if GetIsVehicleEngineRunning(veh) then
                local rpm = GetVehicleCurrentRpm(veh)
                local fuel = GetVehicleFuelLevel(veh) - (cfg.FuelConsumption.idle + rpm * rpm * cfg.FuelConsumption.load) * dt
                if fuel <= 0.0 then
                    fuel = 0.0
                    SetVehicleEngineOn(veh, false, true, true)
                    notify('You have run out of fuel.', 'warning')
                end
                SetVehicleFuelLevel(veh, fuel)
            elseif GetVehicleFuelLevel(veh) <= 0.0 then
                SetVehicleEngineOn(veh, false, true, true)
            end
            local plate = plateOf(veh)
            -- Dirt builds up while driving; hard impacts can puncture a tyre.
            SetVehicleDirtLevel(veh, math.min(15.0, GetVehicleDirtLevel(veh) + GetEntitySpeed(veh) * dt * cfg.DirtRate))
            local body = GetVehicleBodyHealth(veh)
            local lastBody = bodyLast[plate] or body
            if lastBody - body > cfg.PunctureImpact and math.random() < cfg.PunctureChance then
                local wheel = PUNCTURE_WHEELS[math.random(1, #PUNCTURE_WHEELS)]
                SetVehicleTyreBurst(veh, wheel, false, 1000.0)
                local t0 = tracked[plate]
                if t0 then
                    t0.bursts = t0.bursts or {}
                    local known = false
                    for _, w in ipairs(t0.bursts) do if w == wheel then known = true end end
                    if not known then t0.bursts[#t0.bursts + 1] = wheel end
                end
                notify('You have a puncture.', 'warning')
            end
            bodyLast[plate] = body
            local t = tracked[plate]
            if t then
                t.mileage = t.mileage + GetEntitySpeed(veh) * dt
                if now - t.lastReport > cfg.StateReportSeconds * 1000 then
                    t.lastReport = now
                    CreateThread(function()
                        local state = exports.nexoro_vehicles:GetVehicleState(veh)
                        NexoroCore.Callback('nexoro_vehicles:state', { plate = plate, state = state })
                    end)
                end
                if not t.wreckedSent and (GetVehicleEngineHealth(veh) <= 0.0 or IsEntityDead(veh)) then
                    t.wreckedSent = true
                    CreateThread(function() NexoroCore.Callback('nexoro_vehicles:wrecked', { plate = plate }) end)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Fuel pumps and MOT stations
---------------------------------------------------------------------------

local function washCar()
    local veh = nearestVehicle()
    if not veh then return notify('Drive your vehicle into the wash.', 'warning') end
    local plate = plateOf(veh)
    if not NexoroUI.Progress({ label = 'Washing vehicle', duration = 6000, disable = { move = true, car = true, combat = true } }) then return end
    local ok, r = NexoroCore.Callback('nexoro_vehicles:wash', { plate = plate })
    if not ok then return notify(errText(r), 'error') end
    SetVehicleDirtLevel(veh, 0.0)
    notify(('Washed for %s.'):format(r.cost), 'banking')
end

local function nearPoint(list, radius)
    local pos = GetEntityCoords(PlayerPedId())
    for _, p in ipairs(list) do
        if #(pos - vector3(p.x, p.y, p.z)) < radius then return true end
    end
    return false
end

local function refuel()
    local veh = nearestVehicle()
    if not veh then return notify('Park next to the pump.', 'warning') end
    local plate = plateOf(veh)
    local fuel = GetVehicleFuelLevel(veh)
    local room = (100 - fuel) / 100 * cfg.FuelTankLitres
    if room < 0.2 then return notify('The tank is already full.', 'info') end
    local values = NexoroUI.Input({ title = ('Fuel pump - £%.2f per litre'):format(cfg.FuelPricePerLitre), submitLabel = 'Fill up', fields = {
        { type = 'number', name = 'litres', label = ('Litres (up to %.1f)'):format(room), default = math.floor(room * 10) / 10, min = 1, max = room, step = 0.1, required = true },
        { type = 'select', name = 'account', label = 'Pay with', options = { 'bank', 'cash' }, default = 'bank' },
    } })
    if not values then return end
    local litres = math.min(values.litres, room)
    if not NexoroUI.Progress({ label = 'Refuelling', duration = math.max(2500, math.floor(litres * 250)), disable = { move = true, car = true, combat = true } }) then return end
    local ok, result = NexoroCore.Callback('nexoro_vehicles:refuel', { plate = plate, litres = litres, account = values.account })
    if not ok then return notify(errText(result), 'error') end
    SetVehicleFuelLevel(veh, result.fuel + 0.0)
    notify(('Filled %.1f litres for %s.'):format(result.litres, result.cost), 'banking')
end

local function motTest()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return notify('Drive your vehicle into the MOT bay.', 'warning') end
    local plate = plateOf(veh)
    if not NexoroUI.Confirm({ title = 'MOT test', text = ('Test costs £%.2f. The result depends on engine and bodywork condition.'):format(cfg.MotFeePounds), confirmLabel = 'Start test' }) then return end
    if not NexoroUI.Progress({ label = 'MOT test in progress', duration = 8000, canCancel = false, disable = { move = true, car = true, combat = true } }) then return end
    local ok, result = NexoroCore.Callback('nexoro_vehicles:mot', { plate = plate, account = 'bank' })
    if not ok then return notify(errText(result), 'error') end
    if result.passed then
        -- The test includes tyres: any punctures are repaired.
        local vehNow = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehNow ~= 0 then
            for _, wheel in ipairs(PUNCTURE_WHEELS) do SetVehicleTyreFixed(vehNow, wheel) end
        end
        if tracked[plate] then tracked[plate].bursts = {} end
        NexoroUI.Alert({ title = 'MOT pass', text = ('%s passed.\nValid until %s.\nFee: %s'):format(plate, result.expires, result.fee) })
    else
        NexoroUI.Alert({ title = 'MOT fail', text = ('%s failed.\nReasons: %s\nFee: %s'):format(plate, table.concat(result.failures, ', '), result.fee) })
    end
end

CreateThread(function()
    local prompt = nil
    while true do
        local wait = 1000
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded then
            local want = nil
            if nearPoint(cfg.Pumps, cfg.PumpRadius - 2.0) then want = 'pump' elseif nearPoint(cfg.MotStations, cfg.MotRadius - 4.0) then want = 'mot' elseif nearPoint(cfg.CarWashes, cfg.CarWashRadius - 2.0) then want = 'wash' end
            if want ~= prompt then
                prompt = want
                if want then exports.nexoro_ui:ShowTextUI(want == 'pump' and 'Refuel vehicle' or (want == 'wash' and 'Wash vehicle' or 'MOT test'), 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if prompt then
                wait = 0
                if IsControlJustPressed(0, 38) then
                    local which = prompt
                    CreateThread(function() if which == 'pump' then refuel() elseif which == 'wash' then washCar() else motTest() end end)
                end
            end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    for _, p in ipairs(cfg.Pumps) do
        local blip = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(blip, 361); SetBlipColour(blip, 1); SetBlipScale(blip, 0.6); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Petrol station'); EndTextCommandSetBlipName(blip)
    end
    for _, p in ipairs(cfg.MotStations) do
        local blip = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(blip, 446); SetBlipColour(blip, 5); SetBlipScale(blip, 0.7); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('MOT station'); EndTextCommandSetBlipName(blip)
    end
end)

---------------------------------------------------------------------------
-- My vehicles menu
---------------------------------------------------------------------------

local function call(name, payload)
    local ok, result = NexoroCore.Callback('nexoro_vehicles:' .. name, payload)
    if not ok then notify(errText(result), 'error') end
    return ok, result
end

local function vehicleMenu(v)
    local id = 'nexoro_veh_' .. v.plate
    local options = {
        { title = 'Details', icon = 'ℹ', description = ('%s · %s · %.1f miles'):format(v.status, v.garage ~= '' and v.garage or 'no garage', v.miles), onSelect = function()
            CreateThread(function()
                NexoroUI.Alert({ title = v.model:upper() .. ' ' .. v.plate, text = table.concat({
                    'Status: ' .. v.status, 'Fuel: ' .. v.fuel .. '%', 'Engine: ' .. v.engine .. '%', 'Bodywork: ' .. v.body .. '%', ('Mileage: %.1f miles'):format(v.miles),
                    'Insurance: ' .. (v.insured and ('valid until ' .. v.insuranceExpires) or 'none'), 'MOT: ' .. (v.motValid and ('valid until ' .. v.motExpires) or 'none'),
                    'Value: ' .. v.value, v.financeRemaining and ('Finance left: ' .. v.financeRemaining .. ', payment ' .. v.financePayment .. ' due ' .. (v.financeDue or '?')) or 'Owned outright',
                }, '\n') })
            end)
        end },
    }
    if v.mine then
        options[#options + 1] = { title = 'Buy insurance', icon = '£', description = 'Covers the vehicle after a crash. Claim it from this menu once the vehicle is wrecked.', onSelect = function()
            CreateThread(function()
                local values = NexoroUI.Input({ title = 'Insure ' .. v.plate, submitLabel = 'Buy', fields = {
                    { type = 'select', name = 'days', label = 'Plan', options = { { value = 7, label = '7 days' }, { value = 14, label = '14 days' }, { value = 30, label = '30 days' } }, required = true },
                    { type = 'select', name = 'account', label = 'Pay with', options = { 'bank', 'cash' }, default = 'bank' } } })
                if not values then return end
                local ok, r = call('insurance:buy', { plate = v.plate, days = tonumber(values.days), account = values.account })
                if ok then notify(('Insured until %s (%s).'):format(r.expires, r.cost), 'success') end
            end)
        end }
        options[#options + 1] = { title = 'Share a key', icon = '⚿', description = 'Lets another player lock, unlock and drive it. You can revoke keys later.', onSelect = function()
            CreateThread(function()
                local values = NexoroUI.Input({ title = 'Share a key', submitLabel = 'Give key', fields = { { type = 'number', name = 'target', label = 'Player server ID', required = true, min = 1 } } })
                if values and call('keys:give', { plate = v.plate, target = values.target }) then notify('Key shared.', 'success') end
            end)
        end }
        options[#options + 1] = { title = 'Sell to a player', icon = '⇄', description = 'Sends an offer to a player standing next to you. Ownership moves only if they accept and pay.', disabled = v.status ~= 'stored', description = v.status ~= 'stored' and 'Vehicle must be in a garage' or nil, onSelect = function()
            CreateThread(function()
                local values = NexoroUI.Input({ title = 'Sell ' .. v.plate, submitLabel = 'Send offer', fields = {
                    { type = 'number', name = 'target', label = 'Buyer server ID (must be next to you)', required = true, min = 1 },
                    { type = 'number', name = 'price', label = 'Price (£)', required = true, min = 0, step = 0.01 } } })
                if values and call('transfer:offer', { plate = v.plate, target = values.target, price = values.price }) then notify('Offer sent.', 'info') end
            end)
        end }
        if v.financeRemaining then
            options[#options + 1] = { title = 'Pay finance', icon = '£', description = 'Remaining ' .. v.financeRemaining, onSelect = function()
                CreateThread(function()
                    local values = NexoroUI.Input({ title = 'Pay finance', submitLabel = 'Pay', fields = { { type = 'number', name = 'amount', label = 'Amount (£)', required = true, min = 1, step = 0.01 } } })
                    if not values then return end
                    local ok, r = call('finance:pay', { plate = v.plate, amount = values.amount })
                    if ok then notify('Payment made. Remaining: ' .. r.remaining, 'banking') end
                end)
            end }
        end
        if v.status == 'wrecked' then
            options[#options + 1] = { title = 'Make an insurance claim', icon = '✚', description = 'Claims the insurance excess is paid and the vehicle is returned to your default garage in poor condition.', onSelect = function()
                CreateThread(function()
                    local ok, r = call('insurance:claim', { plate = v.plate, account = 'bank' })
                    if ok then notify(('Claim approved. Excess %s. Collect it from %s.'):format(r.excess, r.garage), 'success') end
                end)
            end }
            options[#options + 1] = { title = 'Scrap vehicle', icon = '✖', description = 'Permanently removes a wrecked vehicle you no longer want. Cannot be undone.', onSelect = function()
                CreateThread(function() if NexoroUI.Confirm({ title = 'Scrap ' .. v.plate .. '?', text = 'This cannot be undone.', danger = true }) and call('scrap', { plate = v.plate }) then notify('Vehicle scrapped.', 'info') end end)
            end }
        end
    end
    options[#options + 1] = { title = 'History', icon = '≡', description = 'A list of everything that has happened to this vehicle.', onSelect = function()
        CreateThread(function()
            local ok, rows = call('history', { plate = v.plate })
            if not ok then return end
            local lines = {}
            for _, r in ipairs(rows) do lines[#lines + 1] = ('%s  %s  %s'):format(r.date, r.event, r.detail) end
            NexoroUI.Alert({ title = 'History: ' .. v.plate, text = #lines > 0 and table.concat(lines, '\n') or 'No history.' })
        end)
    end }
    NexoroUI.RegisterContext({ id = id, title = v.model:upper() .. '  ' .. v.plate, menu = 'nexoro_my_vehicles', options = options })
    return id
end

local function openMyVehicles()
    if menuBusy then return end
    menuBusy = true
    CreateThread(function()
        local ok, list = NexoroCore.Callback('nexoro_vehicles:list')
        menuBusy = false
        if not ok then return notify(errText(list), 'error') end
        local options = {}
        for _, v in ipairs(list) do
            options[#options + 1] = { title = ('%s  [%s]'):format(v.model:upper(), v.plate), description = ('%s%s · Fuel %d%%%s%s'):format(v.status, v.mine and '' or ' (shared key)', v.fuel, v.insured and '' or ' · Uninsured', v.motValid and '' or ' · No MOT'), menu = vehicleMenu(v) }
        end
        if #options == 0 then options[1] = { title = 'You have no vehicles', disabled = true } end
        NexoroUI.RegisterContext({ id = 'nexoro_my_vehicles', title = 'My vehicles', options = options })
        NexoroUI.ShowContext('nexoro_my_vehicles')
    end)
end
RegisterCommand('vehicles', openMyVehicles, false)
exports('OpenMyVehicles', openMyVehicles)

RegisterNetEvent('nexoro_vehicles:offer', function(offer)
    CreateThread(function()
        local accepted = NexoroUI.Confirm({ title = 'Vehicle offer', text = ('%s offers you a %s (%s, %.1f miles) for %s.'):format(offer.seller, offer.model:upper(), offer.plate, offer.miles, offer.price), confirmLabel = 'Buy' })
        local ok, result = NexoroCore.Callback('nexoro_vehicles:transfer:respond', { id = offer.id, accept = accepted == true })
        if not ok then return notify(errText(result), 'error') end
        if accepted then notify(('You bought %s. Collect it from the garage it is stored in.'):format(result.plate), 'success') end
    end)
end)
