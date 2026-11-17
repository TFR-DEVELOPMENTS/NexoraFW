fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_markets'
author 'Nexoro Network Team'
description 'Nexoro illegal markets: street contacts for narcotics and unregistered weapons. Daily caps and a chance of an alarm on every deal.'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_dispatch', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
