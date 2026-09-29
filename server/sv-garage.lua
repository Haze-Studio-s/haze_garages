local spawnReservations = {}

local function releaseSpawnReservation(src, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if spawnReservations[cleanPlate] and spawnReservations[cleanPlate].src == src then
        spawnReservations[cleanPlate] = nil
    end
end

local function canPlayerAccessGarage(src, garageData)
    if not garageData then return false end

    if garageData.type == "public" or not garageData.type then
        return true
    elseif garageData.type == "job" and garageData.job then
        local playerJob = Haze.Server.GetPlayerJob(src)
        return playerJob == garageData.job
    elseif garageData.type == "gang" and garageData.gang then
        local playerGang = Haze.Server.GetPlayerGang(src)
        return playerGang == garageData.gang
    end

    return true
end

lib.callback.register("haze_garages:server:getUserVehicles", function(source, garageId)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return {} end

    local garageData = Config.FixedGarages[garageId]
    if not canPlayerAccessGarage(src, garageData) then
        return {}
    end

    local rows = MySQL.query.await([[
        SELECT pv.*, hsd.deformation, hsd.mechanical_damage
        FROM player_vehicles pv
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate = pv.plate
        WHERE pv.citizenid = ? AND pv.state = 1
    ]], { citizenid })

    return rows or {}
end)

lib.callback.register("haze_garages:server:spawnVehicle", function(source, plate, garageId)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local garage = Config.FixedGarages[garageId]
    if not garage then
        return false, "Garagem inválida."
    end

    if not canPlayerAccessGarage(src, garage) then
        return false, Locale.no_permission
    end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if spawnReservations[cleanPlate] then
        return false, Locale.error_spawn_reservation
    end

    spawnReservations[cleanPlate] = { src = src, time = os.time() }

    local vehRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?", { cleanPlate, citizenid })
    if not vehRow then
        releaseSpawnReservation(src, cleanPlate)
        return false, Locale.not_vehicle_owner
    end

    local defRow = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    MySQL.query("UPDATE player_vehicles SET state = 0 WHERE plate = ?", { cleanPlate })
    Haze.Server.GiveKey(src, cleanPlate)

    releaseSpawnReservation(src, cleanPlate)
    return true, {
        plate = cleanPlate,
        model = vehRow.vehicle or vehRow.model,
        mods = vehRow.mods and json.decode(vehRow.mods) or nil,
        deformation = defRow and defRow.deformation and json.decode(defRow.deformation) or nil,
        mechanical = defRow and defRow.mechanical_damage and json.decode(defRow.mechanical_damage) or nil,
        spawnCoords = garage.spawnCoords
    }
end)

lib.callback.register("haze_garages:server:storeVehicle", function(source, plate, garageId, vehicleProps, deformationData, mechanicalData)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local garageData = Config.FixedGarages[garageId]
    if not canPlayerAccessGarage(src, garageData) then
        return false, Locale.no_permission
    end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local isOwner = MySQL.scalar.await("SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?", { cleanPlate, citizenid })
    if not isOwner then
        return false, Locale.not_vehicle_owner
    end

    if vehicleProps then
        MySQL.query("UPDATE player_vehicles SET mods = ?, state = 1, garage = ? WHERE plate = ?", { json.encode(vehicleProps), garageId, cleanPlate })
    else
        MySQL.query("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { garageId, cleanPlate })
    end

    if deformationData or mechanicalData then
        MySQL.query([[
            REPLACE INTO haze_vehicle_deformations (plate, deformation, mechanical_damage)
            VALUES (?, ?, ?)
        ]], {
            cleanPlate,
            deformationData and json.encode(deformationData) or nil,
            mechanicalData and json.encode(mechanicalData) or nil
        })
    end

    Haze.Server.RemoveKey(src, cleanPlate)
    Haze.Server.Notify(src, Locale.vehicle_stored, "success")
    return true
end)
