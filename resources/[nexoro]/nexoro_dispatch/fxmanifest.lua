fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_dispatch'
author 'Nexoro Network Team'
description 'Nexoro dispatch: 999/101/111 calls, incidents, unit status and assignment, GPS, radio channels'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_emergency', 'nexoro_inventory' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
