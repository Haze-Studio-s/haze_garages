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

function Haze.Server.Notify(src, msg, type)
    TriggerClientEvent('ox_lib:notify', src, {
        title = Locale.system_name,
        description = msg,
        type = type or 'info'
    })
end
