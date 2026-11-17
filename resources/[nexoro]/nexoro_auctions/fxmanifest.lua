fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_auctions'
author 'Nexoro Network Team'
description 'Nexoro auction house: items held in escrow, bids refunded when outbid, settled when time runs out'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
