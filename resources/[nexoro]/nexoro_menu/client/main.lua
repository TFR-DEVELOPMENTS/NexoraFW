local cfg = Config.Menu

local function character()
    local ok, data = pcall(function() return exports.nexoro_core:GetCharacterData() end)
    return ok and data or nil
end

local function gbp(n) return ('£%s'):format((('%.2f'):format(n or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')) end

local function showCharacter()
    local c = character()
    if not c then return end
    CreateThread(function()
        NexoroUI.Alert({ title = c.firstName .. ' ' .. c.lastName, text = table.concat({
            'Citizen ID: ' .. c.citizenId,
            'Date of birth: ' .. (c.dob:gsub('(%d+)%-(%d+)%-(%d+)', '%3/%2/%1')),
            'Nationality: ' .. c.nationality,
            'Height: ' .. c.height .. ' cm',
            'Job: ' .. (c.job and (c.job.label .. ' (' .. c.job.gradeLabel .. ')') or 'Unemployed'),
            'Cash: ' .. gbp(c.cash),
            'Bank: ' .. gbp(c.bank),
        }, '\n') })
    end)
end

local function helpOptions()
    local options = {}
    for _, article in ipairs(cfg.Help) do
        options[#options + 1] = { title = article.title, icon = '?', onSelect = function()
            CreateThread(function()
                NexoroUI.Alert({ title = article.title, text = article.text })
                NexoroUI.ShowContext('nexoro_menu_help')
            end)
        end }
    end
    return options
end

local function register()
    NexoroUI.RegisterContext({ id = 'nexoro_menu_help', title = 'Help centre', menu = 'nexoro_menu_main', options = helpOptions() })
    NexoroUI.RegisterContext({ id = 'nexoro_menu_main', title = 'Player menu', options = {
        { title = 'My character', description = 'Shows your name, Citizen ID, date of birth, job, cash and bank.', icon = '☺', onSelect = showCharacter },
        { title = 'Phone', icon = '☎', description = 'Open your phone (F1). Needs a mobile phone item.', onSelect = function() ExecuteCommand('phone') end },
        { title = 'Inventory', icon = '▣', description = 'Open your inventory (I). Drag items to move them; right-click to use.', onSelect = function() ExecuteCommand('inventory') end },
        { title = 'My vehicles', description = 'Keys, insurance, MOT, finance and selling', icon = '⛟', onSelect = function() ExecuteCommand('vehicles') end },
        { title = 'Wardrobe', description = 'Change clothes and save outfits. Unsaved changes are lost when you close it.', icon = '♦', onSelect = function() ExecuteCommand('wardrobe') end },
        { title = 'HUD settings', description = 'Move the HUD, change its size, or hide parts of it. Your choices are remembered.', icon = '▤', onSelect = function() ExecuteCommand('hud') end },
        { title = 'Help centre', description = 'Controls, rules, banking, phone and more', icon = '?', menu = 'nexoro_menu_help' },
        { title = 'Switch character', description = 'Saves your progress and takes you back to character selection (you stay connected).', icon = '⇄', onSelect = function()
            CreateThread(function()
                if NexoroUI.Confirm({ title = 'Switch character?', text = 'Your progress is saved. You will return to character selection.', confirmLabel = 'Switch' }) then ExecuteCommand('logout') end
            end)
        end },
    } })
end

local function openMenu(id)
    local ok, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
    if not ok or not loaded then return end
    NexoroUI.ShowContext(id or 'nexoro_menu_main')
end

CreateThread(function()
    while GetResourceState('nexoro_ui') ~= 'started' or GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    register()
    exports.nexoro_core:RegisterKeybind('player_menu', 'Open player menu', cfg.OpenKey, function() openMenu() end)
end)

RegisterCommand('help', function() openMenu('nexoro_menu_help') end, false)
RegisterCommand('menu', function() openMenu() end, false)
