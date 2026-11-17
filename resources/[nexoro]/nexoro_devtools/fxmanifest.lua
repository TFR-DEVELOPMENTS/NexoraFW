fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_devtools'
author 'Nexoro Network Team'
description 'Nexoro developer tools for test servers: off unless nexoro_devmode is true. Quick test setup, self-check, and a console database reset.'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_database', 'nexoro_inventory' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
