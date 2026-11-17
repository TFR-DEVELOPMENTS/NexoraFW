fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_database'
author 'Nexoro Network Team'
description 'Nexoro database layer and migration runner'
version '1.0.0-beta'

dependency 'oxmysql'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'lib/db.lua',
    'server/migrations.lua',
    'server/main.lua',
}
