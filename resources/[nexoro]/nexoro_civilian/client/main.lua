local cfg = Config.Civilian
local inside = nil

local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

local function jobCentreMenu()
    CreateThread(function()
        local options = {}
        for id, def in pairs(cfg.Jobs) do
            options[#options + 1] = { title = def.label, description = ('£%.2f an hour and £%.2f a task.'):format(def.salary, def.pay), icon = '+',
                onSelect = function()
                    CreateThread(function()
                        local ok, r = NexoroCore.Callback('nexoro_civilian:hire', { job = id })
                        if ok then notify('You started work as a ' .. r.job .. '. Go on duty with /work duty.', 'success')
                        else notify('Could not take the job: ' .. tostring(r), 'error') end
                    end)
                end }
        end
        options[#options + 1] = { title = 'Leave my job', description = 'Go back to being unemployed.', icon = '-',
            onSelect = function()
                CreateThread(function()
                    local ok, r = NexoroCore.Callback('nexoro_civilian:quit')
                    if ok then notify('You left your job.', 'info') else notify('Could not leave: ' .. tostring(r), 'error') end
                end)
            end }
        NexoroUI.RegisterContext({ id = 'nexoro_job_centre', title = cfg.JobCentre.label, options = options })
        NexoroUI.ShowContext('nexoro_job_centre')
    end)
end

RegisterCommand('work', function(_, args)
    CreateThread(function()
        if args[1] == 'duty' then
            local ok, r = NexoroCore.Callback('nexoro_civilian:duty')
            notify(ok and (r.onDuty and 'You are on duty.' or 'You are off duty.') or ('Work: ' .. tostring(r)), ok and 'success' or 'error')
        end
    end)
end, false)

CreateThread(function()
    while true do
        local wait = 800
        local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
        if okLoaded and loaded and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local pos = GetEntityCoords(PlayerPedId())
            local jc = cfg.JobCentre
            local near = #(pos - vector3(jc.x, jc.y, jc.z)) < jc.radius
            if near ~= (inside == 'centre') then
                inside = near and 'centre' or nil
                if near then exports.nexoro_ui:ShowTextUI('Job Centre: E', 'E') else exports.nexoro_ui:HideTextUI() end
            end
            if near then
                wait = 0
                if IsControlJustPressed(0, 38) then CreateThread(jobCentreMenu) end
            end
        end
        Wait(wait)
    end
end)
