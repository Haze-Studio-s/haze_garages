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
    if not citizenid then return { success = false, reason = "invalid_identifier" } end

    local garageData = Config.FixedGarages[garageId]
    if not garageData then
        return { success = false, reason = "invalid_garage" }
    end

    if not canPlayerAccessGarage(src, garageData) then
        return { success = false, reason = "no_permission" }
    end

    local isImpound = garageData.type == "impound"

    local query = [[
        SELECT pv.*, 
               hsp.coords AS street_coords,
               hsd.deformation, 
               hsd.mechanical_damage, 
               hvn.nickname
        FROM player_vehicles pv
        LEFT JOIN haze_street_parking hsp ON hsp.plate = pv.plate
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate = pv.plate
        LEFT JOIN haze_vehicle_nicknames hvn ON hvn.plate = pv.plate
        WHERE ((pv.citizenid IS NOT NULL AND pv.citizenid = ?)
           OR (pv.license IS NOT NULL AND pv.license = ?))
    ]]

    local rows = MySQL.query.await(query, { citizenid or "NONE", citizenid or "NONE" })
    local vehicles = {}

    for _, row in ipairs(rows or {}) do
        local mods = row.mods and json.decode(row.mods) or {}
        local streetCoords = row.street_coords and json.decode(row.street_coords) or nil

        local statusLabel = "Desconhecido"
        local isSpawnable = false
        local spawnType = "none"

        if isImpound then
            if row.state == 2 then
                statusLabel = "Apreendido no Pátio"
                isSpawnable = true
                spawnType = "impound"
                table.insert(vehicles, {
                    plate = row.plate,
                    model = row.vehicle or row.model or "Desconhecido",
                    nickname = row.nickname or "",
                    state = row.state,
                    garage = row.garage,
                    statusLabel = statusLabel,
                    isSpawnable = isSpawnable,
                    spawnType = spawnType,
                    mods = mods,
                    engine = mods.engineHealth or 1000,
                    body = mods.bodyHealth or 1000,
                    fuel = mods.fuelLevel or 100
                })
            end
        else
            -- Garagem Normal (Pública, Job ou Gang)
            if row.state == 2 then
                statusLabel = "Apreendido (Impound)"
                isSpawnable = false
                spawnType = "impound"
            elseif row.state == 0 then
                statusLabel = "Na Rua / Em Uso"
                isSpawnable = false
                spawnType = "out"
            elseif streetCoords then
                statusLabel = "Estacionado na Rua"
                isSpawnable = false
                spawnType = "street"
            elseif row.state == 1 then
                if row.garage == garageId or garageData.type == "public" or not row.garage then
                    statusLabel = "Guardado nesta Garagem"
                    isSpawnable = true
                    spawnType = "fixed"
                else
                    local otherGarage = Config.FixedGarages[row.garage]
                    statusLabel = "Guardado em: " .. (otherGarage and otherGarage.label or row.garage)
                    isSpawnable = false
                    spawnType = "fixed_other"
                end
            end

            table.insert(vehicles, {
                plate = row.plate,
                model = row.vehicle or row.model or "Desconhecido",
                nickname = row.nickname or "",
                state = row.state,
                garage = row.garage,
                statusLabel = statusLabel,
                isSpawnable = isSpawnable,
                spawnType = spawnType,
                streetCoords = streetCoords,
                mods = mods,
                engine = mods.engineHealth or 1000,
                body = mods.bodyHealth or 1000,
                fuel = mods.fuelLevel or 100
            })
        end
    end

    local isCorporate = (garageData.type == "job" or garageData.type == "gang")
    local currentGrade = 0
    if isCorporate then
        currentGrade = (garageData.type == "job") and Haze.Server.GetPlayerJobGrade(src) or Haze.Server.GetPlayerGangGrade(src)
    end
    local canViewLogs = isCorporate and (currentGrade >= (Config.MinGradeToViewLogs or 2))

    -- Injeta veículos corporativos da frota se for garagem de job ou gang
    if isCorporate and garageData.corporateVehicles and #garageData.corporateVehicles > 0 then
        for i, cVeh in ipairs(garageData.corporateVehicles) do
            local minGrade = CorporateManager and CorporateManager.GetVehicleMinGrade(garageData, cVeh.model) or 0
            local hasGrade = (currentGrade >= minGrade)
            local corpPlate = string.upper(garageData.job or garageData.gang or "CORP") .. "-" .. string.format("%03d", i)

            table.insert(vehicles, {
                plate = corpPlate,
                model = cVeh.model,
                label = cVeh.label or cVeh.model,
                nickname = cVeh.label or "",
                state = 1,
                garage = garageId,
                statusLabel = hasGrade and string.format("Liberado (Patente %d+)", minGrade) or string.format("🔒 Patente Mínima: %d", minGrade),
                isSpawnable = hasGrade,
                spawnType = hasGrade and "fixed" or "locked_grade",
                isCorporate = true,
                minGrade = minGrade,
                mods = {},
                engine = 1000,
                body = 1000,
                fuel = 100
            })
        end
    end

    return { 
        success = true, 
        vehicles = vehicles, 
        isCorporate = isCorporate, 
        canViewLogs = canViewLogs, 
        playerGrade = currentGrade,
        garageLabel = garageData.label 
    }
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

    local isCorporateGarage = (garage.type == "job" or garage.type == "gang")
    local currentGrade = isCorporateGarage and ((garage.type == "job") and Haze.Server.GetPlayerJobGrade(src) or Haze.Server.GetPlayerGangGrade(src)) or 0

    -- 1. Verifica se é um veículo da frota corporativa
    local isCorporateFleet = false
    local corpModel = nil
    local corpLabel = nil
    if isCorporateGarage and garage.corporateVehicles and #garage.corporateVehicles > 0 then
        for i, cVeh in ipairs(garage.corporateVehicles) do
            local expectedPlate = string.upper(garage.job or garage.gang or "CORP") .. "-" .. string.format("%03d", i)
            if Haze.Shared.CleanPlate(expectedPlate) == cleanPlate then
                isCorporateFleet = true
                corpModel = cVeh.model
                corpLabel = cVeh.label or cVeh.model
                local minGrade = CorporateManager and CorporateManager.GetVehicleMinGrade(garage, cVeh.model) or 0
                if currentGrade < minGrade then
                    releaseSpawnReservation(src, cleanPlate)
                    return false, string.format("Patente insuficiente! Esta viatura exige patente mínima %d (sua patente atual: %d).", minGrade, currentGrade)
                end
                break
            end
        end
    end

    if isCorporateFleet then
        -- Remove duplicata física se já existir no mundo
        for _, veh in ipairs(GetAllVehicles()) do
            if DoesEntityExist(veh) then
                local p = GetVehicleNumberPlateText(veh)
                if Haze.Shared.CleanPlate(p) == cleanPlate then
                    DeleteEntity(veh)
                    break
                end
            end
        end

        Haze.Server.GiveKey(src, cleanPlate)
        releaseSpawnReservation(src, cleanPlate)

        -- Grava no Livro de Bordo da corporação
        if CorporateManager then
            CorporateManager.LogAction(garageId, cleanPlate, corpLabel or corpModel, citizenid, Haze.Server.GetPlayerCharName(src), "retirada", 100, 1000, 1000)
        end

        return true, {
            plate = cleanPlate,
            model = corpModel,
            mods = nil,
            deformation = nil,
            mechanical = nil,
            spawnCoords = garage.spawnCoords
        }
    end

    -- 2. Veículo Particular / Normal salvo no banco
    local vehRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
    if not vehRow then
        releaseSpawnReservation(src, cleanPlate)
        return false, Locale.not_vehicle_owner
    end

    -- Se o veículo já estiver fora da garagem (em uso)
    if vehRow.state == 0 then
        releaseSpawnReservation(src, cleanPlate)
        return false, "Este veículo já está fora da garagem (em uso na rua)! Localize-o ou guarde-o antes de retirar novamente."
    end

    -- Se o veículo estiver apreendido e a garagem NÃO for de impound
    if vehRow.state == 2 and garage.type ~= "impound" then
        releaseSpawnReservation(src, cleanPlate)
        return false, "Este veículo está apreendido pela polícia! Dirija-se ao Pátio de Apreensão (Impound)."
    end

    -- Se for garagem de impound, processa liberação e multa
    if garage.type == "impound" then
        local impRow = MySQL.single.await([[
            SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), DATE_ADD(impounded_at, INTERVAL duration_minutes MINUTE)) AS minutes_left
            FROM haze_vehicle_impounds 
            WHERE plate = ?
        ]], { cleanPlate })

        if impRow then
            local minutesLeft = tonumber(impRow.minutes_left) or 0
            if minutesLeft > 0 then
                releaseSpawnReservation(src, cleanPlate)
                return false, string.format("O veículo está cumprindo retenção obrigatória. Faltam %d minutos.", minutesLeft)
            end

            local fine = tonumber(impRow.fine_amount) or 0
            if fine > 0 then
                local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
                if bankBalance < fine then
                    releaseSpawnReservation(src, cleanPlate)
                    return false, string.format("Saldo bancário insuficiente para pagar a multa de apreensão ($%d).", fine)
                end
                Haze.Server.RemovePlayerMoney(src, "bank", fine)
                Haze.Server.Notify(src, string.format("Multa de apreensão de $%d debitada da sua conta bancária.", fine), "success")
            end

            MySQL.query.await("DELETE FROM haze_vehicle_impounds WHERE plate = ?", { cleanPlate })
        end
    end

    -- Remove duplicata física se já existir no mundo
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local p = GetVehicleNumberPlateText(veh)
            if Haze.Shared.CleanPlate(p) == cleanPlate then
                DeleteEntity(veh)
                break
            end
        end
    end

    local defRow = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    MySQL.query("UPDATE player_vehicles SET state = 0, garage = ? WHERE plate = ?", { garageId, cleanPlate })
    Haze.Server.GiveKey(src, cleanPlate)

    -- Se for garagem corporativa, registra no Livro de Bordo
    if isCorporateGarage and CorporateManager then
        CorporateManager.LogAction(garageId, cleanPlate, vehRow.vehicle or vehRow.model, citizenid, Haze.Server.GetPlayerCharName(src), "retirada", 100, 1000, 1000)
    end

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
    if not garageData then return false, "Garagem inválida." end
    if not canPlayerAccessGarage(src, garageData) then
        return false, Locale.no_permission
    end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local isCorporateGarage = (garageData.type == "job" or garageData.type == "gang")

    -- Se for viatura corporativa (não precisa estar no player_vehicles como dono pessoal)
    local isCorporateFleet = false
    if isCorporateGarage and garageData.corporateVehicles and #garageData.corporateVehicles > 0 then
        for i, cVeh in ipairs(garageData.corporateVehicles) do
            local expectedPlate = string.upper(garageData.job or garageData.gang or "CORP") .. "-" .. string.format("%03d", i)
            if Haze.Shared.CleanPlate(expectedPlate) == cleanPlate then
                isCorporateFleet = true
                break
            end
        end
    end

    if not isCorporateFleet then
        local isOwner = MySQL.scalar.await("SELECT 1 FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
        if not isOwner then
            return false, Locale.not_vehicle_owner
        end

        if vehicleProps then
            MySQL.query("UPDATE player_vehicles SET mods = ?, state = 1, garage = ? WHERE plate = ?", { json.encode(vehicleProps), garageId, cleanPlate })
        else
            MySQL.query("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { garageId, cleanPlate })
        end
    end

    MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

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

    -- Registra devolução no Livro de Bordo se for garagem corporativa
    if isCorporateGarage and CorporateManager then
        local f = vehicleProps and vehicleProps.fuelLevel or 100
        local eng = vehicleProps and vehicleProps.engineHealth or 1000
        local bdy = vehicleProps and vehicleProps.bodyHealth or 1000
        CorporateManager.LogAction(garageId, cleanPlate, vehicleProps and (vehicleProps.model or "Viatura") or "Viatura", citizenid, Haze.Server.GetPlayerCharName(src), "devolucao", f, eng, bdy)
    end

    Haze.Server.RemoveKey(src, cleanPlate)
    Haze.Server.Notify(src, string.format("Veículo [%s] guardado na %s com sucesso!", cleanPlate, garageData.label), "success")
    return true, { garageLabel = garageData.label }
end)

RegisterNetEvent("haze_garages:server:ejectPassengers", function(netId)
    if not netId then return end
    TriggerClientEvent("haze_garages:client:forceLeaveVehicle", -1, netId)
end)

lib.callback.register("haze_garages:server:recoverStrandedVehicle", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return { success = false, msg = "Identificador ou placa inválida." } end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local vehRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
    if not vehRow then
        return { success = false, msg = "Veículo não encontrado ou não pertence a você." }
    end

    if vehRow.state ~= 1 then
        return { success = false, msg = "Apenas veículos guardados em garagens podem ser rebocados." }
    end

    local currentGarage = Config.FixedGarages[vehRow.garage]
    if not currentGarage then
        return { success = false, msg = "Garagem do veículo não identificada." }
    end

    if canPlayerAccessGarage(src, currentGarage) then
        return { success = false, msg = "Você ainda possui acesso normal a esta garagem! Vá até ela para retirar seu veículo." }
    end

    local fee = Config.TowRecoveryFee or 500
    local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
    local cashBalance = Haze.Server.GetPlayerMoney(src, "cash")
    local paid = false

    if bankBalance >= fee then
        paid = Haze.Server.RemovePlayerMoney(src, "bank", fee)
    elseif cashBalance >= fee then
        paid = Haze.Server.RemovePlayerMoney(src, "cash", fee)
    end

    if not paid then
        return { success = false, msg = string.format("Saldo insuficiente para pagar o guincho ($%d necessário no banco ou dinheiro).", fee) }
    end

    local targetGarage = Config.DefaultPublicGarage or "legion_square"
    MySQL.query.await("UPDATE player_vehicles SET garage = ? WHERE plate = ?", { targetGarage, cleanPlate })

    local targetGarageLabel = Config.FixedGarages[targetGarage] and Config.FixedGarages[targetGarage].label or "Garagem Central"
    Haze.Server.Notify(src, string.format("Veículo [%s] rebocado com sucesso para a %s! Taxa de guincho de $%d debitada.", cleanPlate, targetGarageLabel, fee), "success")

    return {
        success = true,
        newGarage = targetGarage,
        newGarageLabel = targetGarageLabel,
        coords = Config.FixedGarages[targetGarage] and Config.FixedGarages[targetGarage].coords or nil
    }
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

    local pvRows = MySQL.query.await([[
        SELECT pv.*, 
               hsp.coords AS street_coords,
               hsp.model AS street_model,
               hsd.deformation, 
               hsd.mechanical_damage,
               gvw.wear_data,
               gvw.mileage,
               hvn.nickname
        FROM player_vehicles pv
        LEFT JOIN haze_street_parking hsp ON hsp.plate = pv.plate
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate = pv.plate
        LEFT JOIN granolla_vehicle_wear gvw ON gvw.plate = pv.plate
        LEFT JOIN haze_vehicle_nicknames hvn ON hvn.plate = pv.plate
        WHERE (pv.citizenid IS NOT NULL AND pv.citizenid = ?)
           OR (pv.license IS NOT NULL AND pv.license = ?)
    ]], { citizenid or "NONE", license or "NONE" })

    local vehicles = {}
    for _, row in ipairs(pvRows or {}) do
        local mods = row.mods and json.decode(row.mods) or {}
        local wearData = row.wear_data and json.decode(row.wear_data) or nil
        local streetCoords = row.street_coords and json.decode(row.street_coords) or nil

        local statusLabel = "Fora da Garagem"
        local isSpawnable = false
        local spawnType = "none"

        if streetCoords then
            statusLabel = "Estacionado na Rua"
            isSpawnable = true
            spawnType = "street"
        elseif row.state == 1 then
            local gData = row.garage and Config.FixedGarages[row.garage] or nil
            if gData then
                local hasAccess = canPlayerAccessGarage(src, gData)
                if not hasAccess and (gData.type == "job" or gData.type == "gang") then
                    statusLabel = (gData.label or row.garage) .. " (SEM ACESSO)"
                    isSpawnable = false
                    spawnType = "stranded"
                else
                    statusLabel = gData.label or ("Garagem: " .. row.garage)
                    isSpawnable = false
                    spawnType = "fixed"
                end
            else
                statusLabel = "Guardado em Garagem Fixa"
                isSpawnable = false
                spawnType = "fixed"
            end
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
            nickname = row.nickname,
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

lib.callback.register("haze_garages:server:setNickname", function(source, plate, nickname)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return false, "Identificador ou placa inválida." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local isOwner = MySQL.scalar.await("SELECT 1 FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
    if not isOwner then
        return false, Locale.not_vehicle_owner or "Você não é o proprietário deste veículo."
    end

    local cleanNickname = nickname and string.gsub(tostring(nickname), "^%s*(.-)%s*$", "%1") or ""
    if #cleanNickname > 30 then
        cleanNickname = string.sub(cleanNickname, 1, 30)
    end

    if cleanNickname == "" then
        MySQL.query.await("DELETE FROM haze_vehicle_nicknames WHERE plate = ?", { cleanPlate })
    else
        MySQL.query.await([[
            REPLACE INTO haze_vehicle_nicknames (plate, nickname)
            VALUES (?, ?)
        ]], { cleanPlate, cleanNickname })
    end

    print(string.format("^3[Haze Garages]^7 Apelido do veículo %s atualizado para '%s' (src: %s)", cleanPlate, cleanNickname, src))

    return true, { plate = cleanPlate, nickname = cleanNickname }
end)


lib.callback.register("haze_garages:server:unparkOrSpawnVehicle", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local vehRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
    if not vehRow then
        return false, Locale.not_vehicle_owner
    end

    local streetRow = MySQL.single.await("SELECT * FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    if not streetRow or not streetRow.coords then
        local garageName = vehRow.garage and Config.FixedGarages[vehRow.garage] and Config.FixedGarages[vehRow.garage].label or "Garagem Física"
        return false, string.format("Este veículo está guardado na %s. Use o GPS e vá até a garagem física para retirá-lo.", garageName)
    end

    local spawnCoords = json.decode(streetRow.coords)
    MySQL.query("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

    local defRow = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    MySQL.query("UPDATE player_vehicles SET state = 0 WHERE plate = ?", { cleanPlate })
    Haze.Server.GiveKey(src, cleanPlate)

    return true, {
        plate = cleanPlate,
        model = streetRow.model or vehRow.vehicle or vehRow.model,
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

lib.callback.register("haze_garages:server:dvStoreVehicle", function(source, cleanPlate, coords, props, deformationData, mechanicalData)
    if not cleanPlate or cleanPlate == "" then
        return { success = false, reason = "invalid_plate" }
    end

    local cleanPlate = Haze.Shared.CleanPlate(cleanPlate)
    local pvRow = MySQL.single.await("SELECT plate, citizenid FROM player_vehicles WHERE plate = ?", { cleanPlate })

    if not pvRow then
        return { success = true, isPlayerVehicle = false, plate = cleanPlate }
    end

    local nearestGarageId = Haze.Shared.FindNearestFixedGarage(coords)
    local garageData = Config.FixedGarages[nearestGarageId]
    local garageLabel = garageData and garageData.label or nearestGarageId

    if props then
        MySQL.query.await("UPDATE player_vehicles SET mods = ?, state = 1, garage = ? WHERE plate = ?", { json.encode(props), nearestGarageId, cleanPlate })
    else
        MySQL.query.await("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { nearestGarageId, cleanPlate })
    end

    MySQL.query.await("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

    if deformationData or mechanicalData then
        MySQL.query.await([[
            REPLACE INTO haze_vehicle_deformations (plate, deformation, mechanical_damage)
            VALUES (?, ?, ?)
        ]], {
            cleanPlate,
            deformationData and json.encode(deformationData) or nil,
            mechanicalData and json.encode(mechanicalData) or nil
        })
    end

    Haze.Server.RemoveKey(source, cleanPlate)

    print(string.format("^3[Haze Garages]^7 Veículo %s guardado via DV na garagem mais próxima: %s (%s)", cleanPlate, garageLabel, nearestGarageId))

    return {
        success = true,
        isPlayerVehicle = true,
        garageId = nearestGarageId,
        garageLabel = garageLabel,
        plate = cleanPlate
    }
end)

lib.addCommand({'dv', 'deleteveh'}, {
    help = "Deleta o veículo e envia veículo de jogador para a garagem mais próxima.",
    params = {
        { name = "radius", help = "Raio em metros (opcional, padrão 5m)", type = "number", optional = true }
    },
    restricted = Config.DVCommandRestricted or false
}, function(source, args)
    if source == 0 then
        print("^1[Haze Garages]^7 O comando /dv deve ser executado no jogo.")
        return
    end
    TriggerClientEvent("haze_garages:client:dvCommand", source, args and args.radius)
end)

