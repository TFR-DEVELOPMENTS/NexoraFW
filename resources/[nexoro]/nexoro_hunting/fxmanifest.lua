fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_hunting'
author 'Nexoro Network Team'
description 'Nexoro hunting: needs a hunting licence, hunt at woodland spots with a cooldown'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory', 'nexoro_licences', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
