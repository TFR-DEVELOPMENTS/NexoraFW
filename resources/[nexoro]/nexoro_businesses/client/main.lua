local cfg = Config.Businesses
local function notify(text, kind) TriggerEvent('nexoro:notify', { message = text, type = kind or 'info' }) end

-- /business menu: register, see your businesses and staff, deposit and withdraw.
local function ask(title, fields, fn)
    CreateThread(function()
        local v = NexoroUI.Input({ title = title, fields = fields })
        if v then fn(v) end
    end)
end

local function act(name, payload, text)
    CreateThread(function()
        local ok, r = NexoroCore.Callback(name, payload)
        if ok then notify(text or 'Done.', 'success') else notify('Business: ' .. tostring(r), 'error') end
    end)
end

local function openMine(_, _)
    CreateThread(function()
        local ok, data = NexoroCore.Callback('nexoro_businesses:mine')
        if not ok then return notify('Could not load your businesses.', 'error') end
        local options = {
            { title = ('Register a business (£%.2f)'):format(cfg.RegistrationFeePounds), icon = '+', onSelect = function()
                ask('Register a business', { { type = 'input', name = 'name', label = 'Business name', required = true, maxLength = cfg.NameMax } },
                    function(v) act('nexoro_businesses:create', { name = v.name }, 'Business registered.') end)
            end },
        }
        for _, b in ipairs(data.owned) do
            local lines = {}
            for _, s in ipairs(b.staff) do lines[#lines + 1] = ('%s · %s an hour'):format(s.name, s.wage) end
            options[#options + 1] = { title = b.name, description = ('Account %s · %d staff'):format(b.balance, #b.staff), icon = '▤', onSelect = function()
                NexoroUI.RegisterContext({ id = 'nexoro_biz_' .. b.id, title = b.name, menu = 'nexoro_business_menu', options = {
                    { title = 'Deposit', description = 'Move money from your bank into the business account.', icon = '£', onSelect = function()
                        ask('Deposit', { { type = 'number', name = 'amount', label = 'Amount (£)', required = true, min = 0.01, step = 0.01 } },
                            function(v) act('nexoro_businesses:deposit', { id = b.id, amount = v.amount }, 'Deposited.') end) end },
                    { title = 'Withdraw', description = 'Move money from the business account to your bank.', icon = '£', onSelect = function()
                        ask('Withdraw', { { type = 'number', name = 'amount', label = 'Amount (£)', required = true, min = 0.01, step = 0.01 } },
                            function(v) act('nexoro_businesses:withdraw', { id = b.id, amount = v.amount }, 'Withdrawn.') end) end },
                    { title = 'Hire', description = 'Add an employee by server ID. Wages are paid hourly from the account.', icon = '+', onSelect = function()
                        ask('Hire', { { type = 'number', name = 'target', label = 'Player server ID', required = true, min = 1 },
                                      { type = 'number', name = 'wage', label = 'Wage per hour (£)', required = true, min = 0.01, max = cfg.MaxWagePounds, step = 0.01 } },
                            function(v) act('nexoro_businesses:hire', { id = b.id, target = v.target, wage = v.wage }, 'Hired.') end) end },
                    { title = 'Staff', description = #lines > 0 and table.concat(lines, '  ·  ') or 'No staff yet.', icon = '≡', disabled = true },
                } })
                NexoroUI.ShowContext('nexoro_biz_' .. b.id)
            end }
        end
        for _, w in ipairs(data.working) do
            options[#options + 1] = { title = 'Work at ' .. w.name, description = 'Leave this job', icon = '↩', onSelect = function()
                act('nexoro_businesses:quit', { id = w.id }, 'You left ' .. w.name .. '.') end }
        end
        NexoroUI.RegisterContext({ id = 'nexoro_business_menu', title = 'Businesses', options = options })
        NexoroUI.ShowContext('nexoro_business_menu')
    end)
end

RegisterCommand('business', openMine, false)
