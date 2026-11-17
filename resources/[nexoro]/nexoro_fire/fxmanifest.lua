fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_fire'
author 'Nexoro Network Team'
description 'Nexoro fire and rescue: incidents, extinguishing, extrication, hazard zones'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_emergency', 'nexoro_identity' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
