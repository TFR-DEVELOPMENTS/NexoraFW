fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_tablet'
author 'Nexoro Network Team'
description 'Nexoro department tablet: one secure app shell for dispatch, MDT, patient records, incidents and hazards'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_emergency', 'nexoro_inventory', 'nexoro_dispatch' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
