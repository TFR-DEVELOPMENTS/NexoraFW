fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_farming'
author 'Nexoro Network Team'
description 'Nexoro farming: plant wheat on farm plots, come back when it is ready, harvest what you planted'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_ui' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
