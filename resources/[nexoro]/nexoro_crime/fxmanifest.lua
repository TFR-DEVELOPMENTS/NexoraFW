fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_crime'
author 'Nexoro Network Team'
description 'Nexoro crime: vehicle theft, house robbery with the owner away, and a fence for stolen goods. Each raises an alarm to dispatch.'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_vehicles', 'nexoro_housing', 'nexoro_dispatch', 'nexoro_ui' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
