fx_version 'adamant'
game 'gta5'
lua54 'yes'

author 'Cyber Anticheat'
name 'CyberAnticheat'
description '[CYBER ANTICHEAT]'

client_scripts {
    'client/client-obfuscated.lua',
    'client/menu-obfuscated.lua'
}

server_scripts {
    'config.lua',
    'server/server-obfuscated.lua',
    'html/bans.json',
    'html/announcements.json'
}

shared_scripts {
    '@ox_lib/init.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/bans.json',
    'html/announcements.json',
    'html/inportant_accepted.json',
    'html/img/**.png'
}

dependencies {
    'ox_lib'
}