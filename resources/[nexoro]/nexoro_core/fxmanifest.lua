fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_core'
author 'Nexoro Network Team'
description 'Nexoro framework core: players, characters, jobs, money, permissions, callbacks'
version '1.0.0-beta'

dependencies { 'oxmysql', 'nexoro_database' }

shared_scripts {
    'config/framework.lua',
    'shared/utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'config/staff.lua',
    'server/logging.lua',
    'server/security.lua',
    'server/callbacks.lua',
    'server/permissions.lua',
    'server/jobs.lua',
    'server/players.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/callbacks.lua',
    'client/keybinds.lua',
    'client/main.lua',
}

-- lib/client.lua is included by other resources: client_script '@nexoro_core/lib/client.lua'
files { 'lib/client.lua' }
