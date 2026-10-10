-- =================================================================================
-- Haze Garages - Backend do Criador e Gerenciador de Garagens In-Game
-- Validações estritas de segurança, gravação em data/garages.json e hot-reload
-- =================================================================================

local function sanitizeId(str)
    if not str then return nil end
    local s = string.lower(tostring(str)):gsub("%s+", "_"):gsub("%-", "_"):gsub("[^%w_]", "")
    return s ~= "" and s or nil
end

local function validateCoords(c, requireHeading)
    if not c or type(c) ~= "table" then return false end
    local x = tonumber(c.x or c[1])
    local y = tonumber(c.y or c[2])
    local z = tonumber(c.z or c[3])
    if not x or not y or not z then return false end
    if requireHeading then
        local w = tonumber(c.w or c.h or c[4])
        if not w then return false end
    end
    return true
end

--- Salva uma nova garagem ou atualiza uma existente diretamente no arquivo data/garages.json
lib.callback.register("haze_garages:server:saveGarage", function(source, garagePayload)
    local src = source
    if not Haze.Server.IsAdmin(src) then
        print(string.format("^1[Haze Garages] ALERTA DE SEGURANÇA: Jogador %s (ID: %d) tentou salvar garagem sem permissão de admin!^7", GetPlayerName(src), src))
        return { success = false, msg = "Você não possui permissão administrativa para criar ou editar garagens." }
    end

    if not garagePayload or type(garagePayload) ~= "table" then
        return { success = false, msg = "Dados da garagem inválidos ou ausentes." }
    end

    local rawId = garagePayload.id or garagePayload.slug
    local cleanId = sanitizeId(rawId)
    if not cleanId or #cleanId < 2 then
        return { success = false, msg = "O ID da garagem é inválido. Use letras e números sem caracteres especiais." }
    end

    local label = tostring(garagePayload.label or ""):gsub("^%s*(.-)%s*$", "%1")
    if label == "" then
        return { success = false, msg = "O nome de exibição (label) da garagem é obrigatório." }
    end

    local gType = garagePayload.type or "public"
    local validTypes = { public = true, job = true, gang = true, impound = true }
    if not validTypes[gType] then
        return { success = false, msg = "Tipo de garagem inválido (permitidos: public, job, gang, impound)." }
    end

    if not validateCoords(garagePayload.coords, true) then
        return { success = false, msg = "Coordenadas do atendente NPC (coords com heading) inválidas." }
    end

    -- Validação da DropZone (4 Pontos poligonais)
    local dz = garagePayload.dropZone
    if not dz or type(dz) ~= "table" then
        return { success = false, msg = "A zona de devolução (dropZone) é obrigatória." }
    end

    if not dz.points or #dz.points < 3 then
        return { success = false, msg = "A zona de devolução precisa conter pelo menos 3 ou 4 pontos demarcados." }
    end

    for idx, pt in ipairs(dz.points) do
        if not validateCoords(pt, false) then
            return { success = false, msg = string.format("O ponto %d da zona de devolução possui coordenadas inválidas.", idx) }
        end
    end

    -- Validação das vagas de spawn
    local spawns = garagePayload.spawnCoords
    if not spawns or type(spawns) ~= "table" or #spawns == 0 then
        return { success = false, msg = "É necessário cadastrar pelo menos 1 vaga de retirada (spawnCoords)." }
    end

    for idx, sp in ipairs(spawns) do
        if not validateCoords(sp, true) then
            return { success = false, msg = string.format("A vaga de retirada #%d possui coordenadas/heading inválidos.", idx) }
        end
    end

    -- Carrega garagens atuais
    local currentGarages = Config.FixedGarages or GaragesData or {}

    -- Se não foi confirmado sobrescrever e já existe
    if currentGarages[cleanId] and not garagePayload.overwrite then
        return {
            success = false,
            needsConfirm = true,
            msg = string.format("Já existe uma garagem cadastrada com o ID '%s'. Deseja sobrescrever?", cleanId)
        }
    end

    -- Monta estrutura final
    local newGarageRecord = {
        label = label,
        type = gType,
        job = (gType == "job") and (garagePayload.job or "police") or nil,
        gang = (gType == "gang") and (garagePayload.gang or "vagos") or nil,
        category = garagePayload.category or "car",
        coords = garagePayload.coords,
        dropZone = {
            points = dz.points,
            thickness = tonumber(dz.thickness) or 6.0
        },
        spawnCoords = spawns,
        pedModel = garagePayload.pedModel or Config.GaragePedModel or "a_m_y_business_01",
        blip = garagePayload.blip or { sprite = 357, color = 3, scale = 0.75 },
        price = tonumber(garagePayload.price) or 0
    }

    currentGarages[cleanId] = newGarageRecord

    -- Salva imediatamente no arquivo físico data/garages.json e faz broadcast
    local saved = SaveGaragesData(currentGarages)
    if saved then
        local adminName = GetPlayerName(src)
        print(string.format("^2[Haze Garages]^7 Garagem [%s] salva com sucesso por %s (ID: %d)! Atualizada em data/garages.json.", cleanId, adminName, src))
        Haze.Server.Notify(src, string.format("Garagem '%s' criada/salva com sucesso no data/garages.json!", label), "success")
        return { success = true, id = cleanId, msg = "Garagem salva com sucesso e ativa em tempo real!" }
    else
        return { success = false, msg = "Falha ao gravar arquivo data/garages.json no disco." }
    end
end)

--- Remove uma garagem existente do arquivo data/garages.json e sincroniza com os jogadores
lib.callback.register("haze_garages:server:deleteGarage", function(source, garageId)
    local src = source
    if not Haze.Server.IsAdmin(src) then
        return { success = false, msg = "Sem permissão administrativa." }
    end

    local cleanId = sanitizeId(garageId)
    if not cleanId then
        return { success = false, msg = "ID da garagem inválido." }
    end

    local currentGarages = Config.FixedGarages or GaragesData or {}
    if not currentGarages[cleanId] then
        return { success = false, msg = "Garagem não encontrada." }
    end

    local removedLabel = currentGarages[cleanId].label or cleanId
    currentGarages[cleanId] = nil

    local saved = SaveGaragesData(currentGarages)
    if saved then
        local adminName = GetPlayerName(src)
        print(string.format("^3[Haze Garages]^7 Garagem [%s] excluída por %s (ID: %d). Removida de data/garages.json.", cleanId, adminName, src))
        Haze.Server.Notify(src, string.format("Garagem '%s' excluída com sucesso!", removedLabel), "success")
        return { success = true, msg = "Garagem excluída com sucesso!" }
    else
        return { success = false, msg = "Erro ao atualizar data/garages.json após exclusão." }
    end
end)

--- Retorna a lista detalhada de garagens para o painel de gerenciamento do administrador
lib.callback.register("haze_garages:server:getAdminGaragesList", function(source)
    local src = source
    if not Haze.Server.IsAdmin(src) then return nil end

    local list = {}
    for gId, gData in pairs(Config.FixedGarages or GaragesData or {}) do
        list[#list + 1] = {
            id = gId,
            label = gData.label or gId,
            type = gData.type or "public",
            job = gData.job,
            gang = gData.gang,
            category = gData.category or "car",
            coords = gData.coords,
            spawnsCount = gData.spawnCoords and #gData.spawnCoords or 0,
            pointsCount = gData.dropZone and gData.dropZone.points and #gData.dropZone.points or 0
        }
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)
