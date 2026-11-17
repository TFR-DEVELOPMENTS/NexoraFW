fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_lottery'
author 'Nexoro Network Team'
description 'Nexoro national lottery: weekly draw of six numbers, prizes for 4, 5 and 6 matches, rollover when nobody wins'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_gambling', 'nexoro_ui' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
