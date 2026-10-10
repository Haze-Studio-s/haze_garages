-- =================================================================================
-- Haze Garages - Rastreador GPS Veicular & Jammer de Sinal
-- =================================================================================

--- Instala o rastreador GPS em um veículo
lib.callback.register("haze_garages:server:installTracker", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return false, "Identificador ou placa inválida." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local isOwner = MySQL.scalar.await("SELECT 1 FROM player_vehicles WHERE plate = ? AND (citizenid = ? OR license = ?)", { cleanPlate, citizenid, citizenid })
    if not isOwner then
        return false, "Você só pode instalar um rastreador em veículos de sua propriedade."
    end

    local trackerItem = Config.TrackerItem or "vehicle_tracker"
    local hasItem = exports.ox_inventory:GetItemCount(src, trackerItem)
    if not hasItem or hasItem < 1 then
        return false, "Você precisa de um Rastreador GPS Veicular no inventário."
    end

    exports.ox_inventory:RemoveItem(src, trackerItem, 1)

    MySQL.query.await([[
        REPLACE INTO haze_vehicle_trackers (plate, installed_by)
        VALUES (?, ?)
    ]], { cleanPlate, citizenid })

    print(string.format("^3[Haze Garages]^7 Rastreador GPS instalado no veículo %s por %s", cleanPlate, citizenid))
    return true, { plate = cleanPlate }
end)

--- Instala o Jammer de Sinal para bloquear temporariamente o rastreador
lib.callback.register("haze_garages:server:installJammer", function(source, plate)
    local src = source
    if not plate then return false, "Placa inválida." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local jammerItem = Config.JammerItem or "tracker_jammer"
    local hasItem = exports.ox_inventory:GetItemCount(src, jammerItem)
    if not hasItem or hasItem < 1 then
        return false, "Você precisa de um Jammer de Sinal GPS no inventário."
    end

    local trackerRow = MySQL.single.await("SELECT * FROM haze_vehicle_trackers WHERE plate = ?", { cleanPlate })
    if not trackerRow then
        return false, "Este veículo não possui um rastreador GPS ativo para bloquear."
    end

    exports.ox_inventory:RemoveItem(src, jammerItem, 1)

    local durationMinutes = Config.JammerDurationMinutes or 30
    MySQL.query.await([[
        UPDATE haze_vehicle_trackers 
        SET jammed_until = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE plate = ?
    ]], { durationMinutes, cleanPlate })

    print(string.format("^3[Haze Garages]^7 Jammer instalado no veículo %s. Sinal bloqueado por %d minutos.", cleanPlate, durationMinutes))
    return true, { plate = cleanPlate, duration = durationMinutes }
end)

--- Consulta as coordenadas GPS de um veículo (apenas se tiver rastreador e não estiver bloqueado)
lib.callback.register("haze_garages:server:getVehicleGPS", function(source, plate)
    if not plate then return { ok = false, reason = "invalid_plate" } end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local trackerRow = MySQL.single.await([[
        SELECT *, (jammed_until IS NOT NULL AND jammed_until > NOW()) AS is_jammed 
        FROM haze_vehicle_trackers 
        WHERE plate = ?
    ]], { cleanPlate })

    if not trackerRow then
        return { ok = false, reason = "no_tracker" }
    end

    if trackerRow.is_jammed == 1 then
        return { ok = false, reason = "jammed" }
    end

    -- Procura o veículo rodando no mundo
    local targetCoords = nil
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local p = GetVehicleNumberPlateText(veh)
            if Haze.Shared.CleanPlate(p) == cleanPlate then
                local c = GetEntityCoords(veh)
                targetCoords = { x = c.x, y = c.y, z = c.z }
                break
            end
        end
    end

    -- Se não estiver rodando no mundo, verifica vaga de rua
    if not targetCoords then
        local streetRow = MySQL.single.await("SELECT coords FROM haze_street_parking WHERE plate = ?", { cleanPlate })
        if streetRow and streetRow.coords then
            targetCoords = json.decode(streetRow.coords)
        end
    end

    if not targetCoords then
        return { ok = false, reason = "stored_in_fixed_garage" }
    end

    return {
        ok = true,
        coords = targetCoords,
        plate = cleanPlate,
        hasTracker = true
    }
end)

-- Exports Globais de Rastreador
exports("IsTrackerInstalled", function(plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local row = MySQL.single.await("SELECT 1 FROM haze_vehicle_trackers WHERE plate = ?", { cleanPlate })
    return row ~= nil
end)

exports("IsTrackerJammed", function(plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local row = MySQL.single.await("SELECT (jammed_until IS NOT NULL AND jammed_until > NOW()) AS is_jammed FROM haze_vehicle_trackers WHERE plate = ?", { cleanPlate })
    return row and row.is_jammed == 1
end)

exports("GetVehicleGPS", function(plate)
    if not plate then return false, "invalid_plate" end
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local trackerRow = MySQL.single.await([[
        SELECT *, (jammed_until IS NOT NULL AND jammed_until > NOW()) AS is_jammed 
        FROM haze_vehicle_trackers 
        WHERE plate = ?
    ]], { cleanPlate })

    if not trackerRow then
        return false, "no_tracker"
    end

    if trackerRow.is_jammed == 1 then
        return false, "jammed"
    end

    return true, "ok"
end)

lib.callback.register("haze_garages:server:getPhoneVehicles", function(source)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return {} end

    local pvRows = MySQL.query.await([[
        SELECT pv.*, 
               hsp.coords AS street_coords,
               hsp.model AS street_model,
               hsd.deformation, 
               hsd.mechanical_damage,
               gvw.wear_data,
               gvw.mileage,
               hvn.nickname,
               hvt.installed_by AS tracker_installed_by,
               (hvt.jammed_until IS NOT NULL AND hvt.jammed_until > NOW()) AS is_jammed
        FROM player_vehicles pv
        LEFT JOIN haze_street_parking hsp ON hsp.plate = pv.plate
        LEFT JOIN haze_vehicle_deformations hsd ON hsd.plate = pv.plate
        LEFT JOIN granolla_vehicle_wear gvw ON gvw.plate = pv.plate
        LEFT JOIN haze_vehicle_nicknames hvn ON hvn.plate = pv.plate
        LEFT JOIN haze_vehicle_trackers hvt ON hvt.plate = pv.plate
        WHERE (pv.citizenid IS NOT NULL AND pv.citizenid = ?)
           OR (pv.license IS NOT NULL AND pv.license = ?)
    ]], { citizenid or "NONE", citizenid or "NONE" })

    local vehicles = {}
    for _, row in ipairs(pvRows or {}) do
        local mods = row.mods and json.decode(row.mods) or {}
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
                statusLabel = "Guardado em Garagem"
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
            model = string.upper(row.street_model or row.vehicle or row.model or "VEICULO"),
            nickname = row.nickname or "",
            state = row.state,
            garage = row.garage,
            statusLabel = statusLabel,
            isSpawnable = isSpawnable,
            spawnType = spawnType,
            streetCoords = streetCoords,
            engine = mods.engineHealth or 1000,
            body = mods.bodyHealth or 1000,
            fuel = mods.fuelLevel or 100,
            trackerInstalled = row.tracker_installed_by ~= nil,
            isJammed = row.is_jammed == 1
        })
    end

    return vehicles
end)


