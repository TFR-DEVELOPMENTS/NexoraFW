fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_crews'
author 'Nexoro Network Team'
description 'Nexoro crews: player-made groups with a leader, invites, members and a shared name'
version '1.0.0-beta'

dependencies { 'nexoro_core' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
