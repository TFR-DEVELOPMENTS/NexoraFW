fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_robbery'
author 'Nexoro Network Team'
description 'Nexoro robberies: stores and ATMs, need a lockpick, cooldowns, raise an alarm to police dispatch'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_dispatch', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
