Haze = Haze or {}
Haze.Server = Haze.Server or {}

function Haze.Server.GetPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player then return player end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and QBCore and QBCore.Functions then
            local player = QBCore.Functions.GetPlayer(src)
            if player then return player end
        end
    end

    return nil
end

function Haze.Server.GetPlayerIdentifier(src)
    src = tonumber(src)
    if not src then return nil end

    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and xPlayer.identifier then
                return xPlayer.identifier
            end
        end
    end

    local identifiers = GetPlayerIdentifiers(src)
    if identifiers then
        for _, id in ipairs(identifiers) do
            if string.find(id, "license:") then
                return id
            end
        end
    end
    return nil
end

function Haze.Server.GetPlayerJob(src)
    src = tonumber(src)
    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.job then
        return player.PlayerData.job.name or "unemployed"
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            return xPlayer and xPlayer.job and xPlayer.job.name or "unemployed"
        end
    end
    return "unemployed"
end

function Haze.Server.GetPlayerGang(src)
    src = tonumber(src)
    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.gang then
        return player.PlayerData.gang.name or "none"
    end
    return "none"
end

function Haze.Server.IsPlayerOnlineByIdentifier(citizenid)
    if not citizenid then return false end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(citizenid) end)
        if ok and player then return true end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and QBCore and QBCore.Functions then
            local player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            if player then return true end
        end
    end

    return false
end

function Haze.Server.GetMoney(src)
    src = tonumber(src)
    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.money then
        return player.PlayerData.money.cash or 0
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            return xPlayer and xPlayer.getMoney() or 0
        end
    end
    return 0
end

function Haze.Server.RemoveMoney(src, amount)
    src = tonumber(src)
    if amount <= 0 then return true end

    local player = Haze.Server.GetPlayer(src)
    if player and player.Functions and player.PlayerData and player.PlayerData.money then
        if (player.PlayerData.money.cash or 0) >= amount then
            player.Functions.RemoveMoney('cash', amount, "haze-garages-payment")
            return true
        end
        return false
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and xPlayer.getMoney() >= amount then
                xPlayer.removeMoney(amount)
                return true
            end
        end
        return false
    end
    return true
end

function Haze.Server.GiveKey(src, plate)
    src = tonumber(src)
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
    src = tonumber(src)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function()
            exports.qbx_vehiclekeys:RemoveKeys(src, cleanPlate)
        end)
    end
end

function Haze.Server.Notify(src, msg, type)
    src = tonumber(src)
    TriggerClientEvent('ox_lib:notify', src, {
        title = Locale.system_name,
        description = msg,
        type = type or 'info'
    })
end

function Haze.Server.GetPlayerFullName(src)
    src = tonumber(src)
    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.charinfo then
        local fname = player.PlayerData.charinfo.firstname or ""
        local lname = player.PlayerData.charinfo.lastname or ""
        local full = (fname .. " " .. lname):gsub("^%s*(.-)%s*$", "%1")
        if full and full ~= "" then return full end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then return xPlayer.getName() end
        end
    end

    return GetPlayerName(src) or "Desconhecido"
end

function Haze.Server.GetPlayerPhone(src)
    src = tonumber(src)
    local player = Haze.Server.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.charinfo then
        return player.PlayerData.charinfo.phone or "N/A"
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
