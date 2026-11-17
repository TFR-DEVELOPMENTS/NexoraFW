fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_police'
author 'Nexoro Network Team'
description 'Nexoro police: cuffs, arrests, penalty notices, cautions, warrants, search, evidence, breath tests, MDT lookups'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_emergency', 'nexoro_inventory', 'nexoro_identity' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
