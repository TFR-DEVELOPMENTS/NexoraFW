fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_gambling'
author 'Nexoro Network Team'
description 'Nexoro gambling safety: one daily spending limit shared by the lottery and scratchcards'
version '1.0.0-beta'

dependencies { 'nexoro_core' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
