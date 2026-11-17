fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_death'
author 'Nexoro Network Team'
description 'Nexoro death: lie down, bleed out after 300 seconds, revive by emergency services, respawn at hospital keeping your clothes'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
