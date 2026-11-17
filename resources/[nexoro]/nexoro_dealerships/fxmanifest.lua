fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_dealerships'
author 'Nexoro Network Team'
description 'Nexoro car dealerships: cash, bank or finance purchases, dealer buyback'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui', 'nexoro_vehicles' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
