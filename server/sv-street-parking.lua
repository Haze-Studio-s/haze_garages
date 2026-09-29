local activeStreetVehicles = {}

local function isPlayerVehicleOwner(citizenid, plate, cb)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    MySQL.scalar("SELECT citizenid FROM player_vehicles WHERE plate = ? AND citizenid = ?", { cleanPlate, citizenid }, function(owner)
        cb(owner ~= nil)
    end)
end

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
    local isNewOrReplaced = false
    local messageKey = ""

    if existingRow and existingRow.coords then
        local savedCoords = json.decode(existingRow.coords)
        local dist = Haze.Shared.GetDistance(currentCoords, savedCoords)
        if dist > Config.DynamicSpotTolerance then
            feeRequired = Config.StreetParkingFee
            isNewOrReplaced = true
            messageKey = "street_parked_replaced"
        else
            feeRequired = 0
            isNewOrReplaced = false
            messageKey = "street_parked_free_spot"
        end
    else
        feeRequired = Config.StreetParkingFee
        isNewOrReplaced = true
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
        REPLACE INTO haze_street_parking (plate, citizenid, coords, cost_paid)
        VALUES (?, ?, ?, ?)
    ]], {
        cleanPlate,
        citizenid,
        json.encode(currentCoords),
        feeRequired
    })

    activeStreetVehicles[cleanPlate] = {
        plate = cleanPlate,
        citizenid = citizenid,
        coords = currentCoords,
        model = vehData.model,
        props = vehData.props
    }

    local msg = string.format(Locale[messageKey], Config.Currency, feeRequired)
    Haze.Server.Notify(src, msg, "success")
    return true
end)

lib.callback.register("haze_garages:server:getStreetParkedVehicles", function(source)
    local rows = MySQL.query.await("SELECT * FROM haze_street_parking")
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[#result + 1] = {
            plate = row.plate,
            citizenid = row.citizenid,
            coords = json.decode(row.coords)
        }
    end
    return result
end)

lib.callback.register("haze_garages:server:unparkStreetVehicle", function(source, plate)
    local src = source
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    
    MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    activeStreetVehicles[cleanPlate] = nil
    Haze.Server.Notify(src, Locale.street_park_removed, "info")
    return true
end)
