fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_housing'
author 'Nexoro Network Team'
description 'Nexoro housing: buy and sell property, weekly bills with arrears and repossession, keys, storage'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_ui' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
