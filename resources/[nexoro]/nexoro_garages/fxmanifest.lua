fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_garages'
author 'Nexoro Network Team'
description 'Nexoro garages and impound lots: store and retrieve owned vehicles'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui', 'nexoro_vehicles' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
