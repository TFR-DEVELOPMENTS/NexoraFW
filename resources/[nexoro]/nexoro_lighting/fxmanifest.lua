fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_lighting'
author 'Nexoro Network Team'
description 'Nexoro emergency lighting: preset LED patterns drawn for nearby players, synced sirens, driver controls'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_emergency' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
