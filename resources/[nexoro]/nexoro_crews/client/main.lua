local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function act(name, payload, text)
    CreateThread(function()
        local ok, r = NexoroCore.Callback(name, payload)
        if ok then notify(text and text(r) or 'Done.', 'success') else notify('Crew: ' .. tostring(r), 'error') end
    end)
end

-- /crew create <name> · /crew invite <id> · /crew accept · /crew leave · /crew kick <characterId> · /crew disband · /crew
RegisterCommand('crew', function(_, args)
    local sub = args[1]
    if sub == 'create' then
        local name = table.concat(args, ' ', 2)
        act('nexoro_crews:create', { name = name }, function(r) return ('Crew %s created.'):format(r.name) end)
    elseif sub == 'invite' and tonumber(args[2]) then
        act('nexoro_crews:invite', { target = tonumber(args[2]) }, function() return 'Invite sent.' end)
    elseif sub == 'accept' then
        act('nexoro_crews:accept', {}, function(r) return ('You joined %s.'):format(r.crew) end)
    elseif sub == 'leave' then
        act('nexoro_crews:leave', {}, function() return 'You left the crew.' end)
    elseif sub == 'kick' and tonumber(args[2]) then
        act('nexoro_crews:kick', { characterId = tonumber(args[2]) }, function() return 'Member removed.' end)
    elseif sub == 'disband' then
        act('nexoro_crews:disband', {}, function() return 'Crew disbanded.' end)
    else
        CreateThread(function()
            local ok, r = NexoroCore.Callback('nexoro_crews:mine')
            if not ok then return notify('Could not load your crew.', 'error') end
            if not r.crew then return notify('You are not in a crew. /crew create <name> to start one.', 'info') end
            local names = {}
            for _, m in ipairs(r.crew.members) do names[#names + 1] = m.name end
            notify(('%s: %s'):format(r.crew.name, table.concat(names, ', ')), 'info')
        end)
    end
end, false)
