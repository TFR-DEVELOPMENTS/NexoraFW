fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_hud'
author 'Nexoro Network Team'
description 'Nexoro HUD: health, armour, hunger, thirst, stress, stamina, money, job, voice, vehicle (MPH), street, compass'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_ui/lib/client.lua', 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
