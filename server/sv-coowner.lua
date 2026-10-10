-- =================================================================================
-- Haze Garages - Sistema de Coproprietário / Condutor Autorizado (Server-side)
-- Permite cadastrar 1 condutor autorizado por veículo ($1.000) com acesso total
-- mesmo quando o proprietário estiver offline.
-- =================================================================================

CoOwnerManager = CoOwnerManager or {}

--- Retorna se um determinado citizenid é condutor autorizado ou dono da placa
function CoOwnerManager.HasVehicleAccess(cleanPlate, citizenid)
    if not cleanPlate or not citizenid then return false end

    -- 1. Checa propriedade direta no player_vehicles
    local isOwner = MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles 
        WHERE plate = ? AND (citizenid = ? OR license = ?)
    ]], { cleanPlate, citizenid, citizenid })

    if isOwner then return true, "owner" end

    -- 2. Checa vínculo em haze_vehicle_coowners
    local isCoOwner = MySQL.scalar.await([[
        SELECT 1 FROM haze_vehicle_coowners 
        WHERE plate = ? AND coowner_citizenid = ?
    ]], { cleanPlate, citizenid })

    if isCoOwner then return true, "coowner" end

    return false, "none"
end

--- Consulta informações de coproprietário de um veículo
lib.callback.register("haze_garages:server:getVehicleCoOwner", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return { success = false, reason = "Identificador inválido." } end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local isOwner = MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles 
        WHERE plate = ? AND (citizenid = ? OR license = ?)
    ]], { cleanPlate, citizenid, citizenid })

    local coownerRow = MySQL.single.await([[
        SELECT * FROM haze_vehicle_coowners 
        WHERE plate = ?
    ]], { cleanPlate })

    return {
        success = true,
        plate = cleanPlate,
        isOwner = isOwner ~= nil,
        coowner = coownerRow or nil,
        fee = Config.CoOwnerFee or 1000
    }
end)

--- Cadastra um condutor autorizado para o veículo (Custa $1.000)
lib.callback.register("haze_garages:server:setVehicleCoOwner", function(source, plate, targetInput)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)

    -- Validação: Apenas o proprietário legítimo pode cadastrar
    local isOwner = MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles 
        WHERE plate = ? AND (citizenid = ? OR license = ?)
    ]], { cleanPlate, citizenid, citizenid })

    if not isOwner then
        return false, "Apenas o proprietário registrado do veículo pode cadastrar um condutor autorizado."
    end

    -- Validação: Limite estrito de 1 condutor autorizado por veículo
    local existing = MySQL.single.await("SELECT * FROM haze_vehicle_coowners WHERE plate = ?", { cleanPlate })
    if existing then
        return false, string.format("Este veículo já possui um condutor autorizado cadastrado (%s). Remova o atual antes de adicionar um novo.", existing.coowner_name)
    end

    if not targetInput or tostring(targetInput):gsub("%s+", "") == "" then
        return false, "Você precisa informar o ID ou Passaporte do jogador."
    end

    local targetCitizenId = nil
    local targetName = nil
    local targetSrc = tonumber(targetInput)

    -- Se informou o Server ID do jogador (ex: 1, 2, 5)
    if targetSrc and targetSrc > 0 then
        if not GetPlayerPing(targetSrc) or GetPlayerPing(targetSrc) <= 0 then
            return false, "Jogador com este ID não foi encontrado ou está desconectado."
        end

        targetCitizenId = Haze.Server.GetPlayerIdentifier(targetSrc)
        targetName = Haze.Server.GetPlayerCharName(targetSrc)
    else
        -- Se informou o CitizenID diretamente (ex: passaporte ou identificador)
        targetCitizenId = tostring(targetInput):gsub("%s+", "")
        local pRow = MySQL.single.await("SELECT charinfo FROM players WHERE citizenid = ?", { targetCitizenId })
        if pRow and pRow.charinfo then
            local info = json.decode(pRow.charinfo)
            if info and info.firstname then
                targetName = (info.firstname .. " " .. (info.lastname or "")):gsub("^%s*(.-)%s*$", "%1")
            end
        end
        targetName = targetName or ("Cidadão " .. targetCitizenId)
    end

    if not targetCitizenId then
        return false, "Não foi possível identificar o jogador informado."
    end

    if targetCitizenId == citizenid then
        return false, "Você já é o proprietário legítimo deste veículo!"
    end

    -- Cobrança da taxa de serviço de $1.000
    local fee = Config.CoOwnerFee or 1000
    local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
    local cashBalance = Haze.Server.GetPlayerMoney(src, "cash")

    if bankBalance < fee and cashBalance < fee then
        return false, string.format("Saldo insuficiente para pagar a taxa de cadastro do condutor autorizado (%s%s).", Config.Currency or "$", fee)
    end

    local moneyType = (bankBalance >= fee) and "bank" or "cash"
    Haze.Server.RemovePlayerMoney(src, moneyType, fee)

    -- Salva na tabela haze_vehicle_coowners
    MySQL.query.await([[
        INSERT INTO haze_vehicle_coowners (plate, owner_citizenid, coowner_citizenid, coowner_name)
        VALUES (?, ?, ?, ?)
    ]], { cleanPlate, citizenid, targetCitizenId, targetName })

    Haze.Server.Notify(src, string.format(
        Locale.coowner_added_success or "Jogador %s cadastrado com sucesso como condutor autorizado da placa %s! Taxa de %s%s debitada.",
        targetName, cleanPlate, Config.Currency or "$", fee
    ), "success")

    if targetSrc and targetSrc > 0 then
        Haze.Server.Notify(targetSrc, string.format(
            Locale.coowner_received_success or "Você foi autorizado como condutor do veículo placa %s por %s! Agora você pode retirá-lo da garagem a qualquer momento.",
            cleanPlate, Haze.Server.GetPlayerCharName(src)
        ), "info")
    end

    return true, { coownerName = targetName, coownerCitizenId = targetCitizenId }
end)

--- Revoga autorização de condutor de um veículo (Gratuito)
lib.callback.register("haze_garages:server:removeVehicleCoOwner", function(source, plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    local cleanPlate = Haze.Shared.CleanPlate(plate)

    local isOwner = MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles 
        WHERE plate = ? AND (citizenid = ? OR license = ?)
    ]], { cleanPlate, citizenid, citizenid })

    if not isOwner then
        return false, "Apenas o proprietário registrado do veículo pode revogar a autorização de condutores."
    end

    local deleted = MySQL.query.await("DELETE FROM haze_vehicle_coowners WHERE plate = ?", { cleanPlate })
    if deleted and deleted.affectedRows and deleted.affectedRows > 0 then
        Haze.Server.Notify(src, Locale.coowner_removed_success or "Condutor autorizado removido com sucesso.", "success")
        return true, "Condutor autorizado removido com sucesso."
    else
        return false, "Nenhum condutor autorizado estava registrado para este veículo."
    end
end)
