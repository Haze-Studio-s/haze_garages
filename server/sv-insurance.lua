-- =================================================================================
-- Haze Garages - Seguradora de Veículos Mors Mutual (Server-side)
-- Gestão de sinistros, franquia de seguro, carência de reparo e liberação expressa.
-- =================================================================================

InsuranceManager = InsuranceManager or {}

--- Declara um veículo como destruído / sinistrado
function InsuranceManager.ReportDestroyedVehicle(cleanPlate)
    if not cleanPlate then return false end

    -- 1. Remove qualquer vaga de rua pendente
    MySQL.query.await("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

    -- 2. Limpa deformações para quando o seguro for acionado receber lataria nova
    MySQL.query.await("DELETE FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    -- 3. Atualiza estado para 3 (Sinistrado) e transfere para a seguradora
    local targetGarage = Config.Insurance.LotGarageId or "mors_mutual"
    MySQL.query.await([[
        UPDATE player_vehicles 
        SET state = 3, garage = ? 
        WHERE plate = ?
    ]], { targetGarage, cleanPlate })

    -- 4. Insere ou atualiza na tabela de seguros
    local deductible = Config.Insurance.BaseDeductible or 2500
    MySQL.query.await([[
        INSERT INTO haze_vehicle_insurance (plate, deductible_fee, status)
        VALUES (?, ?, 'destroyed')
        ON DUPLICATE KEY UPDATE 
            deductible_fee = VALUES(deductible_fee),
            status = 'destroyed',
            claimed_at = NULL,
            ready_at = NULL
    ]], { cleanPlate, deductible })

    print(string.format("^3[Haze Garages]^7 Sinistro registrado para o veículo placa [%s] na Seguradora Mors Mutual.", cleanPlate))
    return true
end

--- Evento client-side para notificar destruição de veículo do jogador
RegisterNetEvent("haze_garages:server:reportDestroyedVehicle", function(plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return end

    local cleanPlate = Haze.Shared.CleanPlate(plate)

    -- Validação: Confirma se o veículo é do jogador ou coproprietário
    local hasAccess = MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles pv
        LEFT JOIN haze_vehicle_coowners hco ON hco.plate = pv.plate
        WHERE pv.plate = ? AND (
            (pv.citizenid IS NOT NULL AND pv.citizenid = ?)
         OR (pv.license IS NOT NULL AND pv.license = ?)
         OR (hco.coowner_citizenid IS NOT NULL AND hco.coowner_citizenid = ?)
        )
    ]], { cleanPlate, citizenid, citizenid, citizenid })

    if not hasAccess then return end

    InsuranceManager.ReportDestroyedVehicle(cleanPlate)

    Haze.Server.Notify(src, string.format(
        Locale.insurance_destroyed_alert or "Seu veículo [%s] sofreu perda total! Uma ocorrência de sinistro foi aberta na Seguradora Mors Mutual.",
        cleanPlate
    ), "error")
end)

--- Retorna lista de veículos sinistrados do jogador
lib.callback.register("haze_garages:server:getInsuranceVehicles", function(source)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return {} end

    local query = [[
        SELECT pv.plate, pv.vehicle, pv.model, pv.garage, pv.state, pv.mods,
               hvn.nickname,
               hvi.deductible_fee, hvi.claimed_at, hvi.ready_at, hvi.status,
               TIMESTAMPDIFF(MINUTE, NOW(), hvi.ready_at) AS minutes_left,
               hco.coowner_citizenid
        FROM player_vehicles pv
        LEFT JOIN haze_vehicle_insurance hvi ON hvi.plate = pv.plate
        LEFT JOIN haze_vehicle_nicknames hvn ON hvn.plate = pv.plate
        LEFT JOIN haze_vehicle_coowners hco ON hco.plate = pv.plate
        WHERE ((pv.citizenid IS NOT NULL AND pv.citizenid = ?)
           OR (pv.license IS NOT NULL AND pv.license = ?)
           OR (hco.coowner_citizenid IS NOT NULL AND hco.coowner_citizenid = ?))
          AND pv.state = 3
    ]]

    local rows = MySQL.query.await(query, { citizenid, citizenid, citizenid })
    local list = {}

    for _, row in ipairs(rows or {}) do
        local rawStatus = row.status or "destroyed"
        local minutesLeft = tonumber(row.minutes_left) or 0
        local actualStatus = rawStatus

        if rawStatus == "pending" then
            if minutesLeft <= 0 then
                actualStatus = "ready"
                -- Atualiza status no banco para pronto
                MySQL.query("UPDATE haze_vehicle_insurance SET status = 'ready' WHERE plate = ?", { row.plate })
            end
        end

        table.insert(list, {
            plate = row.plate,
            model = row.vehicle or row.model or "Desconhecido",
            nickname = row.nickname or "",
            deductible = row.deductible_fee or (Config.Insurance.BaseDeductible or 2500),
            expressFee = Config.Insurance.ExpressFee or 1000,
            status = actualStatus,
            minutesLeft = math.max(0, minutesLeft),
            isCoOwner = (row.coowner_citizenid ~= nil and row.coowner_citizenid == citizenid)
        })
    end

    return list
end)

--- Acionamento da apólice de seguro (Regular com 15 min ou Expresso Imediato)
lib.callback.register("haze_garages:server:claimInsurance", function(source, plate, isExpress)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return false, "Identificador ou placa inválida." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)

    local row = MySQL.single.await([[
        SELECT pv.plate, pv.state, hvi.status, hvi.deductible_fee,
               TIMESTAMPDIFF(MINUTE, NOW(), hvi.ready_at) AS minutes_left
        FROM player_vehicles pv
        LEFT JOIN haze_vehicle_insurance hvi ON hvi.plate = pv.plate
        LEFT JOIN haze_vehicle_coowners hco ON hco.plate = pv.plate
        WHERE pv.plate = ? AND (
            (pv.citizenid IS NOT NULL AND pv.citizenid = ?)
         OR (pv.license IS NOT NULL AND pv.license = ?)
         OR (hco.coowner_citizenid IS NOT NULL AND hco.coowner_citizenid = ?)
        )
    ]], { cleanPlate, citizenid, citizenid, citizenid })

    if not row or row.state ~= 3 then
        return false, "Este veículo não possui registro de sinistro na Seguradora Mors Mutual."
    end

    local status = row.status or "destroyed"
    local minutesLeft = tonumber(row.minutes_left) or 0
    local baseDeductible = row.deductible_fee or (Config.Insurance.BaseDeductible or 2500)
    local expressFee = Config.Insurance.ExpressFee or 1000
    local waitMinutes = Config.Insurance.ClaimWaitMinutes or 15

    -- Se já estiver pronto
    if status == "ready" or (status == "pending" and minutesLeft <= 0) then
        return false, "Seu veículo já foi reparado e está disponível para retirada no pátio da Mors Mutual!"
    end

    -- Se já estiver pendente e o jogador quer pagar o guincho expresso para liberar agora
    if status == "pending" then
        if not isExpress then
            return false, string.format("O reparo do veículo já está em andamento. Faltam %d minutos.", minutesLeft)
        end

        local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
        local cashBalance = Haze.Server.GetPlayerMoney(src, "cash")
        if bankBalance < expressFee and cashBalance < expressFee then
            return false, string.format("Saldo insuficiente para pagar o Guincho Expresso (%s%s).", Config.Currency or "$", expressFee)
        end

        local moneyType = (bankBalance >= expressFee) and "bank" or "cash"
        Haze.Server.RemovePlayerMoney(src, moneyType, expressFee)

        MySQL.query.await([[
            UPDATE haze_vehicle_insurance 
            SET status = 'ready', ready_at = NOW() 
            WHERE plate = ?
        ]], { cleanPlate })

        Haze.Server.Notify(src, string.format(
            Locale.insurance_express_ready or "Guincho Expresso acionado com sucesso (%s%s)! Seu veículo [%s] está liberado para retirada.",
            Config.Currency or "$", expressFee, cleanPlate
        ), "success")

        return true, { status = "ready", minutesLeft = 0 }
    end

    -- Primeiro acionamento (status == 'destroyed')
    local totalFee = baseDeductible
    if isExpress then
        totalFee = baseDeductible + expressFee
    end

    local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
    local cashBalance = Haze.Server.GetPlayerMoney(src, "cash")
    if bankBalance < totalFee and cashBalance < totalFee then
        return false, string.format("Saldo insuficiente para pagar a franquia do seguro (%s%s).", Config.Currency or "$", totalFee)
    end

    local moneyType = (bankBalance >= totalFee) and "bank" or "cash"
    Haze.Server.RemovePlayerMoney(src, moneyType, totalFee)

    if isExpress then
        MySQL.query.await([[
            INSERT INTO haze_vehicle_insurance (plate, deductible_fee, claimed_at, ready_at, status)
            VALUES (?, ?, NOW(), NOW(), 'ready')
            ON DUPLICATE KEY UPDATE
                deductible_fee = VALUES(deductible_fee),
                claimed_at = NOW(),
                ready_at = NOW(),
                status = 'ready'
        ]], { cleanPlate, baseDeductible })

        Haze.Server.Notify(src, string.format(
            Locale.insurance_claimed_express or "Franquia e Guincho Expresso pagos (%s%s)! O veículo [%s] foi restaurado e está pronto para retirada.",
            Config.Currency or "$", totalFee, cleanPlate
        ), "success")

        return true, { status = "ready", minutesLeft = 0 }
    else
        MySQL.query.await([[
            INSERT INTO haze_vehicle_insurance (plate, deductible_fee, claimed_at, ready_at, status)
            VALUES (?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? MINUTE), 'pending')
            ON DUPLICATE KEY UPDATE
                deductible_fee = VALUES(deductible_fee),
                claimed_at = NOW(),
                ready_at = DATE_ADD(NOW(), INTERVAL ? MINUTE),
                status = 'pending'
        ]], { cleanPlate, baseDeductible, waitMinutes, waitMinutes })

        Haze.Server.Notify(src, string.format(
            Locale.insurance_claimed_pending or "Franquia de %s%s paga com sucesso! Seu veículo [%s] está em reparo pela Seguradora (Carência: %d minutos).",
            Config.Currency or "$", totalFee, cleanPlate, waitMinutes
        ), "info")

        return true, { status = "pending", minutesLeft = waitMinutes }
    end
end)

--- Liberação / Retirada do veículo restaurado da Seguradora
lib.callback.register("haze_garages:server:retrieveInsuranceVehicle", function(source, plate, garageId)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid or not plate then return false, "Identificador ou placa inválida." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local targetGarageId = garageId or Config.Insurance.LotGarageId or "mors_mutual"

    local row = MySQL.single.await([[
        SELECT pv.plate, pv.state, pv.mods, pv.vehicle, pv.model,
               hvi.status, TIMESTAMPDIFF(MINUTE, NOW(), hvi.ready_at) AS minutes_left
        FROM player_vehicles pv
        LEFT JOIN haze_vehicle_insurance hvi ON hvi.plate = pv.plate
        LEFT JOIN haze_vehicle_coowners hco ON hco.plate = pv.plate
        WHERE pv.plate = ? AND (
            (pv.citizenid IS NOT NULL AND pv.citizenid = ?)
         OR (pv.license IS NOT NULL AND pv.license = ?)
         OR (hco.coowner_citizenid IS NOT NULL AND hco.coowner_citizenid = ?)
        )
    ]], { cleanPlate, citizenid, citizenid, citizenid })

    if not row or row.state ~= 3 then
        return false, "Este veículo não está no pátio da Seguradora Mors Mutual."
    end

    local minutesLeft = tonumber(row.minutes_left) or 0
    if row.status ~= "ready" and minutesLeft > 0 then
        return false, string.format("O veículo ainda está em reparo pela seguradora. Faltam %d minutos.", minutesLeft)
    end

    -- Restaura mods com motor e lataria perfeitos
    local mods = row.mods and json.decode(row.mods) or {}
    mods.engineHealth = 1000.0
    mods.bodyHealth = 1000.0
    mods.fuelLevel = 100.0

    -- Transfere para a garagem com state = 1 (Guardado)
    MySQL.query.await([[
        UPDATE player_vehicles 
        SET state = 1, garage = ?, mods = ? 
        WHERE plate = ?
    ]], { targetGarageId, json.encode(mods), cleanPlate })

    -- Remove registro da seguradora
    MySQL.query.await("DELETE FROM haze_vehicle_insurance WHERE plate = ?", { cleanPlate })

    -- Limpa deformações antigas
    MySQL.query.await("DELETE FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    local gData = Config.FixedGarages[targetGarageId]
    local gLabel = gData and gData.label or "Garagem"

    Haze.Server.Notify(src, string.format(
        Locale.insurance_vehicle_retrieved or "Veículo [%s] restaurado com sucesso! Ele foi transferido para a %s.",
        cleanPlate, gLabel
    ), "success")

    return true, {
        plate = cleanPlate,
        garageId = targetGarageId,
        garageLabel = gLabel
    }
end)
