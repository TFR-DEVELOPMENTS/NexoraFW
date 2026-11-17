local cfg = Config.Scratch
local inside = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function play()
    CreateThread(function()
        local ok, r = NexoroCore.Callback('nexoro_scratch:buy')
        if not ok then return notify('Card not bought: ' .. tostring(r), 'error') end
        if r.prize > 0 then notify(('You won %s!'):format(r.won), 'success')
        else notify('No luck this time.', 'info') end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local o = cfg.Counter
            local near = #(GetEntityCoords(PlayerPedId()) - vector3(o.x, o.y, o.z)) < o.radius
            if near ~= inside then
                inside = near
                if near then exports.nexoro_ui:ShowTextUI(o.label .. ': scratchcard', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then CreateThread(play) end
            end
        end
        Wait(wait)
    end
end)
