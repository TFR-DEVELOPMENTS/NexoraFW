fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_postal'
author 'Nexoro Network Team'
description 'Nexoro postal worker: delivery rounds with GPS stops, paid per stop when you are really there'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
