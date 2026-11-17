fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_emergency'
author 'Nexoro Network Team'
description 'Nexoro emergency services: departments, ranks, duty, callsigns, rosters and management'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
