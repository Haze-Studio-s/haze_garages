local activeStreetVehicles = {}

local function isPlayerVehicleOwner(citizenid, plate, cb)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    MySQL.scalar("SELECT citizenid FROM player_vehicles WHERE plate = ? AND citizenid = ?", { cleanPlate, citizenid }, function(owner)
        cb(owner ~= nil)
    end)
end

local function findNearestFixedGarage(coords)
    local nearestId = "legion_square"
    local minDistance = 999999.0

    for garageId, gData in pairs(Config.FixedGarages or {}) do
        if gData.category == "car" or not gData.category then
            local dist = Haze.Shared.GetDistance(coords, gData.coords)
            if dist < minDistance then
                minDistance = dist
                nearestId = garageId
            end
        end
    end
    return nearestId
end

local function getPlayerStreetParkLimit(src)
    local limits = Config.StreetParkVIPLimits or { default = 1 }
    if exports.qbx_core then
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            if player.PlayerData.gang and limits[player.PlayerData.gang.name] then
                return limits[player.PlayerData.gang.name]
            end
        end
    end
    return limits.default or 1
end

local function checkExpiredStreetParkings()
    local hours = Config.StreetParkingExpirationHours or 72
    local rows = MySQL.query.await([[
        SELECT * FROM haze_street_parking 
        WHERE updated_at < DATE_SUB(NOW(), INTERVAL ? HOUR)
    ]], { hours })

    for _, row in ipairs(rows or {}) do
        local spotCoords = json.decode(row.coords)
        local nearestGarage = findNearestFixedGarage(spotCoords)

        MySQL.query("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { nearestGarage, row.plate })
        MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { row.plate })
        activeStreetVehicles[row.plate] = nil

        print(string.format("^3[Haze Garages]^7 Vaga de rua expirada para a placa %s. Veículo transferido para %s.", row.plate, nearestGarage))
    end
end

CreateThread(function()
    Wait(5000)
    checkExpiredStreetParkings()
    while true do
        Wait(3600000) -- Roda a cada 1 hora
        checkExpiredStreetParkings()
    end
end)

RegisterCommand(Config.StreetParkCommand or "estacionar", function(source, args)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return end

    TriggerClientEvent("haze_garages:client:requestStreetPark", src)
end, false)

lib.callback.register("haze_garages:server:handleStreetPark", function(source, vehData)
    local src = source
    if not vehData or not vehData.plate then return false, "Dados inválidos." end

    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador não encontrado." end

    local cleanPlate = Haze.Shared.CleanPlate(vehData.plate)
    local currentCoords = {
        x = vehData.x,
        y = vehData.y,
        z = vehData.z,
        w = vehData.heading
    }

    local p = promise.new()
    isPlayerVehicleOwner(citizenid, cleanPlate, function(isOwner)
        p:resolve(isOwner)
    end)

    local isOwner = Citizen.Await(p)
    if not isOwner then
        return false, Locale.not_vehicle_owner
    end

    local existingRow = MySQL.single.await("SELECT * FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    local feeRequired = 0
    local messageKey = ""

    if existingRow and existingRow.coords then
        local savedCoords = json.decode(existingRow.coords)
        local dist = Haze.Shared.GetDistance(currentCoords, savedCoords)
        if dist > Config.DynamicSpotTolerance then
            feeRequired = Config.StreetParkingFee
            messageKey = "street_parked_replaced"
        else
            feeRequired = 0
            messageKey = "street_parked_free_spot"
        end
    else
        local countRow = MySQL.single.await("SELECT COUNT(*) as total FROM haze_street_parking WHERE citizenid = ?", { citizenid })
        local currentParkedCount = countRow and countRow.total or 0
        local maxAllowed = getPlayerStreetParkLimit(src)

        if currentParkedCount >= maxAllowed then
            return false, string.format(Locale.street_park_limit_reached, currentParkedCount, maxAllowed)
        end

        feeRequired = Config.StreetParkingFee
        messageKey = "street_parked_new_spot"
    end

    if feeRequired > 0 then
        local playerMoney = Haze.Server.GetMoney(src)
        if playerMoney < feeRequired then
            return false, string.format(Locale.no_money, Config.Currency, feeRequired)
        end
        Haze.Server.RemoveMoney(src, feeRequired)
    end

    MySQL.query([[
        REPLACE INTO haze_street_parking (plate, citizenid, coords, model, cost_paid)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        cleanPlate,
        citizenid,
        json.encode(currentCoords),
        tostring(vehData.model or ""),
        feeRequired
    })

    activeStreetVehicles[cleanPlate] = {
        plate = cleanPlate,
        citizenid = citizenid,
        coords = currentCoords,
        model = vehData.model,
        props = vehData.props
    }

    Haze.Server.GiveKey(src, cleanPlate)
    local msg = string.format(Locale[messageKey], Config.Currency, feeRequired)
    Haze.Server.Notify(src, msg, "success")
    return true
end)

lib.callback.register("haze_garages:server:checkVehicleOfflineLock", function(source, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local row = MySQL.single.await("SELECT citizenid FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    if not row then
        row = MySQL.single.await("SELECT citizenid FROM player_vehicles WHERE plate = ?", { cleanPlate })
    end

    if row and row.citizenid then
        local isOnline = Haze.Server.IsPlayerOnlineByIdentifier(row.citizenid)
        return not isOnline -- Retorna verdadeiro se o dono estiver OFFLINE
    end

    return false
end)

lib.callback.register("haze_garages:server:getStreetParkedVehicles", function(source)
    local rows = MySQL.query.await([[
        SELECT s.plate, s.citizenid, s.coords, s.model AS street_model, p.vehicle AS pv_model 
        FROM haze_street_parking s 
        LEFT JOIN player_vehicles p ON s.plate = p.plate
    ]])
    local result = {}
    for _, row in ipairs(rows or {}) do
        local modelToUse = (row.street_model and row.street_model ~= "") and row.street_model or row.pv_model
        result[#result + 1] = {
            plate = row.plate,
            citizenid = row.citizenid,
            coords = json.decode(row.coords),
            model = modelToUse
        }
    end
    return result
end)

lib.callback.register("haze_garages:server:unparkStreetVehicle", function(source, plate)
    local src = source
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    
    MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    activeStreetVehicles[cleanPlate] = nil
    Haze.Server.GiveKey(src, cleanPlate)
    Haze.Server.Notify(src, Locale.street_park_removed, "info")
    return true
end)
