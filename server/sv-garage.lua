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
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate COLLATE utf8mb4_unicode_ci = pv.plate COLLATE utf8mb4_unicode_ci
        WHERE (pv.citizenid IS NOT NULL AND pv.citizenid COLLATE utf8mb4_unicode_ci = ? COLLATE utf8mb4_unicode_ci)
           OR (pv.license IS NOT NULL AND pv.license COLLATE utf8mb4_unicode_ci = ? COLLATE utf8mb4_unicode_ci)
    ]], { citizenid or "NONE", citizenid or "NONE" })

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

lib.callback.register("haze_garages:server:getDetailedPlayerVehicles", function(source)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    local license = nil

    local identifiers = GetPlayerIdentifiers(src)
    if identifiers then
        for _, id in ipairs(identifiers) do
            if string.find(id, "license:") then
                license = id
                break
            end
        end
    end

    print(string.format("^3[Haze Garages]^7 Buscando veículos para citizenid: '%s' | license: '%s' (src: %s)", tostring(citizenid), tostring(license), tostring(src)))

    local pvRows = MySQL.query.await([[
        SELECT pv.*, 
               hsp.coords AS street_coords,
               hsp.model AS street_model,
               hsd.deformation, 
               hsd.mechanical_damage,
               gvw.wear_data,
               gvw.mileage
        FROM player_vehicles pv
        LEFT JOIN haze_street_parking hsp ON hsp.plate COLLATE utf8mb4_unicode_ci = pv.plate COLLATE utf8mb4_unicode_ci
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate COLLATE utf8mb4_unicode_ci = pv.plate COLLATE utf8mb4_unicode_ci
        LEFT JOIN granolla_vehicle_wear gvw ON gvw.plate COLLATE utf8mb4_unicode_ci = pv.plate COLLATE utf8mb4_unicode_ci
        WHERE (pv.citizenid IS NOT NULL AND pv.citizenid COLLATE utf8mb4_unicode_ci = ? COLLATE utf8mb4_unicode_ci)
           OR (pv.license IS NOT NULL AND pv.license COLLATE utf8mb4_unicode_ci = ? COLLATE utf8mb4_unicode_ci)
    ]], { citizenid or "NONE", license or "NONE" })

    print(string.format("^2[Haze Garages]^7 Total de veículos encontrados no DB: %d", #(pvRows or {})))

    local vehicles = {}
    for _, row in ipairs(pvRows or {}) do
        local mods = row.mods and json.decode(row.mods) or {}
        local wearData = row.wear_data and json.decode(row.wear_data) or nil
        local streetCoords = row.street_coords and json.decode(row.street_coords) or nil

        local statusLabel = "Fora da Garagem"
        local isSpawnable = false
        local spawnType = "none"

        if row.state == 1 then
            if row.garage and Config.FixedGarages[row.garage] then
                statusLabel = Config.FixedGarages[row.garage].label or ("Garagem: " .. row.garage)
                isSpawnable = true
                spawnType = "fixed"
            else
                statusLabel = "Guardado em Garagem Fixa"
                isSpawnable = true
                spawnType = "fixed_default"
            end
        elseif streetCoords then
            statusLabel = "Estacionado na Rua"
            isSpawnable = true
            spawnType = "street"
        elseif row.state == 2 then
            statusLabel = "Apreendido / Impound"
            isSpawnable = false
            spawnType = "impound"
        elseif row.state == 0 then
            statusLabel = "Na Rua / Em Uso"
            isSpawnable = false
            spawnType = "out"
        end

        table.insert(vehicles, {
            plate = row.plate,
            model = row.street_model or row.vehicle or row.model,
            label = row.vehicle or row.model,
            state = row.state,
            garage = row.garage,
            statusLabel = statusLabel,
            isSpawnable = isSpawnable,
            spawnType = spawnType,
            streetCoords = streetCoords,
            mods = mods,
            engineHealth = mods.engineHealth or 1000,
            bodyHealth = mods.bodyHealth or 1000,
            fuel = mods.fuelLevel or 100,
            wearData = wearData,
            mileage = row.mileage or 0
        })
    end

    return vehicles
end)

lib.callback.register("haze_garages:server:unparkOrSpawnVehicle", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local vehRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?", { cleanPlate, citizenid })
    if not vehRow then
        return false, Locale.not_vehicle_owner
    end

    local streetRow = MySQL.single.await("SELECT * FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    local defRow = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    local spawnCoords = nil

    if streetRow and streetRow.coords then
        spawnCoords = json.decode(streetRow.coords)
        MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    elseif vehRow.garage and Config.FixedGarages[vehRow.garage] then
        spawnCoords = Config.FixedGarages[vehRow.garage].spawnCoords
    else
        local defaultG = Config.FixedGarages["legion_square"]
        spawnCoords = defaultG and defaultG.spawnCoords or vec4(222.10, -805.20, 30.6, 140.0)
    end

    MySQL.query("UPDATE player_vehicles SET state = 0 WHERE plate = ?", { cleanPlate })
    Haze.Server.GiveKey(src, cleanPlate)

    return true, {
        plate = cleanPlate,
        model = streetRow and streetRow.model or vehRow.vehicle or vehRow.model,
        mods = vehRow.mods and json.decode(vehRow.mods) or nil,
        deformation = defRow and defRow.deformation and json.decode(defRow.deformation) or nil,
        mechanical = defRow and defRow.mechanical_damage and json.decode(defRow.mechanical_damage) or nil,
        spawnCoords = spawnCoords
    }
end)

RegisterNetEvent("haze_garages:server:giveVehicleKeys", function(netId, plate)
    local src = source
    Haze.Server.GiveKey(src, plate, netId)
end)
