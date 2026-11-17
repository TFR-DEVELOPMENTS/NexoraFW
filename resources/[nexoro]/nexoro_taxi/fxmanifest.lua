fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_taxi'
author 'Nexoro Network Team'
description 'Nexoro taxi: a real civilian job. Fares are measured on the server and paid from the bank of the passenger'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
