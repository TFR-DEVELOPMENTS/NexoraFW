fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_shops'
author 'Nexoro Network Team'
description 'Nexoro shops: buy and sell with stock that restocks over time'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
