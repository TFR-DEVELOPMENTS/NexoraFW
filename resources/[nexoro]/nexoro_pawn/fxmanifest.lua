fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_pawn'
author 'Nexoro Network Team'
description 'Nexoro pawn shop: sell items for cash at fixed pawn prices'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_inventory' }

shared_script 'config.lua'
server_script 'server/main.lua'
