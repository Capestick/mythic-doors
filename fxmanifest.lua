fx_version 'cerulean'
game 'gta5'
lua54 'yes'
client_script "@mythic-base/components/cl_error.lua"
client_script "@pwnzor/client/check.lua"



client_scripts {
    'config.lua',
    'utils.lua',
    'shared/elevatorConfig.lua',
    'shared/doorConfig/**/*.lua',
    'client/bridge.lua',
    'client/garages.lua',
    'client/elevators.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'utils.lua',
    'shared/elevatorConfig.lua',
    'shared/doorConfig/**/*.lua',
    'server/convert_to_ox.lua',
    'server/bridge.lua',
}