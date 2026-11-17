fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_world'
author 'Nexoro Network Team'
description 'Nexoro world: UK real-time clock (GMT/BST), realistic weather cycle with smooth transitions, traffic and pedestrian density'
version '1.0.0-beta'

dependencies { 'nexoro_core' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
