local cfg = Config.Lottery
local inside = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function buy()
    CreateThread(function()
        local v = NexoroUI.Input({ title = ('Lottery ticket, £%.2f'):format(cfg.TicketPricePounds), submitLabel = 'Buy', fields = {
            { type = 'input', name = 'numbers', label = ('Pick %d different numbers from 1 to %d, separated by commas'):format(cfg.NumbersPerTicket, cfg.PoolSize), required = true } } })
        if not v then return end
        local nums = {}
        for n in tostring(v.numbers):gmatch('%d+') do nums[#nums + 1] = tonumber(n) end
        local ok, r = NexoroCore.Callback('nexoro_lottery:buy', { numbers = nums })
        if ok then notify(('Ticket bought: %s.'):format(r.numbers), 'success')
        else notify('Ticket not bought: ' .. tostring(r), 'error') end
    end)
end

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local o = cfg.Office
            local near = #(GetEntityCoords(PlayerPedId()) - vector3(o.x, o.y, o.z)) < o.radius
            if near ~= inside then
                inside = near
                if near then exports.nexoro_ui:ShowTextUI(o.label .. ': buy a ticket', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if inside then
                wait = 0
                if IsControlJustPressed(0, 38) then CreateThread(buy) end
            end
        end
        Wait(wait)
    end
end)
