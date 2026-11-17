fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_admin'
author 'Nexoro Network Team'
description 'Nexoro in-game admin and moderator menu: players, vehicles, world, economy, logs, bans'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_identity' }

shared_script 'config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@nexoro_database/lib/db.lua',
    'server/main.lua',
}
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
