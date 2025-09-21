fx_version 'cerulean'
game 'gta5'

name 'cg-streetracing'
author 'CodeGremlins'
description 'Base street racing script (ESX + ox_lib + ox_target) with simple position/time UI'
version '0.1.0'

lua54 'yes'

shared_scripts {
	'@es_extended/imports.lua',
	'@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
	'client/main.lua',
	'client/ui.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

ui_page 'web/index.html'

files {
	'web/index.html',
	'web/style.css',
	'web/script.js'
}

dependencies {
	'es_extended',
	'ox_lib',
	'ox_target'
}
