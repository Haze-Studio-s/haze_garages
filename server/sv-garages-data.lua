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
        price = g.price or 0
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

    -- Se o arquivo não existir ou estiver vazio, faz fallback e cria o arquivo inicial
    if not parsed then
        print("^3[Haze Garages]^7 Arquivo data/garages.json não encontrado ou vazio. Migrando garagens padrão...")
        parsed = {}
        for gId, gData in pairs(Config.FixedGarages or {}) do
            parsed[gId] = serializeGarage(gData)
        end
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

--- Salva as garagens em data/garages.json e faz broadcast imediato para todos os clientes
--- @param garagesTable table Tabela com todas as garagens
--- @return boolean
function SaveGaragesData(garagesTable)
    if type(garagesTable) ~= "table" then return false end

    local exportTable = {}
    for gId, gData in pairs(garagesTable) do
        exportTable[gId] = serializeGarage(gData)
    end

    local resName = GetCurrentResourceName()
    local success = SaveResourceFile(resName, "data/garages.json", json.encode(exportTable, { indent = true }), -1)

    if success then
        -- Atualiza memória local do servidor
        GaragesData = {}
        Config.FixedGarages = Config.FixedGarages or {}

        for gId, raw in pairs(exportTable) do
            local norm = normalizeGarage(raw)
            GaragesData[gId] = norm
            Config.FixedGarages[gId] = norm
        end

        -- Sincroniza em tempo real com todos os jogadores conectados
        TriggerClientEvent("haze_garages:client:syncGarages", -1, exportTable)
        print("^2[Haze Garages]^7 Arquivo data/garages.json atualizado no disco e sincronizado em tempo real!")
        return true
    else
        print("^1[Haze Garages] ERRO ao salvar data/garages.json no disco!^7")
        return false
    end
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

-- Carrega as garagens no boot do servidor
CreateThread(function()
    LoadGaragesData()
end)
