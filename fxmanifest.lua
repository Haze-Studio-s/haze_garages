fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'haze_garages'
author 'Haze Studios'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/pt-BR.lua',
    'shared/main.lua'
}

client_scripts {
    'framework/cl-wrapper.lua',
    'client/cl-main.lua',
    'client/cl-creator.lua',
    'client/cl-garage.lua',
    'client/cl-street-parking.lua',
    'client/cl-parking-meters.lua',
    'client/cl-deformation.lua',
    'client/cl-tracker.lua',
    'client/cl-valet.lua',
    'client/cl-corporate.lua',
    'client/cl-coowner.lua',
    'client/cl-insurance.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'framework/sv-wrapper.lua',
    'server/sv-database.lua',
    'server/sv-garages-data.lua',
    'server/sv-creator.lua',
    'server/sv-corporate.lua',
    'server/sv-garage.lua',
    'server/sv-street-parking.lua',
    'server/sv-parking-meters.lua',
    'server/sv-deformation.lua',
    'server/sv-autostore.lua',
    'server/sv-tracker.lua',
    'server/sv-impound.lua',
    'server/sv-valet.lua',
    'server/sv-coowner.lua',
    'server/sv-insurance.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/phone.html',
    'web/phone.css',
    'web/phone.js',
    'web/icon.png',
    'data/garages.json'
}

exports {
    'dvVehicle',
    'StoreVehicleNearestGarage',
    'ImpoundVehicle',
    'IsTrackerInstalled',
    'IsTrackerJammed',
    'OpenGarageMenu',
    'StoreVehicleAtGarage',
    'GetGarageData'
}

server_exports {
    'RegisterDynamicGarage',
    'UnregisterDynamicGarage',
    'IsGarageRegistered',
    'GetGarage',
    'GetGaragesData',
    'SaveGaragesData',
    'GetDynamicGarages'
}


