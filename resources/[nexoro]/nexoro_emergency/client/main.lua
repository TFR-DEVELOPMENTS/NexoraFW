local cfg = Config.Emergency
local CATEGORY = { police = true, ambulance = true, fire = true }
local wearing = false

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local ERR = {
    forbidden = 'You do not have permission for that.', not_emergency = 'You are not in an emergency service.',
    invalid_callsign = 'Enter a callsign number from 1 to 99.', callsign_taken = 'That callsign is already in use in your department.',
    target_not_found = 'That player is not online.', cannot_target_self = 'You cannot do that to yourself.',
    already_in_service = 'That person already serves in an emergency service.', not_in_department = 'That person is not in your department.',
    outranks_you = 'You cannot act on someone of equal or higher rank.', rank_too_high = 'You cannot give a rank at or above your own.',
    invalid_grade = 'That rank does not exist.', invalid_delta = 'Invalid rank change.',
}

-- Applies the department uniform when going on duty; restores civilian clothes when going off duty.
local function applyUniform(category)
    local u = cfg.Uniforms[category]
    if not u then return end
    local ped = PlayerPedId()
    for comp, v in pairs(u.components or {}) do SetPedComponentVariation(ped, comp, v[1], v[2], 2) end
    for prop, v in pairs(u.props or {}) do
        if v[1] < 0 then ClearPedProp(ped, prop) else SetPedPropIndex(ped, prop, v[1], v[2], true) end
    end
    wearing = true
end

local function restoreCivilian()
    local ok, app = NexoroCore.Callback('nexoro_character:getAppearance')
    if ok and app then exports.nexoro_character:ApplyAppearance(app) end
    wearing = false
end

AddEventHandler('nexoro:client:jobUpdatedLocal', function(job)
    if type(job) ~= 'table' then return end
    CreateThread(function()
        if job.onDuty and CATEGORY[job.category] then applyUniform(job.category)
        elseif wearing then restoreCivilian() end
    end)
end)

local function act(name, payload, okText)
    CreateThread(function()
        local ok, res = NexoroCore.Callback(name, payload)
        if ok then notify(okText or 'Done.', 'success')
        else notify(ERR[res] or 'That did not work.', 'error') end
    end)
end

local function askPlayer(title, onSubmit, extra)
    CreateThread(function()
        local fields = { { type = 'number', name = 'target', label = 'Player server ID', required = true, min = 1 } }
        for _, f in ipairs(extra or {}) do fields[#fields + 1] = f end
        local v = NexoroUI.Input({ title = title, fields = fields })
        if v then onSubmit(v) end
    end)
end

local function openManage()
    NexoroUI.RegisterContext({ id = 'nexoro_service_manage', title = 'Manage staff', menu = 'nexoro_service', options = {
        { title = 'Hire into department', icon = '+', description = 'Adds a player to your department at the lowest rank. Enter their server ID.', onSelect = function() askPlayer('Hire', function(v) act('nexoro_emergency:hire', { target = v.target }, 'Hired.') end) end },
        { title = 'Promote', icon = '▲', description = 'Moves a member of your department up one rank (never to your own rank or above).', onSelect = function() askPlayer('Promote', function(v) act('nexoro_emergency:promote', { target = v.target, delta = 1 }, 'Promoted.') end) end },
        { title = 'Demote', icon = '▼', description = 'Moves a member of your department down one rank.', onSelect = function() askPlayer('Demote', function(v) act('nexoro_emergency:promote', { target = v.target, delta = -1 }, 'Demoted.') end) end },
        { title = 'Dismiss', icon = '✖', description = 'Removes a member from your department. They become unemployed.', onSelect = function() askPlayer('Dismiss', function(v) act('nexoro_emergency:dismiss', { target = v.target }, 'Dismissed.') end) end },
    } })
end

local function openMenu()
    CreateThread(function()
        local ok, s = NexoroCore.Callback('nexoro_emergency:status')
        if not ok then return notify('You are not in an emergency service.', 'warning') end
        local options = {
            { title = s.onDuty and 'Go off duty' or 'Go on duty', icon = '●', description = s.onDuty and 'Ends your shift. Your operational powers and uniform stop.' or 'Starts your shift. Puts on your uniform and gives you your powers.', onSelect = function() act('nexoro_emergency:toggleDuty', {}, 'Duty status changed.') end },
            { title = 'Set callsign', description = s.callsign ~= '' and ('Current: ' .. s.callsign) or 'Not set', icon = '#', onSelect = function()
                CreateThread(function()
                    local v = NexoroUI.Input({ title = 'Callsign', fields = { { type = 'number', name = 'number', label = 'Number (1-99)', required = true, min = 1, max = cfg.CallsignMax } } })
                    if v then act('nexoro_emergency:setCallsign', { callsign = v.number }, 'Callsign set.') end
                end)
            end },
            { title = 'Roster', icon = '≡', description = 'Shows everyone online in your department, highest rank first, with callsign and duty status.', onSelect = function()
                CreateThread(function()
                    local okR, list = NexoroCore.Callback('nexoro_emergency:roster')
                    if not okR then return notify(ERR[list] or 'Roster unavailable.', 'error') end
                    local lines = {}
                    for _, m in ipairs(list) do
                        lines[#lines + 1] = ('%s  %s  %s  %s'):format(m.callsign ~= '' and m.callsign or '--', m.rank, m.name, m.onDuty and 'on duty' or 'off duty')
                    end
                    NexoroUI.Alert({ title = 'Roster', text = #lines > 0 and table.concat(lines, '\n') or 'No one online.' })
                end)
            end },
        }
        if s.permissions then
            for _, p in ipairs(s.permissions) do if p == 'emergency.manage' then options[#options + 1] = { title = 'Manage staff', icon = '✚', menu = 'nexoro_service_manage' }; break end end
        end
        NexoroUI.RegisterContext({ id = 'nexoro_service', title = ('%s · %s'):format(s.department, s.rank), options = options })
        openManage()
        NexoroUI.ShowContext('nexoro_service')
    end)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' or GetResourceState('nexoro_ui') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('service_menu', 'Open service menu', cfg.MenuKey, openMenu)
end)
RegisterCommand('service', openMenu, false)
