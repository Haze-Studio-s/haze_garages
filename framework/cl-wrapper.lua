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

function Haze.Client.GetVehicleProperties(veh)
    if not veh or not DoesEntityExist(veh) then return {} end
    if lib and lib.getVehicleProperties then
        return lib.getVehicleProperties(veh)
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions and QBCore.Functions.GetVehicleProperties then
            return QBCore.Functions.GetVehicleProperties(veh)
        end
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        if ESX and ESX.Game and ESX.Game.GetVehicleProperties then
            return ESX.Game.GetVehicleProperties(veh)
        end
    end
    return {}
end

function Haze.Client.SetVehicleProperties(veh, props)
    if not veh or not DoesEntityExist(veh) or not props or type(props) ~= 'table' or next(props) == nil then return end
    if lib and lib.setVehicleProperties then
        lib.setVehicleProperties(veh, props)
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions and QBCore.Functions.SetVehicleProperties then
            QBCore.Functions.SetVehicleProperties(veh, props)
        end
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        if ESX and ESX.Game and ESX.Game.SetVehicleProperties then
            ESX.Game.SetVehicleProperties(veh, props)
        end
    end
end

function Haze.Client.RequestModel(model, timeout)
    if not model then return false end
    local modelHash = Haze.Shared.GetModelHash(model)
    if not modelHash then return false end

    if HasModelLoaded(modelHash) then return true end

    if lib and lib.requestModel then
        local success, res = pcall(lib.requestModel, modelHash, timeout)
        if success and res then return res end
    end

    if IsModelInCdimage(modelHash) or IsModelValid(modelHash) then
        RequestModel(modelHash)
        local start = GetGameTimer()
        while not HasModelLoaded(modelHash) do
            Wait(10)
            if GetGameTimer() - start > (timeout or 5000) then return false end
        end
        return HasModelLoaded(modelHash)
    end

    RequestModel(modelHash)
    local start = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - start > (timeout or 2000) then break end
    end
    return HasModelLoaded(modelHash)
end


