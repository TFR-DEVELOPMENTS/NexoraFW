fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_identity'
author 'Nexoro Network Team'
description 'Nexoro identity rules: UK-style character validation and citizen IDs'
version '1.0.0-beta'

dependency 'nexoro_core'

server_scripts {
    'config.lua',
    'server/validation.lua',
    'server/main.lua',
}
