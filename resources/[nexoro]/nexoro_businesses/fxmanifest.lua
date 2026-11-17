fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_businesses'
author 'Nexoro Network Team'
description 'Nexoro businesses: register a business, its own bank account, staff with wages paid automatically'
version '1.0.0-beta'

dependencies { 'nexoro_core' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
