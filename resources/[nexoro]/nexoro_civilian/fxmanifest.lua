fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_civilian'
author 'Nexoro Network Team'
description 'Nexoro civilian jobs: take a job at the job centre, go on duty, and do the tasks at the job points for pay'
version '1.0.0-beta'

dependencies { 'nexoro_core', 'nexoro_ui' }

shared_script 'config.lua'
server_script 'server/main.lua'
client_scripts { '@nexoro_core/lib/client.lua', '@nexoro_ui/lib/client.lua', 'client/main.lua' }
