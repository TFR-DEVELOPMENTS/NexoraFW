fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_scratchcards'
author 'Nexoro Network Team'
description 'Nexoro scratchcards: instant win, published odds, shared daily gambling limit'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_gambling', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
