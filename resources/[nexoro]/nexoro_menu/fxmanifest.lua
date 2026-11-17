fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_menu'
author 'Nexoro Network Team'
description 'Nexoro player menu and in-game help centre'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
client_scripts { '@nexoro_ui/lib/client.lua', 'client/main.lua' }
