-- =================================================================================
-- Haze Garages - Auto-Store Vehicles on Resource Stop / Server Restart
-- Guardar automaticamente todos os veículos em uso na garagem PÚBLICA mais próxima,
-- ignorando garagens de empresa (job), gangues ou pátios de apreensão (impound).
-- =================================================================================

--- Retorna o ID da garagem FIXA PÚBLICA mais próxima por distância 3D
--- @param coords vector3|table
--- @return string
local function findNearestPublicGarage(coords)
    local nearestId = "legion_square"
    local minDistance = 999999.0

    if not coords then return nearestId end
    local cX = coords.x or (coords[1] or 0)
    local cY = coords.y or (coords[2] or 0)
    local cZ = coords.z or (coords[3] or 0)
    local vecCoords = vec3(cX, cY, cZ)

    for garageId, gData in pairs(Config.FixedGarages or {}) do
        -- Ignora garagens corporativas (job), de gangues (gang) e pátios de apreensão (impound)
        local gType = gData.type or "public"
        local gCategory = gData.category or "car"

        if gType == "public" and (gCategory == "car" or gCategory == "all") then
            local gCoords = vec3(gData.coords.x, gData.coords.y, gData.coords.z)
            local dist = #(vecCoords - gCoords)
            if dist < minDistance then
                minDistance = dist
                nearestId = garageId
            end
        end
    end

    return nearestId
end

--- Executa a rotina de auto-salvamento e guarda de veículos em uso
local function autoStoreAllActiveVehicles()
    local allVehicles = GetAllVehicles()
    if not allVehicles or #allVehicles == 0 then return end

    local storedCount = 0

    for _, veh in ipairs(allVehicles) do
        if DoesEntityExist(veh) then
            local rawPlate = GetVehicleNumberPlateText(veh)
            local cleanPlate = Haze.Shared.CleanPlate(rawPlate)

            if cleanPlate and cleanPlate ~= "" then
                local pvRow = MySQL.single.await("SELECT plate, citizenid FROM player_vehicles WHERE plate = ?", { cleanPlate })

                if pvRow then
                    local coords = GetEntityCoords(veh)
                    local nearestPublicGarage = findNearestPublicGarage(coords)

                    -- Deleta entrada de vaga de rua se houver
                    MySQL.query.await("DELETE FROM haze_street_parking WHERE plate = ?", { cleanPlate })

                    -- Atualiza o estado para guardado na garagem pública mais próxima
                    MySQL.query.await("UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?", { nearestPublicGarage, cleanPlate })

                    -- Deleta a entidade do mundo
                    DeleteEntity(veh)
                    storedCount = storedCount + 1
                end
            end
        end
    end

    if storedCount > 0 then
        print(string.format("^2[Haze Garages]^7 Auto-salvamento pós-restart concluído: %d veículo(s) de jogador guardado(s) na garagem pública mais próxima.", storedCount))
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    autoStoreAllActiveVehicles()
end)

RegisterNetEvent("txAdmin:events:serverStopping", function()
    autoStoreAllActiveVehicles()
end)
