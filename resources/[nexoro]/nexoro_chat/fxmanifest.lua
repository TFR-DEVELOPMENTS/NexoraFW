fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_chat'
author 'Nexoro Network Team'
description 'Nexoro public chat: server-verified job prefixes, channels, spam protection, moderation'
version '1.0.0-beta'

dependency 'nexoro_core'

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
