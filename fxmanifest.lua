fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'Auren_Death'
author 'APEX'
description 'Revólveres PD, suspensão persistente e cerimônias para MRI QBOX'
version '1.1.3'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/database.lua', 'server/registry.lua', 'server/npcs.lua', 'server/main.lua', 'server/admin.lua' }
client_scripts { 'client/effects.lua', 'client/npcs.lua', 'client/main.lua', 'client/admin.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js', 'web/assets/*.png', 'web/assets/*.wav' }
dependencies { '/onesync', 'qbx_core', 'ox_lib', 'ox_inventory', 'oxmysql', 'ox_target' }
