fx_version 'cerulean'
games { 'gta5' }

author 'Fae_Alchemy'
description 'Job-Owned Black Market with Custom Crafting, Money Wash, and Stock/Offline Access Management.'
version '1.1.1'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/inventory.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'ox_lib',
    'void_bridge'
}
