local cfg = Config.Transport
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function tap(route, index, stop)
    CreateThread(function()
        local ok, status = NexoroCore.Callback('nexoro_transport:status')
        if ok and status.boarded then
            local okA, r = NexoroCore.Callback('nexoro_transport:alight', { route = route.id, stop = index })
            if okA then notify(('Off at %s. Fare %s.'):format(r.stop, r.fare), 'banking')
            else notify('Tap off: ' .. tostring(r), 'error') end
        else
            local okB, r = NexoroCore.Callback('nexoro_transport:board', { route = route.id, stop = index })
            if okB then notify('On at ' .. r.stop .. '. Tap off at your stop.', 'success')
            else notify('Tap on: ' .. tostring(r), 'error') end
        end
    end)
end

CreateThread(function()
    for _, r in ipairs(cfg.Routes) do
        for _, s in ipairs(r.stops) do
            local blip = AddBlipForCoord(s.x, s.y, s.z)
            SetBlipSprite(blip, 513); SetBlipColour(blip, 3); SetBlipScale(blip, 0.6); SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Bus stop: ' .. s.label); EndTextCommandSetBlipName(blip)
        end
    end
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, r in ipairs(cfg.Routes) do
                for i, s in ipairs(r.stops) do
                    if #(pos - vector3(s.x, s.y, s.z)) < cfg.StopRadius then found = { route = r, index = i, stop = s }; break end
                end
                if found then break end
            end
            local key = found and (found.route.id .. found.index) or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.stop.label .. ': tap card', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then local f = found; CreateThread(function() tap(f.route, f.index, f.stop) end) end
            end
        end
        Wait(wait)
    end
end)
