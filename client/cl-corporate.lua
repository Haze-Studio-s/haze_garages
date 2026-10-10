-- =================================================================================
-- Haze Garages - Gestão Avançada para Corporações (Client-side)
-- Responsável pela consulta do Livro de Bordo (Histórico de Uso) e comando in-game.
-- =================================================================================

--- Retorna a garagem corporativa mais próxima do jogador
local function getNearestCorporateGarage(radius)
    local ped = cache.ped or PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local maxDist = radius or 30.0

    local bestId = nil
    local bestGarage = nil
    local minDist = maxDist

    for gId, gData in pairs(Config.FixedGarages or {}) do
        if (gData.type == "job" or gData.type == "gang") and gData.coords then
            local gVec = vec3(gData.coords.x, gData.coords.y, gData.coords.z)
            local dist = #(pCoords - gVec)
            if dist < minDist then
                minDist = dist
                bestId = gId
                bestGarage = gData
            end
        end
    end

    return bestId, bestGarage
end

--- Abre o modal do Livro de Bordo na NUI
local function openCorporateLogsNUI(garageId)
    local res = lib.callback.await("haze_garages:server:getGarageLogs", false, garageId)
    if not res or not res.success then
        Haze.Client.Notify(res and res.reason or "Não foi possível carregar o Livro de Bordo.", "error")
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCorporateLogs",
        garageId = garageId,
        garageLabel = res.garageLabel or "Garagem Corporativa",
        logs = res.logs or {},
        playerGrade = res.playerGrade or 0
    })
end

--- Callback da NUI para carregar os logs de uma garagem
RegisterNUICallback("fetchGarageLogs", function(data, cb)
    if not data or not data.garageId then cb({ success = false }) return end
    local res = lib.callback.await("haze_garages:server:getGarageLogs", false, data.garageId)
    cb(res or { success = false })
end)

--- NUI Callback para fechar o Livro de Bordo
RegisterNUICallback("closeCorporateLogs", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

--- Evento para abrir o livro de bordo a partir da interface principal da garagem
RegisterNetEvent("haze_garages:client:openCorporateLogs", function(garageId)
    openCorporateLogsNUI(garageId)
end)

--- Comando in-game /livrodebordo
RegisterCommand(Config.CorporateLogCommand or "livrodebordo", function(source, args)
    local targetGarageId = args and args[1] or nil
    if not targetGarageId then
        local gId, gData = getNearestCorporateGarage(35.0)
        if gId then
            targetGarageId = gId
        end
    end

    if not targetGarageId then
        Haze.Client.Notify("Você precisa estar próximo a uma garagem corporativa (LSPD/Facção) para consultar o Livro de Bordo.", "error")
        return
    end

    openCorporateLogsNUI(targetGarageId)
end, false)
