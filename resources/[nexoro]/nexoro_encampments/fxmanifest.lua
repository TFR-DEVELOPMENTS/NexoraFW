fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_encampments'
author 'Nexoro Network Team'
description 'Nexoro encampments: claim a pitch on open land, police notices, warrants after the deadline, gate control'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_police', 'nexoro_ui' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
