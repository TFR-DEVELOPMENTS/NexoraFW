fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_transport'
author 'Nexoro Network Team'
description 'Nexoro public transport: bus routes with stops, paid by distance, tapped on and off'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
