fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_driving'
author 'Nexoro Network Team'
description 'Nexoro driving aids: indicators, seatbelt chime, wet-road grip, vehicle state'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_world', 'nexoro_hud' }

shared_script 'config.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }
