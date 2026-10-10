-- =================================================================================
-- Haze Garages - Gerenciador de Persistência Dinâmica de Garagens (JSON)
-- Responsável pelo carregamento, gravação e hot-reload das garagens em tempo real.
-- =================================================================================

GaragesData = GaragesData or {}

local function toVec3(v)
    if not v then return vec3(0.0, 0.0, 0.0) end
    if type(v) == "vector3" then return v end
    return vec3(tonumber(v.x or v[1]) or 0.0, tonumber(v.y or v[2]) or 0.0, tonumber(v.z or v[3]) or 0.0)
end

local function toVec4(v)
    if not v then return vec4(0.0, 0.0, 0.0, 0.0) end
    if type(v) == "vector4" then return v end
    return vec4(tonumber(v.x or v[1]) or 0.0, tonumber(v.y or v[2]) or 0.0, tonumber(v.z or v[3]) or 0.0, tonumber(v.w or v.h or v[4]) or 0.0)
end

local function roundNum(val, decimals)
    local mult = 10 ^ (decimals or 2)
    return math.floor((tonumber(val) or 0.0) * mult + 0.5) / mult
end

--- Normaliza dados brutos do JSON para vetores nativos do FiveM
local function normalizeGarage(raw)
    local g = table.clone(raw)
    g.coords = toVec4(g.coords)

    if g.dropZone then
        if g.dropZone.points and #g.dropZone.points > 0 then
            local normPoints = {}
            for i = 1, #g.dropZone.points do
                normPoints[#normPoints + 1] = toVec3(g.dropZone.points[i])
            end
            g.dropZone.points = normPoints
        elseif g.dropZone.coords then
            g.dropZone.coords = toVec3(g.dropZone.coords)
        end
    elseif g.coords then
        g.dropZone = {
            coords = toVec3(g.coords),
            radius = 6.0
        }
    end

    if g.spawnCoords and #g.spawnCoords > 0 then
        local normSpawns = {}
        for i = 1, #g.spawnCoords do
            normSpawns[#normSpawns + 1] = toVec4(g.spawnCoords[i])
        end
        g.spawnCoords = normSpawns
    end

    return g
end

--- Formata dados de uma garagem para estrutura serializável em JSON
local function serializeGarage(g)
    local c = g.coords
    local out = {
        label = g.label or "Garagem",
        type = g.type or "public",
        job = g.job or nil,
        gang = g.gang or nil,
        category = g.category or "car",
        coords = {
            x = roundNum(c.x or c[1], 2),
            y = roundNum(c.y or c[2], 2),
            z = roundNum(c.z or c[3], 2),
            w = roundNum(c.w or c.h or c[4] or 0.0, 1)
        },
        pedModel = g.pedModel or Config.GaragePedModel or "a_m_y_business_01",
        blip = g.blip or { sprite = 357, color = 3, scale = 0.75 },
        price = g.price or 0,
        hasPed = (g.hasPed ~= false),
        hasBlip = (g.hasBlip ~= false),
        isDynamic = (g.isDynamic == true),
        propertyId = g.propertyId or nil,
        buildingId = g.buildingId or nil
    }

    if g.dropZone then
        out.dropZone = {
            thickness = tonumber(g.dropZone.thickness) or 6.0
        }
        if g.dropZone.points and #g.dropZone.points > 0 then
            out.dropZone.points = {}
            for _, p in ipairs(g.dropZone.points) do
                table.insert(out.dropZone.points, {
                    x = roundNum(p.x or p[1], 2),
                    y = roundNum(p.y or p[2], 2),
                    z = roundNum(p.z or p[3], 2)
                })
            end
        elseif g.dropZone.coords then
            out.dropZone.coords = {
                x = roundNum(g.dropZone.coords.x or g.dropZone.coords[1], 2),
                y = roundNum(g.dropZone.coords.y or g.dropZone.coords[2], 2),
                z = roundNum(g.dropZone.coords.z or g.dropZone.coords[3], 2)
            }
            out.dropZone.radius = tonumber(g.dropZone.radius) or 6.0
        end
    end

    if g.spawnCoords and #g.spawnCoords > 0 then
        out.spawnCoords = {}
        for _, s in ipairs(g.spawnCoords) do
            table.insert(out.spawnCoords, {
                x = roundNum(s.x or s[1], 2),
                y = roundNum(s.y or s[2], 2),
                z = roundNum(s.z or s[3], 2),
                w = roundNum(s.w or s.h or s[4] or 0.0, 1)
            })
        end
    end

    return out
end

--- Carrega os dados de garagens do arquivo data/garages.json
function LoadGaragesData()
    local resName = GetCurrentResourceName()
    local content = LoadResourceFile(resName, "data/garages.json")

    local parsed = nil
    if content and content ~= "" then
        local ok, data = pcall(json.decode, content)
        if ok and type(data) == "table" and next(data) ~= nil then
            parsed = data
        end
    end

    -- Se o arquivo não existir ou estiver vazio, restaura as garagens padrão no disco
    if not parsed then
        print("^3[Haze Garages]^7 Arquivo data/garages.json não encontrado. Criando arquivo com garagens padrão...")
        local defaultGarages = {
            ["legion_square"] = {
                label = "Garagem Central - Praça Legion",
                type = "public",
                category = "car",
                coords = { x = 215.12, y = -810.55, z = 30.7, w = 320.0 },
                dropZone = {
                    points = {
                        { x = 210.5, y = -792.0, z = 30.6 },
                        { x = 220.5, y = -792.0, z = 30.6 },
                        { x = 220.5, y = -805.0, z = 30.6 },
                        { x = 210.5, y = -805.0, z = 30.6 }
                    },
                    thickness = 6.0
                },
                spawnCoords = {
                    { x = 222.1, y = -805.2, z = 30.6, w = 140.0 },
                    { x = 225.8, y = -803.5, z = 30.6, w = 140.0 },
                    { x = 229.5, y = -801.8, z = 30.6, w = 140.0 },
                    { x = 233.2, y = -800.1, z = 30.6, w = 140.0 }
                },
                pedModel = "a_m_y_business_01",
                blip = { sprite = 357, color = 3, scale = 0.75 },
                price = 0
            },
            ["pillbox_roof"] = {
                label = "Heliponto Hospital Pillbox",
                type = "public",
                category = "plane",
                coords = { x = 352.1, y = -588.2, z = 74.16, w = 250.0 },
                dropZone = {
                    points = {
                        { x = 343.0, y = -580.0, z = 74.16 },
                        { x = 358.0, y = -580.0, z = 74.16 },
                        { x = 358.0, y = -596.0, z = 74.16 },
                        { x = 343.0, y = -596.0, z = 74.16 }
                    },
                    thickness = 8.0
                },
                spawnCoords = {
                    { x = 348.5, y = -587.1, z = 74.16, w = 70.0 },
                    { x = 354.2, y = -594.3, z = 74.16, w = 70.0 }
                },
                pedModel = "s_m_m_doctor_01",
                blip = { sprite = 423, color = 3, scale = 0.75 },
                price = 0
            },
            ["marina_boat"] = {
                label = "Marina de Los Santos",
                type = "public",
                category = "boat",
                coords = { x = -735.4, y = -1320.1, z = 1.6, w = 0.0 },
                dropZone = {
                    points = {
                        { x = -716.0, y = -1320.0, z = 0.5 },
                        { x = -734.0, y = -1320.0, z = 0.5 },
                        { x = -734.0, y = -1340.0, z = 0.5 },
                        { x = -716.0, y = -1340.0, z = 0.5 }
                    },
                    thickness = 10.0
                },
                spawnCoords = {
                    { x = -730.1, y = -1330.5, z = 0.5, w = 180.0 },
                    { x = -723.4, y = -1335.2, z = 0.5, w = 180.0 },
                    { x = -716.8, y = -1339.8, z = 0.5, w = 180.0 }
                },
                pedModel = "s_m_m_dockwork_01",
                blip = { sprite = 410, color = 3, scale = 0.75 },
                price = 0
            },
            ["police_main"] = {
                label = "Garagem Departamento de Polícia (LSPD)",
                type = "job",
                job = "police",
                category = "car",
                coords = { x = 441.1, y = -981.2, z = 30.6, w = 270.0 },
                dropZone = {
                    points = {
                        { x = 435.0, y = -988.0, z = 30.6 },
                        { x = 447.0, y = -988.0, z = 30.6 },
                        { x = 447.0, y = -1002.0, z = 30.6 },
                        { x = 435.0, y = -1002.0, z = 30.6 }
                    },
                    thickness = 6.0
                },
                spawnCoords = {
                    { x = 447.2, y = -981.2, z = 30.6, w = 90.0 },
                    { x = 447.2, y = -985.4, z = 30.6, w = 90.0 },
                    { x = 447.2, y = -989.6, z = 30.6, w = 90.0 },
                    { x = 447.2, y = -993.8, z = 30.6, w = 90.0 }
                },
                pedModel = "s_m_y_cop_01",
                blip = { sprite = 60, color = 38, scale = 0.8 },
                price = 0
            },
            ["vagos_base"] = {
                label = "Garagem Facção Vagos",
                type = "gang",
                gang = "vagos",
                category = "car",
                coords = { x = 335.5, y = -2012.3, z = 20.8, w = 225.0 },
                dropZone = {
                    points = {
                        { x = 332.0, y = -2004.0, z = 20.8 },
                        { x = 345.0, y = -2004.0, z = 20.8 },
                        { x = 345.0, y = -2017.0, z = 20.8 },
                        { x = 332.0, y = -2017.0, z = 20.8 }
                    },
                    thickness = 6.0
                },
                spawnCoords = {
                    { x = 340.1, y = -2015.4, z = 20.8, w = 45.0 },
                    { x = 344.2, y = -2018.7, z = 20.8, w = 45.0 },
                    { x = 348.5, y = -2022.1, z = 20.8, w = 45.0 }
                },
                pedModel = "g_m_y_salvagoon_01",
                blip = { sprite = 84, color = 5, scale = 0.8 },
                price = 0
            },
            ["impound_main"] = {
                label = "Pátio de Apreensão Policial (Impound)",
                type = "impound",
                category = "car",
                coords = { x = 409.12, y = -1623.55, z = 29.3, w = 50.0 },
                dropZone = {
                    points = {
                        { x = 393.0, y = -1622.0, z = 29.3 },
                        { x = 407.0, y = -1622.0, z = 29.3 },
                        { x = 407.0, y = -1638.0, z = 29.3 },
                        { x = 393.0, y = -1638.0, z = 29.3 }
                    },
                    thickness = 6.0
                },
                spawnCoords = {
                    { x = 404.1, y = -1630.2, z = 29.3, w = 230.0 },
                    { x = 400.5, y = -1634.4, z = 29.3, w = 230.0 },
                    { x = 396.8, y = -1638.6, z = 29.3, w = 230.0 }
                },
                pedModel = "s_m_y_valet_01",
                blip = { sprite = 67, color = 1, scale = 0.75 },
                price = 0
            }
        }
        parsed = defaultGarages
        SaveResourceFile(resName, "data/garages.json", json.encode(parsed, { indent = true }), -1)
    end

    -- Normaliza para o ambiente em execução
    GaragesData = {}
    Config.FixedGarages = Config.FixedGarages or {}

    for gId, raw in pairs(parsed) do
        local norm = normalizeGarage(raw)
        GaragesData[gId] = norm
        Config.FixedGarages[gId] = norm
    end

    local count = 0
    for _ in pairs(GaragesData) do count = count + 1 end
    print(string.format("^2[Haze Garages]^7 Carregadas com sucesso ^3%d^7 garagens de ^2data/garages.json^7!", count))
    return GaragesData
end

--- Salva as garagens estáticas em data/garages.json e faz broadcast imediato para todos os clientes
--- Garagens dinâmicas (ex: ps-housing) são mantidas em memória e não poluem o arquivo JSON
--- @param garagesTable table Tabela com todas as garagens
--- @return boolean
function SaveGaragesData(garagesTable)
    if type(garagesTable) ~= "table" then return false end

    local exportTable = {}
    for gId, gData in pairs(garagesTable) do
        if not gData.isDynamic then
            exportTable[gId] = serializeGarage(gData)
        end
    end

    local resName = GetCurrentResourceName()
    local success = SaveResourceFile(resName, "data/garages.json", json.encode(exportTable, { indent = true }), -1)

    if success then
        -- Atualiza memória local do servidor preservando garagens dinâmicas
        GaragesData = {}
        Config.FixedGarages = Config.FixedGarages or {}

        for gId, raw in pairs(exportTable) do
            local norm = normalizeGarage(raw)
            GaragesData[gId] = norm
            Config.FixedGarages[gId] = norm
        end

        -- Restaura as garagens dinâmicas na tabela unificada Config.FixedGarages
        for gId, dNorm in pairs(DynamicGarages or {}) do
            Config.FixedGarages[gId] = dNorm
        end

        -- Sincroniza em tempo real com todos os jogadores conectados
        local allGaragesSync = {}
        for gId, gData in pairs(Config.FixedGarages) do
            allGaragesSync[gId] = serializeGarage(gData)
        end
        TriggerClientEvent("haze_garages:client:syncGarages", -1, allGaragesSync)
        print("^2[Haze Garages]^7 Arquivo data/garages.json atualizado no disco e sincronizado em tempo real!")
        return true
    else
        print("^1[Haze Garages] ERRO ao salvar data/garages.json no disco!^7")
        return false
    end
end

-- =================================================================================
-- Gerenciador de Garagens Dinâmicas (Residências, Prédios e Eventos em Tempo Real)
-- =================================================================================

DynamicGarages = DynamicGarages or {}

--- Registra ou atualiza uma garagem dinâmica em tempo real (sem gravar no data/garages.json)
--- @param garageId string Identificador único da garagem (ex: 'housegarage-12', 'buildinggarage-3')
--- @param data table Configuração completa da garagem (coords, spawnCoords, dropZone, canAccess, etc.)
--- @param syncClient boolean|nil Se true ou nil, envia atualização imediata aos clientes conectados
--- @return boolean success
function RegisterDynamicGarage(garageId, data, syncClient)
    if not garageId or type(garageId) ~= "string" or type(data) ~= "table" then
        print(string.format("^1[Haze Garages] RegisterDynamicGarage chamado com parâmetros inválidos (id: %s)^7", tostring(garageId)))
        return false
    end

    local g = table.clone(data)
    g.id = garageId
    g.isDynamic = true
    if g.hasPed == nil then
        g.hasPed = (g.type ~= "house" and g.type ~= "building")
    end
    if g.hasBlip == nil then
        g.hasBlip = (g.type ~= "house" and g.type ~= "building")
    end

    local norm = normalizeGarage(g)
    -- Preserva funções de controle de acesso Lua (que clones ou json não copiam)
    norm.canAccess = data.canAccess
    norm.isDynamic = true
    norm.hasPed = g.hasPed
    norm.hasBlip = g.hasBlip
    norm.propertyId = data.propertyId
    norm.buildingId = data.buildingId

    DynamicGarages[garageId] = norm
    Config.FixedGarages = Config.FixedGarages or {}
    Config.FixedGarages[garageId] = norm

    if syncClient ~= false then
        local serialized = serializeGarage(norm)
        TriggerClientEvent("haze_garages:client:syncDynamicGarage", -1, garageId, serialized)
    end

    return true
end

--- Remove uma garagem dinâmica registrada
--- @param garageId string Identificador da garagem
--- @return boolean
function UnregisterDynamicGarage(garageId)
    if not garageId then return false end
    if not Config.FixedGarages or not Config.FixedGarages[garageId] then
        return false
    end

    DynamicGarages[garageId] = nil
    Config.FixedGarages[garageId] = nil

    TriggerClientEvent("haze_garages:client:removeDynamicGarage", -1, garageId)
    return true
end

--- Verifica se uma garagem está registrada no sistema
--- @param garageId string
--- @return boolean
function IsGarageRegistered(garageId)
    return (Config.FixedGarages and Config.FixedGarages[garageId] ~= nil) or false
end

--- Retorna os dados completos de uma garagem
--- @param garageId string
--- @return table|nil
function GetGarage(garageId)
    return Config.FixedGarages and Config.FixedGarages[garageId]
end

-- Callbacks e eventos de sincronização
lib.callback.register("haze_garages:server:getGarages", function(source)
    local exportTable = {}
    for gId, gData in pairs(Config.FixedGarages or GaragesData or {}) do
        exportTable[gId] = serializeGarage(gData)
    end
    return exportTable
end)

-- Exports do Servidor
exports("GetGaragesData", function()
    return GaragesData
end)

exports("SaveGaragesData", function(data)
    return SaveGaragesData(data)
end)

exports("RegisterDynamicGarage", function(garageId, data, syncClient)
    return RegisterDynamicGarage(garageId, data, syncClient)
end)

exports("UnregisterDynamicGarage", function(garageId)
    return UnregisterDynamicGarage(garageId)
end)

exports("IsGarageRegistered", function(garageId)
    return IsGarageRegistered(garageId)
end)

exports("GetGarage", function(garageId)
    return GetGarage(garageId)
end)

exports("GetDynamicGarages", function()
    return DynamicGarages
end)

-- Carrega as garagens no boot do servidor
CreateThread(function()
    LoadGaragesData()
end)
