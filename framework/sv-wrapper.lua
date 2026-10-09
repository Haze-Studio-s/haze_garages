Haze = Haze or {}
Haze.Server = Haze.Server or {}

local QBX = exports['qbx_core']

function Haze.Server.GetPlayerIdentifier(src)
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier or nil
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if string.find(id, "license:") then
            return id
        end
    end
    return nil
end

function Haze.Server.GetPlayerJob(src)
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        return player and player.PlayerData.job and player.PlayerData.job.name or "unemployed"
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.job and player.PlayerData.job.name or "unemployed"
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.job and xPlayer.job.name or "unemployed"
    end
    return "unemployed"
end

function Haze.Server.GetPlayerGang(src)
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        return player and player.PlayerData.gang and player.PlayerData.gang.name or "none"
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.gang and player.PlayerData.gang.name or "none"
    end
    return "none"
end

function Haze.Server.IsPlayerOnlineByIdentifier(citizenid)
    if not citizenid then return false end
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayerByCitizenId(citizenid)
        return player ~= nil
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        return player ~= nil
    end
    return false
end

function Haze.Server.GetMoney(src)
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        return player and player.PlayerData.money.cash or 0
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.money.cash or 0
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.getMoney() or 0
    end
    return 999999
end

function Haze.Server.RemoveMoney(src, amount)
    if amount <= 0 then return true end
    
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        if player and player.PlayerData.money.cash >= amount then
            player.Functions.RemoveMoney('cash', amount, "haze-garages-payment")
            return true
        end
        return false
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData.money.cash >= amount then
            player.Functions.RemoveMoney('cash', amount, "haze-garages-payment")
            return true
        end
        return false
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            return true
        end
        return false
    end
    return true
end

function Haze.Server.GiveKey(src, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(src, cleanPlate)
        end)
    elseif GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, cleanPlate)
    end
end

function Haze.Server.RemoveKey(src, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function()
            exports.qbx_vehiclekeys:RemoveKeys(src, cleanPlate)
        end)
    end
end

function Haze.Server.Notify(src, msg, type)
    TriggerClientEvent('ox_lib:notify', src, {
        title = Locale.system_name,
        description = msg,
        type = type or 'info'
    })
end

function Haze.Server.GetPlayerFullName(src)
    if not src then return "Desconhecido" end
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local fname = player.PlayerData.charinfo.firstname or ""
            local lname = player.PlayerData.charinfo.lastname or ""
            return (fname .. " " .. lname):gsub("^%s*(.-)%s*$", "%1")
        end
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local fname = player.PlayerData.charinfo.firstname or ""
            local lname = player.PlayerData.charinfo.lastname or ""
            return (fname .. " " .. lname):gsub("^%s*(.-)%s*$", "%1")
        end
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            return xPlayer.getName()
        end
    end
    return GetPlayerName(src) or "Desconhecido"
end

function Haze.Server.GetPlayerPhone(src)
    if not src then return "N/A" end
    if GetResourceState('qbx_core') == 'started' and QBX then
        local player = QBX:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            return player.PlayerData.charinfo.phone or "N/A"
        end
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            return player.PlayerData.charinfo.phone or "N/A"
        end
    end
    return "N/A"
end

function Haze.Server.NotifyPoliceAlert(coords, plate, title, message)
    if GetResourceState('ps-dispatch') == 'started' then
        pcall(function()
            exports['ps-dispatch']:CustomAlert({
                coords = coords,
                message = message or "Tentativa de arrombamento de veículo",
                dispatchCode = "10-90",
                description = string.format("%s | Placa: %s", message, plate),
                radius = 0,
                sprite = 161,
                color = 1,
                scale = 0.8,
                length = 3
            })
        end)
    end

    local policeJobs = Config.PoliceJobs or { "police", "sheriff" }
    local players = GetPlayers()
    for _, pId in ipairs(players) do
        local targetSrc = tonumber(pId)
        local job = Haze.Server.GetPlayerJob(targetSrc)
        for _, pJob in ipairs(policeJobs) do
            if job == pJob then
                TriggerClientEvent('ox_lib:notify', targetSrc, {
                    title = title or "🚨 Chamado Policial - Arrombamento",
                    description = string.format("%s [Placa: %s]", message, plate),
                    type = "error",
                    duration = 10000
                })
                TriggerClientEvent('haze_garages:client:addPoliceBlip', targetSrc, coords, plate)
                break
            end
        end
    end
end

