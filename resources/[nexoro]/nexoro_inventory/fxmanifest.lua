fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_inventory'
author 'Nexoro Network Team'
description 'Nexoro inventory: server-authoritative slots, weight, stacking, metadata, usable items'
version '1.0.0-beta'

dependency 'nexoro_core'

shared_scripts { 'config.lua', 'items.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/img/*.png' }
