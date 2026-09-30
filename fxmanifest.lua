fx_version 'cerulean'
game 'gta5'

author 'Los Santos Amusements'
description 'Scratch & Win - item-based instant-win scratchcards (server-authoritative RNG)'
version '1.0.0'

shared_scripts {
  'config.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/bridge.lua',
  'server/inventory.lua',
  'server/log.lua',
  'server/webhook.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}

-- No query string on purpose (?v=1 on this exact line has previously broken FXServer's files{}
-- matching for us and made the whole page fail to load, which renders as a solid black screen).
-- Cache-bust internal assets instead, inside html/index.html itself, if you ever need to.
ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}

-- ox_inventory is the primary target; qb-inventory is auto-detected and supported too (see
-- server/inventory.lua) but isn't declared as a hard dependency since either one works.
dependencies {
  'oxmysql',
}
