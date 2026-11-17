fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexoro_loading'
author 'Nexoro Network Team'
description 'Nexoro custom loading screen: tips, rules, announcements, music player, real loading progress'
version '1.0.0-beta'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'          -- lets the mouse move on the loading screen (volume, music controls)   -- nexoro_character closes it once the character scene is ready
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/config.js', 'html/audio/*', 'html/img/*' }
