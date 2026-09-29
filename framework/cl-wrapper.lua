Haze = Haze or {}
Haze.Client = Haze.Client or {}

Haze.Client.Framework = nil

local function initFramework()
    if GetResourceState('qbx_core') == 'started' then
        Haze.Client.Framework = 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        Haze.Client.Framework = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        Haze.Client.Framework = 'esx'
    else
        Haze.Client.Framework = 'standalone'
    end
end

initFramework()

function Haze.Client.Notify(msg, type)
    if lib and lib.notify then
        lib.notify({
            title = Locale.system_name,
            description = msg,
            type = type or 'info'
        })
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(msg)
        DrawNotification(false, false)
    end
end
