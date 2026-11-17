fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_map'
author 'Nexoro Network Team'
description 'Nexoro map: stations, hospitals, shops and banks; live incidents, hazard zones and unit positions for emergency services'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_dispatch', 'nexoro_fire' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
