local cfg = Config.Scrapping
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

CreateThread(function()
    for _, p in ipairs(cfg.Points) do
        local blip = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(blip, 365); SetBlipColour(blip, 47); SetBlipScale(blip, 0.7); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Scrap: ' .. p.label); EndTextCommandSetBlipName(blip)
    end
end)

-- /scrap duty to start or finish a shift
RegisterCommand('scrap', function(_, args)
    if args[1] == 'duty' then
        CreateThread(function()
            local ok, r = NexoroCore.Callback('nexoro_scrapping:duty')
            notify(ok and (r.onDuty and 'Shift started.' or 'Shift finished.') or ('Scrap: ' .. tostring(r)), ok and 'success' or 'error')
        end)
    end
end, false)

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for _, p in ipairs(cfg.Points) do
                if #(pos - vector3(p.x, p.y, p.z)) < cfg.CollectRadius then found = p; break end
            end
            local key = found and found.id or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.label .. ': collect scrap', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then
                    local id = found.id
                    CreateThread(function()
                        if not NexoroUI.Progress({ label = 'Collecting scrap', duration = 5000, disable = { move = true, car = true, combat = true } }) then return end
                        local ok, r, extra = NexoroCore.Callback('nexoro_scrapping:collect', { point = id })
                        if ok then notify(('Collected %d scrap.'):format(r.amount), 'success')
                        elseif r == 'cooldown' then notify(('This point is resting (%d min).'):format(math.ceil((extra or 0) / 60)), 'warning')
                        else notify('Scrap: ' .. tostring(r), 'error') end
                    end)
                end
            end
        end
        Wait(wait)
    end
end)
