-- =================================================================================
-- Haze Garages - Sistema de Manobrista NPC Valet (Server-side)
-- Responsável pela validação autoritativa, cobrança, seleção de garagem e sincronização.
-- =================================================================================

local activeValets = {}

--- Retorna a garagem pública mais próxima de uma coordenada fornecida
local function getNearestPublicGarage(coords)
    local bestId = nil
    local bestGarage = nil
    local minDistance = 99999999.0

    local targetVec = vec3(coords.x, coords.y, coords.z)

    for gId, gData in pairs(Config.FixedGarages or {}) do
        local isCarCategory = (not gData.category or gData.category == "car")
        if (gData.type == "public" or not gData.type) and isCarCategory and gData.coords and gData.spawnCoords and #gData.spawnCoords > 0 then
            local gCoords = vec3(gData.coords.x, gData.coords.y, gData.coords.z)
            local dist = #(targetVec - gCoords)
            if dist < minDistance then
                minDistance = dist
                bestId = gId
                bestGarage = gData
            end
        end
    end

    -- Fallback se nenhuma garagem pública for encontrada
    if not bestGarage then
        bestId = Config.DefaultPublicGarage or "legion_square"
        bestGarage = Config.FixedGarages and Config.FixedGarages[bestId]
    end

    return bestId, bestGarage
end

--- Retorna veículos elegíveis para Valet do jogador (guardados com state = 1)
lib.callback.register("haze_garages:server:getValetVehicles", function(source)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return {} end

    local query = [[
        SELECT pv.plate, pv.vehicle, pv.model, pv.garage, pv.state, pv.mods,
               hvn.nickname
        FROM player_vehicles pv
        LEFT JOIN haze_vehicle_nicknames hvn ON hvn.plate = pv.plate
        WHERE ((pv.citizenid IS NOT NULL AND pv.citizenid = ?)
           OR (pv.license IS NOT NULL AND pv.license = ?))
          AND pv.state = 1
    ]]

    local rows = MySQL.query.await(query, { citizenid, citizenid })
    local list = {}

    for _, row in ipairs(rows or {}) do
        local gData = Config.FixedGarages[row.garage]
        local gLabel = gData and gData.label or row.garage or "Garagem"
        table.insert(list, {
            plate = row.plate,
            model = row.vehicle or row.model or "Desconhecido",
            nickname = row.nickname or "",
            garage = row.garage,
            garageLabel = gLabel
        })
    end

    return list
end)

--- Callback para solicitar o manobrista Valet
lib.callback.register("haze_garages:server:requestValet", function(source, plate, playerCoords)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return false, "Identificador inválido." end

    if not playerCoords or not playerCoords.x then
        return false, "Coordenadas do jogador inválidas."
    end

    -- Validação de Valet ativo para o jogador
    if activeValets[citizenid] then
        local current = activeValets[citizenid]
        if os.time() - current.startTime < (Config.ValetTimeoutSeconds or 180) then
            return false, Locale.valet_already_active or "Você já possui um manobrista a caminho!"
        else
            activeValets[citizenid] = nil
        end
    end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if not cleanPlate or cleanPlate == "" then
        return false, "Placa inválida."
    end

    local vehRow = MySQL.single.await([[
        SELECT * FROM player_vehicles 
        WHERE plate = ? AND (citizenid = ? OR license = ?)
    ]], { cleanPlate, citizenid, citizenid })

    if not vehRow then
        return false, Locale.not_vehicle_owner or "Você não possui os documentos deste veículo."
    end

    -- Validações do estado do veículo
    if vehRow.state == 0 then
        return false, Locale.valet_outside_error or "Este veículo já está fora da garagem (em uso na rua)! Não é possível chamar o manobrista."
    elseif vehRow.state == 2 then
        return false, Locale.valet_impounded_error or "Este veículo está apreendido pela polícia no Pátio (Impound)!"
    elseif vehRow.state == 3 then
        return false, "Este veículo está sinistrado na Seguradora!"
    elseif vehRow.state ~= 1 then
        return false, Locale.valet_not_stored_error or "O veículo precisa estar guardado em uma garagem para ser entregue pelo manobrista."
    end

    -- Cobrança da taxa do Valet
    local fee = Config.ValetPrice or 150
    local bankBalance = Haze.Server.GetPlayerMoney(src, "bank")
    local cashBalance = Haze.Server.GetPlayerMoney(src, "cash")

    if bankBalance < fee and cashBalance < fee then
        return false, string.format(Locale.valet_no_money or "Saldo insuficiente para pagar o manobrista (%s%s).", Config.Currency or "$", fee)
    end

    local moneyType = (bankBalance >= fee) and "bank" or "cash"
    Haze.Server.RemovePlayerMoney(src, moneyType, fee)

    -- Localiza a garagem pública mais próxima para o manobrista sair
    local nearestGarageId, nearestGarage = getNearestPublicGarage(playerCoords)
    if not nearestGarage or not nearestGarage.spawnCoords or #nearestGarage.spawnCoords == 0 then
        Haze.Server.AddPlayerMoney(src, moneyType, fee)
        return false, "Nenhuma garagem pública disponível próxima para despacho do veículo."
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

    -- Atualiza estado do veículo no banco de dados para 0 (em uso na rua)
    MySQL.query("UPDATE player_vehicles SET state = 0, garage = ? WHERE plate = ?", { nearestGarageId, cleanPlate })

    -- Entrega as chaves do veículo ao proprietário
    Haze.Server.GiveKey(src, cleanPlate)

    local defRow = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })

    -- Registra o Valet ativo
    activeValets[citizenid] = {
        plate = cleanPlate,
        src = src,
        garageId = nearestGarageId,
        startTime = os.time()
    }

    return true, {
        plate = cleanPlate,
        model = vehRow.vehicle or vehRow.model,
        mods = vehRow.mods and json.decode(vehRow.mods) or nil,
        deformation = defRow and defRow.deformation and json.decode(defRow.deformation) or nil,
        mechanical = defRow and defRow.mechanical_damage and json.decode(defRow.mechanical_damage) or nil,
        spawnCoords = nearestGarage.spawnCoords,
        garageId = nearestGarageId,
        garageLabel = nearestGarage.label or "Garagem Pública",
        fee = fee
    }
end)

--- Finalização de entrega do Valet com sucesso
RegisterNetEvent("haze_garages:server:valetFinished", function(plate)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if citizenid and activeValets[citizenid] then
        activeValets[citizenid] = nil
    end
end)

--- Cancelamento ou aborto do Valet (recolhe de volta para a garagem se solicitado)
RegisterNetEvent("haze_garages:server:valetCancelled", function(plate, returnToGarage)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if citizenid and activeValets[citizenid] then
        local gId = activeValets[citizenid].garageId or Config.DefaultPublicGarage or "legion_square"
        activeValets[citizenid] = nil

        if returnToGarage and plate then
            local cleanPlate = Haze.Shared.CleanPlate(plate)
            MySQL.query("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { gId, cleanPlate })
        end
    end
end)

--- Limpeza se o jogador desconectar com Valet a caminho
AddEventHandler("playerDropped", function()
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if citizenid and activeValets[citizenid] then
        local val = activeValets[citizenid]
        if val.plate then
            local cleanPlate = Haze.Shared.CleanPlate(val.plate)
            MySQL.query("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { val.garageId or "legion_square", cleanPlate })
        end
        activeValets[citizenid] = nil
    end
end)
