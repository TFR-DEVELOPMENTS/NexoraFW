fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_prison'
author 'Nexoro Network Team'
description 'Nexoro prison: sentences from police arrests, time served on the server clock, release'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_police' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
