fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_banking'
author 'Nexoro Network Team'
description 'Nexoro banking: deposits, withdrawals, transfers, statements, salaries'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_identity' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
