-- =================================================================================
-- Haze Garages - Sistema de Apreensão Policial & Pátio de Impound
-- Multas e tempo de apreensão definidos diretamente pelos policiais ou scripts de polícia.
-- =================================================================================

--- Registra a apreensão de um veículo no banco de dados e atualiza seu estado
--- @param plate string
--- @param fineAmount number|nil
--- @param reason string|nil
--- @param durationMinutes number|nil
--- @param impoundLotId string|nil
--- @param officerName string|nil
local function impoundVehicleInternal(plate, fineAmount, reason, durationMinutes, impoundLotId, officerName)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if not cleanPlate or cleanPlate == "" then return false, "Placa inválida." end

    local pvRow = MySQL.single.await("SELECT * FROM player_vehicles WHERE plate = ?", { cleanPlate })
    if not pvRow then
        return false, "Veículo não cadastrado no sistema."
    end

    fineAmount = tonumber(fineAmount) or 500
    reason = (reason and reason ~= "") and reason or "Apreensão Policial por Infração"
    durationMinutes = tonumber(durationMinutes) or 0
    impoundLotId = impoundLotId or "impound_main"

    -- Deleta registro de estacionamento de rua se houver
    MySQL.query.await("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

    -- Atualiza estado do veículo para 2 (Apreendido)
    MySQL.query.await("UPDATE player_vehicles SET state = 2, garage = ? WHERE plate = ?", { impoundLotId, cleanPlate })

    -- Insere ou atualiza os detalhes da apreensão
    MySQL.query.await([[
        REPLACE INTO haze_vehicle_impounds (plate, reason, fine_amount, duration_minutes, impounded_by, impound_lot)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { cleanPlate, reason, fineAmount, durationMinutes, officerName or "Polícia", impoundLotId })

    -- Se o veículo estiver rodando no mundo, deleta a entidade física
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local p = GetVehicleNumberPlateText(veh)
            if Haze.Shared.CleanPlate(p) == cleanPlate then
                DeleteEntity(veh)
                break
            end
        end
    end

    print(string.format("^3[Haze Garages]^7 Veículo %s APREENDIDO por %s. Multa: $%d | Tempo: %d min | Motivo: %s",
        cleanPlate, officerName or "Polícia", fineAmount, durationMinutes, reason))

    return true, { plate = cleanPlate, fineAmount = fineAmount, durationMinutes = durationMinutes }
end

lib.callback.register("haze_garages:server:impoundVehicle", function(source, plate, fineAmount, reason, durationMinutes, impoundLotId)
    local src = source
    local playerJob = Haze.Server.GetPlayerJob(src)
    local isPolice = false

    local policeJobs = Config.PoliceJobs or { "police", "sheriff" }
    for _, job in ipairs(policeJobs) do
        if playerJob == job then
            isPolice = true
            break
        end
    end

    if not isPolice then
        return false, "Apenas oficiais de polícia podem apreender veículos."
    end

    local officerName = GetPlayerName(src)
    return impoundVehicleInternal(plate, fineAmount, reason, durationMinutes, impoundLotId, officerName)
end)

lib.callback.register("haze_garages:server:getImpoundDetails", function(source, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local row = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), DATE_ADD(impounded_at, INTERVAL duration_minutes MINUTE)) AS minutes_left
        FROM haze_vehicle_impounds 
        WHERE plate = ?
    ]], { cleanPlate })

    if not row then
        return nil
    end

    local minutesLeft = tonumber(row.minutes_left) or 0
    if minutesLeft < 0 then minutesLeft = 0 end

    return {
        plate = cleanPlate,
        reason = row.reason,
        fineAmount = row.fine_amount,
        impoundedAt = row.impounded_at,
        durationMinutes = row.duration_minutes,
        minutesLeft = minutesLeft,
        impoundedBy = row.impounded_by,
        impoundLot = row.impound_lot
    }
end)

lib.callback.register("haze_garages:server:releaseImpoundVehicle", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local impRow = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), DATE_ADD(impounded_at, INTERVAL duration_minutes MINUTE)) AS minutes_left
        FROM haze_vehicle_impounds 
        WHERE plate = ?
    ]], { cleanPlate })

    if not impRow then
        return false, "Este veículo não possui registro de apreensão ativo."
    end

    local minutesLeft = tonumber(impRow.minutes_left) or 0
    if minutesLeft > 0 then
        return false, string.format("O veículo ainda está cumprindo tempo de apreensão. Faltam %d minutos.", minutesLeft)
    end

    local fineAmount = impRow.fine_amount or 500
    local playerMoney = Haze.Server.GetPlayerMoney(src, "bank")
    if playerMoney < fineAmount then
        return false, string.format("Saldo bancário insuficiente para pagar a multa de apreensão (%s).", Haze.Shared.FormatMoney(fineAmount))
    end

    -- Debita a multa bancária
    Haze.Server.RemovePlayerMoney(src, "bank", fineAmount)

    -- Atualiza estado do veículo para 1 (Guardado em garagem)
    local defaultGarage = impRow.impound_lot or "legion_square"
    MySQL.query.await("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { defaultGarage, cleanPlate })

    -- Deleta o registro de apreensão
    MySQL.query.await("DELETE FROM haze_vehicle_impounds WHERE plate = ?", { cleanPlate })

    Haze.Server.Notify(src, string.format("Multa de apreensão de %s paga com sucesso! Veículo liberado na garagem.", Haze.Shared.FormatMoney(fineAmount)), "success")

    return true, { plate = cleanPlate, finePaid = fineAmount, garage = defaultGarage }
end)

-- Exportação global para scripts policiais externos
exports("ImpoundVehicle", function(plate, fineAmount, reason, durationMinutes, impoundLotId, officerName)
    return impoundVehicleInternal(plate, fineAmount, reason, durationMinutes, impoundLotId, officerName)
end)

lib.addCommand({'apreender', 'impoundveh'}, {
    help = "Apreender veículo e enviar para o Pátio de Apreensão (Polícia)",
    params = {
        { name = "plate", help = "Placa do veículo", type = "string" },
        { name = "fine", help = "Valor da multa em $ (opcional, padrão $500)", type = "number", optional = true },
        { name = "duration", help = "Tempo de retenção em minutos (opcional, padrão 0)", type = "number", optional = true },
        { name = "reason", help = "Motivo da infração", type = "string", optional = true }
    },
    restricted = Config.PoliceJobs or { "police", "sheriff" }
}, function(source, args)
    if not args or not args.plate then
        Haze.Server.Notify(source, "Informe a placa do veículo a ser apreendido.", "error")
        return
    end

    local officerName = Haze.Server.GetPlayerFullName(source)
    local success, res = impoundVehicleInternal(args.plate, args.fine, args.reason, args.duration, "impound_main", officerName)
    if success then
        Haze.Server.Notify(source, string.format("Veículo [%s] apreendido com sucesso! Multa: $%d", res.plate, res.fineAmount), "success")
    else
        Haze.Server.Notify(source, res or "Erro ao apreender veículo.", "error")
    end
end)

