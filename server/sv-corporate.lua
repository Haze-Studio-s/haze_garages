-- =================================================================================
-- Haze Garages - Gestão Avançada para Corporações (Server-side)
-- Responsável pelo Livro de Bordo (Registro de Histórico de Uso),
-- Auditoria de Avarias/Combustível e Restrição por Patente Mínima (minGrade).
-- =================================================================================

CorporateManager = CorporateManager or {}

--- Retorna a patente mínima requerida para retirar determinado modelo
function CorporateManager.GetVehicleMinGrade(garageData, modelName)
    if not garageData or not modelName then return 0 end
    local cleanModel = string.lower(modelName)

    -- 1. Verifica na frota customizada cadastrada diretamente na garagem (data/garages.json)
    if garageData.corporateVehicles and type(garageData.corporateVehicles) == "table" then
        for _, v in ipairs(garageData.corporateVehicles) do
            if string.lower(v.model) == cleanModel then
                return tonumber(v.minGrade) or 0
            end
        end
    end

    -- 2. Verifica no mapeamento global de jobs/gangues do config.lua
    local orgKey = garageData.job or garageData.gang
    if orgKey and Config.CorporateMinGrades and Config.CorporateMinGrades[orgKey] then
        local mg = Config.CorporateMinGrades[orgKey][cleanModel]
        if mg ~= nil then
            return tonumber(mg) or 0
        end
    end

    return 0
end

--- Insere um registro no Livro de Bordo da Corporação
function CorporateManager.LogAction(garageId, plate, model, citizenid, playerName, action, fuel, engineHealth, bodyHealth)
    if not Config.LogCorporateGarages then return end
    if not garageId or not plate then return end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local f = tonumber(fuel) or 100.0
    local eng = tonumber(engineHealth) or 1000.0
    local bdy = tonumber(bodyHealth) or 1000.0

    MySQL.query([[
        INSERT INTO haze_garage_logs 
        (garage_id, plate, model, citizenid, player_name, action, fuel, engine_health, body_health)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        garageId,
        cleanPlate,
        model or "Desconhecido",
        citizenid or "NONE",
        playerName or "Desconhecido",
        action or "retirada",
        f,
        eng,
        bdy
    })
end

--- Callback para consultar os registros de bordo da garagem corporativa
lib.callback.register("haze_garages:server:getGarageLogs", function(source, garageId)
    local src = source
    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    if not citizenid then return { success = false, reason = "Identificador inválido." } end

    local garageData = Config.FixedGarages[garageId]
    if not garageData then
        return { success = false, reason = "Garagem não encontrada." }
    end

    if garageData.type ~= "job" and garageData.type ~= "gang" then
        return { success = false, reason = "Esta garagem não possui Livro de Bordo corporativo." }
    end

    -- Validação de pertencimento à organização
    local playerOrgGrade = 0
    if garageData.type == "job" then
        local playerJob = Haze.Server.GetPlayerJob(src)
        if playerJob ~= garageData.job then
            return { success = false, reason = "Você não pertence a esta corporação." }
        end
        playerOrgGrade = Haze.Server.GetPlayerJobGrade(src)
    elseif garageData.type == "gang" then
        local playerGang = Haze.Server.GetPlayerGang(src)
        if playerGang ~= garageData.gang then
            return { success = false, reason = "Você não pertence a esta facção." }
        end
        playerOrgGrade = Haze.Server.GetPlayerGangGrade(src)
    end

    -- Validação de patente mínima para auditoria dos logs
    local requiredGrade = Config.MinGradeToViewLogs or 2
    if playerOrgGrade < requiredGrade then
        return { 
            success = false, 
            reason = string.format("Apenas superiores a partir da patente %d podem consultar o Livro de Bordo. Sua patente atual: %d.", requiredGrade, playerOrgGrade) 
        }
    end

    local query = [[
        SELECT id, garage_id, plate, model, citizenid, player_name, action, fuel, engine_health, body_health,
               DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') as formatted_date
        FROM haze_garage_logs
        WHERE garage_id = ?
        ORDER BY created_at DESC
        LIMIT 60
    ]]

    local rows = MySQL.query.await(query, { garageId })

    return {
        success = true,
        logs = rows or {},
        garageLabel = garageData.label or "Garagem Corporativa",
        playerGrade = playerOrgGrade
    }
end)
