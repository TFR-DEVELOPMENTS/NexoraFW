local cfg = Config.Housing
local inside = nil
local interior = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end
local ERR = { too_far = 'Move closer.', no_access = 'You do not have a key.', already_owned = 'That property has already been sold.',
    insufficient_funds = 'You cannot afford that.', arrears_outstanding = 'Pay your arrears before selling.', not_owner = 'Only the owner can do that.',
    key_limit = 'Too many keys are out already.', target_not_found = 'That player is not online.', no_arrears = 'You have no arrears.' }

local function call(name, payload, okText)
    CreateThread(function()
        local ok, r = NexoroCore.Callback(name, payload)
        if ok then if okText then notify(okText .. (type(r) == 'table' and r.received and (' ' .. r.received) or ''), 'success') end
        else notify(ERR[r] or 'That did not work.', 'error') end
    end)
end

local function openAgent(agentId)
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_housing:list', { agent = agentId })
        if not ok then return notify(ERR[data] or 'The agent is closed.', 'error') end
        local options = {}
        for _, p in ipairs(data.properties) do
            local desc = ('%s · %s a week · %s'):format(p.price, p.weekly, p.status)
            options[#options + 1] = { title = p.label, description = desc, icon = '⌂', disabled = p.status ~= 'for sale' and p.status ~= 'yours',
                onSelect = function()
                    if p.status == 'for sale' then
                        NexoroUI.RegisterContext({ id = 'nexoro_buy_' .. p.id, title = p.label, menu = 'nexoro_agent_' .. agentId, options = {
                            { title = 'Buy', description = 'Pay ' .. p.price .. ' from your bank. Bills are ' .. p.weekly .. ' a week.', icon = '£',
                              onSelect = function() call('nexoro_housing:buy', { id = p.id }, 'Property bought for') end } } })
                        NexoroUI.ShowContext('nexoro_buy_' .. p.id)
                    else
                        NexoroUI.RegisterContext({ id = 'nexoro_sell_' .. p.id, title = p.label, menu = 'nexoro_agent_' .. agentId, options = {
                            { title = 'Sell back', description = 'The agent pays back ' .. math.floor(cfg.SellBackRate * 100) .. '% of the price.', icon = '£',
                              onSelect = function() call('nexoro_housing:sell', { id = p.id }, 'Sold for') end },
                            { title = 'Pay arrears', description = 'Clears any missed weekly bills.', icon = '£',
                              onSelect = function() call('nexoro_housing:arrears', { id = p.id }, 'Arrears paid.') end } } })
                        NexoroUI.ShowContext('nexoro_sell_' .. p.id)
                    end
                end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_agent_' .. agentId, title = data.agent, options = options })
        NexoroUI.ShowContext('nexoro_agent_' .. agentId)
    end)
end

-- Enter, leave and key sharing at the door.
local function doorPrompt(propId)
    CreateThread(function()
        NexoroUI.RegisterContext({ id = 'nexoro_door_' .. propId, title = 'Property', options = {
            { title = 'Go in', description = 'Enter the property.', icon = '→', onSelect = function() call('nexoro_housing:enter', { id = propId }) end },
            { title = 'Stash', description = 'Open the storage in this property.', icon = '▣', onSelect = function()
                CreateThread(function()
                    local ok, s = NexoroCore.Callback('nexoro_housing:stash', { id = propId })
                    if not ok then return notify(ERR[s] or 'No access.', 'error') end
                    local lines = {}
                    for _, it in ipairs(s.items or {}) do lines[#lines + 1] = ('%s x%d'):format(it.label, it.amount) end
                    NexoroUI.Alert({ title = 'Storage', text = #lines > 0 and table.concat(lines, '\n') or 'Empty.' })
                end)
            end } } })
        NexoroUI.ShowContext('nexoro_door_' .. propId)
    end)
end

CreateThread(function()
    for _, a in pairs(cfg.Agents) do
        local blip = AddBlipForCoord(a.x, a.y, a.z)
        SetBlipSprite(blip, 40); SetBlipColour(blip, 5); SetBlipScale(blip, 0.6); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(a.label); EndTextCommandSetBlipName(blip)
    end
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local found
            for id, a in pairs(cfg.Agents) do
                if #(pos - vector3(a.x, a.y, a.z)) < a.radius then found = { kind = 'agent', id = id, label = a.label }; break end
            end
            if not found then
                for _, p in ipairs(cfg.Properties) do
                    local e = p.entrance
                    if #(pos - vector3(e.x, e.y, e.z)) < 3.0 then found = { kind = 'door', id = p.id, label = p.label }; break end
                end
            end
            local key = found and (found.kind .. found.id) or nil
            if key ~= inside then
                inside = key
                if found then exports.nexoro_ui:ShowTextUI(found.label .. ': E', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if found then
                wait = 0
                if IsControlJustPressed(0, 38) then
                    local f = found
                    if f.kind == 'agent' then openAgent(f.id) else doorPrompt(f.id) end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('nexoro_housing:enter', function(data)
    if type(data) ~= 'table' or type(data.interior) ~= 'table' then return end
    local i = data.interior
    SetEntityCoords(PlayerPedId(), i.x + 0.0, i.y + 0.0, i.z + 0.0, false, false, false, false)
    notify('You are inside. Walk back to the door to leave.', 'info')
end)

RegisterNetEvent('nexoro_housing:leave', function(data)
    if type(data) ~= 'table' or type(data.entrance) ~= 'table' then return end
    local e = data.entrance
    SetEntityCoords(PlayerPedId(), e.x + 0.0, e.y + 0.0, e.z + 0.0, false, false, false, false)
end)
