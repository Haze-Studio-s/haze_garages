local spawnedGaragePeds = {}
local garageBlips = {}
local garagePoints = {}

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

local function normalizeGaragesTable(rawTable)
    local out = {}
    for gId, raw in pairs(rawTable or {}) do
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

        out[gId] = g
    end
    return out
end

local function cleanupGaragePeds()
    for _, ped in ipairs(spawnedGaragePeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedGaragePeds = {}
end

local function canAccessGarageClient(garageData)
    if not garageData then return false end
    if garageData.type == "public" or not garageData.type or garageData.type == "impound" then
        return true
    elseif garageData.type == "job" and garageData.job then
        return Haze.Client.GetPlayerJob() == garageData.job
    elseif garageData.type == "gang" and garageData.gang then
        return Haze.Client.GetPlayerGang() == garageData.gang
    end
    return false
end

local function refreshGarageBlips()
    for _, blip in pairs(garageBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    garageBlips = {}

    for garageId, gData in pairs(Config.FixedGarages or {}) do
        if canAccessGarageClient(gData) then
            local bCfg = gData.blip or { sprite = 357, color = 3, scale = 0.75 }
            local blip = AddBlipForCoord(gData.coords.x, gData.coords.y, gData.coords.z)
            SetBlipSprite(blip, bCfg.sprite or 357)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, bCfg.scale or 0.75)
            SetBlipColour(blip, bCfg.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(gData.label or "Garagem")
            EndTextCommandSetBlipName(blip)
            garageBlips[garageId] = blip
        end
    end
end

RegisterNetEvent("QBCore:Client:OnJobUpdate", function() refreshGarageBlips() end)
RegisterNetEvent("qbx_core:client:onJobUpdate", function() refreshGarageBlips() end)
RegisterNetEvent("QBCore:Client:OnGangUpdate", function() refreshGarageBlips() end)
RegisterNetEvent("qbx_core:client:onGangUpdate", function() refreshGarageBlips() end)
RegisterNetEvent("esx:setJob", function() refreshGarageBlips() end)

local function getBestSpawnCoords(spawnData)
    if not spawnData then
        local pedCoords = GetEntityCoords(cache.ped or PlayerPedId())
        return vec4(pedCoords.x + 2.0, pedCoords.y + 2.0, pedCoords.z, GetEntityHeading(cache.ped or PlayerPedId()))
    end

    -- Se for um vec4 único
    if spawnData.x and not spawnData[1] then
        return spawnData
    end

    -- Se for array de vagas { vec4(...), vec4(...) }
    for _, spot in ipairs(spawnData) do
        local checkVec = vec3(spot.x, spot.y, spot.z)
        local isOccupied = IsPositionOccupied(checkVec.x, checkVec.y, checkVec.z, 2.5, false, true, false, false, false, 0, false)
        if not isOccupied then
            local closest = lib.getClosestVehicle(checkVec, 2.5, true)
            if not closest or closest == 0 then
                return spot
            end
        end
    end

    -- Se todas estiverem ocupadas, usa a primeira como fallback
    return spawnData[1]
end

local isStoringVehicle = false

RegisterNetEvent("haze_garages:client:forceLeaveVehicle", function(targetNetId)
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        if NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) == targetNetId then
            TaskLeaveVehicle(ped, veh, 0)
        end
    end
end)

--- Retorna o centro médio de um conjunto de pontos vec3
local function getPolygonCenter(points)
    if not points or #points == 0 then return vec3(0, 0, 0) end
    local cx, cy, cz = 0.0, 0.0, 0.0
    local n = #points
    for i = 1, n do
        cx = cx + points[i].x
        cy = cy + points[i].y
        cz = cz + points[i].z
    end
    return vec3(cx / n, cy / n, cz / n)
end

--- Retorna a distância máxima do centro até qualquer um dos vértices
local function getPolygonMaxRadius(center, points)
    if not points or #points == 0 then return 6.0 end
    local maxDist = 0.0
    for i = 1, #points do
        local d = #(vec2(points[i].x, points[i].y) - vec2(center.x, center.y))
        if d > maxDist then maxDist = d end
    end
    return maxDist
end

--- Verifica se uma coordenada 3D está dentro da dropZone (Polígono de 4 pontos ou círculo)
local function isCoordsInDropZone(coords, dz)
    if not dz or not coords then return false end

    -- Modo 1: Área demarcada por 4 pontos (ou mais)
    if dz.points and #dz.points >= 3 then
        local center = getPolygonCenter(dz.points)
        local thickness = dz.thickness or 6.0

        -- Validação de altura Z
        if math.abs(coords.z - center.z) > (thickness / 2.0 + 2.0) then
            return false
        end

        -- Raycasting 2D point-in-polygon
        local poly = dz.points
        local inside = false
        local j = #poly
        for i = 1, #poly do
            if ((poly[i].y > coords.y) ~= (poly[j].y > coords.y)) and
               (coords.x < (poly[j].x - poly[i].x) * (coords.y - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x) then
                inside = not inside
            end
            j = i
        end
        return inside
    end

    -- Modo 2: Raio circular simples (retrocompatibilidade)
    if dz.coords then
        local radius = dz.radius or 6.0
        return #(coords - dz.coords) <= radius
    end

    return false
end


local function getVehicleInGarageDropZone(garageId)
    local gData = Config.FixedGarages[garageId]
    if not gData then return nil end

    local dz = gData.dropZone
    if not dz then return nil end

    -- Se o jogador estiver dentro de um veículo, checa se este veículo está na área de 4 pontos
    local ped = cache.ped or PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    if currentVeh and currentVeh ~= 0 and DoesEntityExist(currentVeh) then
        local vehCoords = GetEntityCoords(currentVeh)
        if isCoordsInDropZone(vehCoords, dz) then
            return currentVeh
        end
    end

    -- Se o jogador estiver a pé (ex: falando com atendente NPC via ox_target):
    local center = (dz.points and #dz.points >= 3) and getPolygonCenter(dz.points) or (dz.coords or vec3(gData.coords.x, gData.coords.y, gData.coords.z))
    local searchRadius = (dz.points and #dz.points >= 3) and (getPolygonMaxRadius(center, dz.points) + 4.0) or (dz.radius or 6.0)

    local closestVeh = lib.getClosestVehicle(center, searchRadius, true)
    if closestVeh and DoesEntityExist(closestVeh) then
        local vehCoords = GetEntityCoords(closestVeh)
        if isCoordsInDropZone(vehCoords, dz) then
            return closestVeh
        end
    end

    return nil
end

local function storeVehicleAtGarage(garageId, veh)
    if isStoringVehicle then
        Haze.Client.Notify("Já existe um processo de armazenamento de veículo em andamento.", "warning")
        return false
    end

    if not veh or not DoesEntityExist(veh) then
        Haze.Client.Notify("Nenhum veículo encontrado para guardar.", "error")
        return false
    end

    local gData = Config.FixedGarages[garageId]
    if not gData then
        Haze.Client.Notify("Garagem inválida.", "error")
        return false
    end

    if not canAccessGarageClient(gData) then
        Haze.Client.Notify("Você não possui permissão para guardar veículos nesta garagem.", "error")
        return false
    end

    isStoringVehicle = true

    -- 1. Fazer todos os ocupantes descerem do veículo (motorista e passageiros)
    local maxSeats = GetVehicleMaxNumberOfPassengers(veh)
    for seat = -1, maxSeats - 1 do
        local occupant = GetPedInVehicleSeat(veh, seat)
        if occupant and occupant ~= 0 and DoesEntityExist(occupant) then
            TaskLeaveVehicle(occupant, veh, 0)
        end
    end

    -- Sincronizar com outros jogadores na rede que estejam dentro do veículo
    if NetworkGetEntityIsNetworked(veh) then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent("haze_garages:server:ejectPassengers", netId)
    end

    -- 2. Trancar portas, desligar motor e piscar faróis
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleLights(veh, 2)
    SetTimeout(350, function()
        if DoesEntityExist(veh) then
            SetVehicleLights(veh, 0)
        end
    end)

    -- 3. Contagem regressiva de 5 segundos antes de sumir
    local countdownSec = Config.StoreCountdownSeconds or 5
    lib.progressBar({
        duration = countdownSec * 1000,
        label = "Inspecionando e guardando veículo...",
        useReplay = false,
        canCancel = false,
        disable = {
            combat = true,
            car = true
        }
    })

    if not DoesEntityExist(veh) then
        isStoringVehicle = false
        return false
    end

    local rawPlate = GetVehicleNumberPlateText(veh)
    local cleanPlate = Haze.Shared.CleanPlate(rawPlate)
    local props = Haze.Client.GetVehicleProperties(veh)

    local deformationData, mechanicalData = nil, nil
    if Haze.Client.GetVehicleDeformation then
        pcall(function()
            deformationData, mechanicalData = Haze.Client.GetVehicleDeformation(veh)
        end)
    end

    local success, payload = lib.callback.await("haze_garages:server:storeVehicle", false, cleanPlate, garageId, props, deformationData, mechanicalData)
    if success then
        SetEntityAsMissionEntity(veh, true, true)
        local tries = 0
        while DoesEntityExist(veh) and tries < 20 do
            NetworkRequestControlOfEntity(veh)
            DeleteVehicle(veh)
            DeleteEntity(veh)
            Wait(50)
            tries = tries + 1
        end
        isStoringVehicle = false
        return true
    else
        SetVehicleDoorsLocked(veh, 1)
        Haze.Client.Notify(payload or "Erro ao guardar veículo.", "error")
        isStoringVehicle = false
        return false
    end
end

RegisterNetEvent("haze_garages:client:storeClosestVehicle", function(garageId)
    local veh = getVehicleInGarageDropZone(garageId)
    if veh then
        storeVehicleAtGarage(garageId, veh)
    else
        Haze.Client.Notify("Nenhum veículo seu foi encontrado na vaga de devolução desta garagem. Estacione na vaga demarcada para guardar.", "warning")
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        cleanupGaragePeds()
        for _, blip in pairs(garageBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        garageBlips = {}
        for _, pt in ipairs(garagePoints) do
            pt:remove()
        end
        garagePoints = {}
    end
end)

local function initGaragesMesh()
    cleanupGaragePeds()
    refreshGarageBlips()

    for _, pt in ipairs(garagePoints) do
        pt:remove()
    end
    garagePoints = {}

    for garageId, garageData in pairs(Config.FixedGarages or {}) do
        local pedModel = garageData.pedModel or Config.GaragePedModel or "a_m_y_business_01"
        local pedHash = Haze.Shared.GetModelHash(pedModel)

        if pedHash and Haze.Client.RequestModel(pedHash) then
            local heading = ((garageData.coords.w or 0.0) + 180.0) % 360.0
            local ped = CreatePed(4, pedHash, garageData.coords.x, garageData.coords.y, garageData.coords.z - 1.0, heading, false, false)
            SetEntityHeading(ped, heading)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedDiesWhenInjured(ped, false)
            SetPedCanPlayAmbientAnims(ped, true)
            SetPedCanRagdollFromPlayerImpact(ped, false)

            spawnedGaragePeds[#spawnedGaragePeds + 1] = ped

            if exports.ox_target then
                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = "haze_garage_open_" .. garageId,
                        icon = "fas fa-warehouse",
                        label = garageData.label,
                        onSelect = function()
                            TriggerEvent("haze_garages:client:openGarageMenu", garageId)
                        end
                    },
                    {
                        name = "haze_garage_store_" .. garageId,
                        icon = "fas fa-arrow-down",
                        label = "Guardar Veículo (Vaga de Devolução)",
                        onSelect = function()
                            local veh = getVehicleInGarageDropZone(garageId)
                            if veh then
                                storeVehicleAtGarage(garageId, veh)
                            else
                                Haze.Client.Notify("Nenhum veículo seu foi encontrado na vaga de devolução desta garagem. Estacione o veículo na área demarcada para guardá-lo.", "error")
                            end
                        end
                    }
                })
            else
                local pt = lib.points.new({
                    coords = vec3(garageData.coords.x, garageData.coords.y, garageData.coords.z),
                    distance = 4.0,
                    onEnter = function()
                        lib.showTextUI(Locale.garage_open_prompt)
                    end,
                    onLeave = function()
                        lib.hideTextUI()
                    end,
                    nearby = function()
                        if IsControlJustReleased(0, 38) then -- Key E
                            TriggerEvent("haze_garages:client:openGarageMenu", garageId)
                        end
                    end
                })
                garagePoints[#garagePoints + 1] = pt
            end

            -- Ponto demarcado para guardar veículo (Drop-off Zone de 4 Pontos ou Raio)
            local dz = garageData.dropZone
            if dz then
                local isPoly = dz.points and #dz.points >= 3
                local center = isPoly and getPolygonCenter(dz.points) or (dz.coords or vec3(garageData.coords.x, garageData.coords.y, garageData.coords.z))
                local maxRadius = isPoly and getPolygonMaxRadius(center, dz.points) or (dz.radius or 6.0)
                local isPromptShown = false

                local drivePt = lib.points.new({
                    coords = center,
                    distance = maxRadius + 4.0,
                    onLeave = function()
                        if isPromptShown then
                            lib.hideTextUI()
                            isPromptShown = false
                        end
                    end,
                    nearby = function(self)
                        -- Detecta se o jogador no veículo está dentro da área fechada pelos 4 pontos
                        local ped = cache.ped or PlayerPedId()
                        if IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
                            local currentVeh = GetVehiclePedIsIn(ped, false)
                            local vehCoords = GetEntityCoords(currentVeh)
                            local isInside = isCoordsInDropZone(vehCoords, dz)

                            if isInside then
                                if not isPromptShown then
                                    lib.showTextUI("[E] Guardar Veículo na " .. (garageData.label or garageId))
                                    isPromptShown = true
                                end

                                if IsControlJustReleased(0, 38) then -- Key E
                                    if isPromptShown then
                                        lib.hideTextUI()
                                        isPromptShown = false
                                    end
                                    storeVehicleAtGarage(garageId, currentVeh)
                                end
                            else
                                if isPromptShown then
                                    lib.hideTextUI()
                                    isPromptShown = false
                                end
                            end
                        else
                            if isPromptShown then
                                lib.hideTextUI()
                                isPromptShown = false
                            end
                        end
                    end
                })
                garagePoints[#garagePoints + 1] = drivePt
            end
        end
    end
end

-- Evento de inicialização do cliente
AddEventHandler("haze_garages:client:init", function()
    CreateThread(function()
        local ok, serverGarages = pcall(function()
            return lib.callback.await("haze_garages:server:getGarages", false)
        end)
        if ok and serverGarages and type(serverGarages) == "table" and next(serverGarages) ~= nil then
            Config.FixedGarages = normalizeGaragesTable(serverGarages)
        end
        initGaragesMesh()
    end)
end)

-- Evento de hot-reload em tempo real quando garagens são criadas/editadas/excluídas
RegisterNetEvent("haze_garages:client:syncGarages", function(serverGarages)
    if serverGarages and type(serverGarages) == "table" then
        Config.FixedGarages = normalizeGaragesTable(serverGarages)
        initGaragesMesh()
    end
end)


RegisterNetEvent("haze_garages:client:openGarageMenu", function(garageId)
    local garage = Config.FixedGarages[garageId]
    if not garage then return end

    local res = lib.callback.await("haze_garages:server:getUserVehicles", false, garageId)
    if not res or not res.success then
        if res and res.reason == "no_permission" then
            Haze.Client.Notify("Você não possui permissão para acessar esta garagem.", "error")
        else
            Haze.Client.Notify("Não foi possível acessar os veículos desta garagem.", "error")
        end
        return
    end

    local vehicles = res.vehicles or {}
    if #vehicles == 0 then
        Haze.Client.Notify("Você não possui veículos nesta garagem.", "warning")
        return
    end

    local nuiVehicles = {}
    for _, v in ipairs(vehicles) do
        local plate = v.plate
        local model = v.vehicle or v.model or "Desconhecido"
        local mods = v.mods and (type(v.mods) == "string" and json.decode(v.mods) or v.mods) or {}
        
        local wearInfo = nil
        if Config.EnableGranollaMechanic and GetResourceState('granolla_mechanic') == 'started' then
            pcall(function()
                wearInfo = lib.callback.await("granolla_mechanic:server:getVehicleWear", false, plate, false)
            end)
        end

        nuiVehicles[#nuiVehicles + 1] = {
            plate = plate,
            model = string.upper(model),
            nickname = v.nickname or "",
            statusLabel = v.statusLabel,
            isSpawnable = v.isSpawnable,
            spawnType = v.spawnType,
            garage = v.garage,
            engine = mods.engineHealth or v.engine or 1000,
            body = mods.bodyHealth or v.body or 1000,
            fuel = mods.fuelLevel or v.fuel or 100,
            mileage = v.mileage or 0,
            wear = wearInfo and wearInfo.wear or nil
        }
    end

    local hasTransferContract = false
    if GetResourceState("ox_inventory") == "started" then
        local count = exports.ox_inventory:Search("count", "vehicle_transfer_contract") or 0
        hasTransferContract = count > 0
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openGarage",
        title = garage.label,
        garageId = garageId,
        vehicles = nuiVehicles,
        hasTransferContract = hasTransferContract
    })
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNetEvent("haze_garages:client:spawnVehicle", function(plate, garageId)
    local success, payload = lib.callback.await("haze_garages:server:spawnVehicle", false, plate, garageId)
    if not success then
        Haze.Client.Notify(payload or "Erro ao retirar veículo.", "error")
        return
    end

    local spawnCoords = getBestSpawnCoords(payload.spawnCoords)

    local modelHash = Haze.Shared.GetModelHash(payload.model)
    if not modelHash or not Haze.Client.RequestModel(modelHash) then
        Haze.Client.Notify("Erro ao carregar modelo do veículo.", "error")
        return
    end

    local veh = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0, true, false)
    SetVehicleNumberPlateText(veh, payload.plate)

    if payload.mods then
        Haze.Client.SetVehicleProperties(veh, payload.mods)
    end

    if payload.deformation or payload.mechanical then
        TriggerEvent("haze_garages:client:applyVehicleDeformation", veh, payload.deformation, payload.mechanical)
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent("haze_garages:server:giveVehicleKeys", netId, payload.plate)
    TriggerEvent("qb-vehiclekeys:client:AddKeys", payload.plate)

    Haze.Client.Notify("Veículo retirado com sucesso!", "success")
end)

RegisterNUICallback("spawnVehicle", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })
    TriggerEvent("haze_garages:client:spawnVehicle", data.plate, data.garageId)
    cb("ok")
end)

RegisterNUICallback("transferVehicle", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })

    if not data or not data.plate then
        cb("error")
        return
    end

    if GetResourceState("granolla_dealershipv2") == "started" then
        TriggerEvent("granolla_dealershipv2:client:startVehicleTransferByPlate", data.plate)
        cb("ok")
    else
        Haze.Client.Notify("Sistema de transferência indisponível.", "error")
        cb("error")
    end
end)

RegisterNUICallback("setNickname", function(data, cb)
    if not data or not data.plate then cb({ ok = false }) return end
    local success, res = lib.callback.await("haze_garages:server:setNickname", false, data.plate, data.nickname)
    if success then
        Haze.Client.Notify(res.nickname ~= "" and string.format("Apelido definido: '%s'", res.nickname) or "Apelido removido.", "success")
        cb({ ok = true, plate = res.plate, nickname = res.nickname })
    else
        Haze.Client.Notify(res or "Erro ao definir apelido.", "error")
        cb({ ok = false })
    end
end)

RegisterNUICallback("trackVehicle", function(data, cb)
    if data and data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        Haze.Client.Notify("Localização do veículo marcada no GPS!", "info")
        cb("ok")
    else
        cb("error")
    end
end)

RegisterNUICallback("trackGarage", function(data, cb)
    local garageId = data and data.garageId or "legion_square"
    local garage = Config.FixedGarages[garageId]
    if garage and garage.coords then
        SetNewWaypoint(garage.coords.x + 0.0, garage.coords.y + 0.0)
        Haze.Client.Notify(string.format("Garagem [%s] marcada no GPS!", garage.label or garageId), "success")
        cb("ok")
    else
        cb("error")
    end
end)

RegisterNUICallback("recoverStrandedVehicle", function(data, cb)
    if not data or not data.plate then return cb({ ok = false }) end
    local res = lib.callback.await("haze_garages:server:recoverStrandedVehicle", false, data.plate)
    if res and res.success then
        if res.coords then
            SetNewWaypoint(res.coords.x + 0.0, res.coords.y + 0.0)
        end
        cb({ ok = true, msg = "Veículo rebocado com sucesso!" })
    else
        cb({ ok = false, msg = res and res.msg or "Erro ao solicitar guincho." })
    end
end)

RegisterNUICallback("unparkVehicle", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })

    local plate = data.plate
    local success, payload = lib.callback.await("haze_garages:server:unparkOrSpawnVehicle", false, plate)
    if not success then
        Haze.Client.Notify(payload or "Erro ao retirar veículo.", "error")
        cb("error")
        return
    end

    local spawnCoords = payload.spawnCoords or GetEntityCoords(cache.ped or PlayerPedId())

    local modelHash = Haze.Shared.GetModelHash(payload.model)
    if not modelHash or not Haze.Client.RequestModel(modelHash) then
        Haze.Client.Notify("Erro ao carregar modelo do veículo.", "error")
        cb("error")
        return
    end

    local veh = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0, true, false)
    SetVehicleNumberPlateText(veh, payload.plate)

    if payload.mods then
        Haze.Client.SetVehicleProperties(veh, payload.mods)
    end

    if payload.deformation or payload.mechanical then
        TriggerEvent("haze_garages:client:applyVehicleDeformation", veh, payload.deformation, payload.mechanical)
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent("haze_garages:server:giveVehicleKeys", netId, payload.plate)
    TriggerEvent("qb-vehiclekeys:client:AddKeys", payload.plate)

    Haze.Client.Notify("Veículo retirado com sucesso!", "success")
    cb("ok")
end)

RegisterCommand("listarveiculos", function()
    local vehicles = lib.callback.await("haze_garages:server:getDetailedPlayerVehicles", false)
    if not vehicles or #vehicles == 0 then
        Haze.Client.Notify("Você não possui nenhum veículo cadastrado.", "info")
        return
    end

    local nuiVehicles = {}
    for _, v in ipairs(vehicles) do
        nuiVehicles[#nuiVehicles + 1] = {
            plate = v.plate,
            model = string.upper(v.model or "Desconhecido"),
            label = v.label or v.model,
            nickname = v.nickname or "",
            statusLabel = v.statusLabel,
            isSpawnable = v.isSpawnable,
            spawnType = v.spawnType,
            streetCoords = v.streetCoords,
            engine = v.engineHealth or 1000,
            body = v.bodyHealth or 1000,
            fuel = v.fuel or 100,
            mileage = v.mileage or 0
        }
    end

    local hasTransferContract = false
    if GetResourceState("ox_inventory") == "started" then
        local count = exports.ox_inventory:Search("count", "vehicle_transfer_contract") or 0
        hasTransferContract = count > 0
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openVehicleList",
        title = "🚗 Meus Veículos",
        vehicles = nuiVehicles,
        hasTransferContract = hasTransferContract
    })
end, false)


local function processVehicleDV(veh)
    if not veh or not DoesEntityExist(veh) then return false end

    local coords = GetEntityCoords(veh)
    local rawPlate = GetVehicleNumberPlateText(veh)
    local cleanPlate = Haze.Shared.CleanPlate(rawPlate)
    local props = Haze.Client.GetVehicleProperties(veh)

    local deformationData, mechanicalData = nil, nil
    if Haze.Client.GetVehicleDeformation then
        pcall(function()
            deformationData, mechanicalData = Haze.Client.GetVehicleDeformation(veh)
        end)
    end

    local result = lib.callback.await("haze_garages:server:dvStoreVehicle", false, cleanPlate, coords, props, deformationData, mechanicalData)

    SetEntityAsMissionEntity(veh, true, true)
    local tries = 0
    while DoesEntityExist(veh) and tries < 20 do
        NetworkRequestControlOfEntity(veh)
        DeleteVehicle(veh)
        DeleteEntity(veh)
        Wait(50)
        tries = tries + 1
    end

    if result and result.isPlayerVehicle then
        Haze.Client.Notify(string.format("Veículo [%s] guardado na garagem mais próxima (%s).", cleanPlate, result.garageLabel or "Garagem"), "success")
    else
        Haze.Client.Notify(string.format("Veículo [%s] deletado.", cleanPlate), "info")
    end

    return true
end

RegisterNetEvent("haze_garages:client:dvCommand", function(radiusArg)
    local ped = cache.ped or PlayerPedId()
    local pedVeh = GetVehiclePedIsIn(ped, false)

    if pedVeh and pedVeh ~= 0 then
        processVehicleDV(pedVeh)
        return
    end

    local radius = radiusArg and tonumber(radiusArg) or 5.0
    if radius > 50.0 then radius = 50.0 end

    local pedCoords = GetEntityCoords(ped)
    local closestVeh = lib.getClosestVehicle(pedCoords, radius, true)

    if closestVeh and DoesEntityExist(closestVeh) then
        processVehicleDV(closestVeh)
    else
        Haze.Client.Notify("Nenhum veículo próximo encontrado.", "error")
    end
end)

exports("dvVehicle", processVehicleDV)
exports("StoreVehicleNearestGarage", processVehicleDV)

-- NUI Callbacks para o App de Garagem Customizado no Telefone
RegisterNUICallback("getPhoneVehicles", function(data, cb)
    local vehicles = lib.callback.await("haze_garages:server:getPhoneVehicles", false)
    cb({ vehicles = vehicles or {} })
end)

RegisterNUICallback("trackPhoneVehicle", function(data, cb)
    if not data or not data.plate then cb({ ok = false }) return end

    local gpsRes = lib.callback.await("haze_garages:server:getVehicleGPS", false, data.plate)
    if gpsRes and gpsRes.ok and gpsRes.coords then
        SetNewWaypoint(gpsRes.coords.x + 0.0, gpsRes.coords.y + 0.0)
        Haze.Client.Notify("Sinal do GPS recebido! Localização marcada no mapa.", "success")
        cb({ ok = true })
    elseif gpsRes and gpsRes.reason == "no_tracker" then
        Haze.Client.Notify("Este veículo não possui Rastreador GPS instalado!", "error")
        cb({ ok = false, reason = "no_tracker" })
    elseif gpsRes and gpsRes.reason == "jammed" then
        Haze.Client.Notify("Sinal do GPS bloqueado por um Jammer!", "warning")
        cb({ ok = false, reason = "jammed" })
    else
        Haze.Client.Notify("Não foi possível obter a localização deste veículo.", "error")
        cb({ ok = false })
    end
end)

RegisterNUICallback("valetPhoneVehicle", function(data, cb)
    if not data or not data.plate then cb({ ok = false }) return end
    TriggerEvent("haze_garages:client:openGarageMenu", "legion_square")
    cb({ ok = true })
end)

-- Registro Automático do App no vp_phone
CreateThread(function()
    Wait(2000)
    if GetResourceState("vp_phone") == "started" then
        pcall(function()
            exports["vp_phone"]:AddCustomApp({
                identifier = "haze_garages",
                name = "Haze Garagens",
                description = "Gerencie seus veículos, rastreador GPS e localizações.",
                developer = "Haze Studios",
                defaultApp = true,
                icon = "https://cfx-nui-haze_garages/web/icon.png",
                ui = "web/phone.html"
            })
        end)
    end
end)

RegisterCommand("garagemapp", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openPhoneNUI" })
end, false)

-- Comando para Guardar Veículo na Garagem mais próxima
RegisterCommand("guardar", function()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        local pedCoords = GetEntityCoords(ped)
        veh = lib.getClosestVehicle(pedCoords, 8.0, true)
    end

    if not veh or not DoesEntityExist(veh) then
        Haze.Client.Notify("Você precisa estar dentro de um veículo ou próximo dele para guardar.", "error")
        return
    end

    local vehCoords = GetEntityCoords(veh)
    local nearestGarageId = nil
    local minDistance = 999999.0

    for gId, gData in pairs(Config.FixedGarages or {}) do
        if canAccessGarageClient(gData) then
            local dist = #(vec3(vehCoords.x, vehCoords.y, vehCoords.z) - vec3(gData.coords.x, gData.coords.y, gData.coords.z))
            if dist < minDistance then
                minDistance = dist
                nearestGarageId = gId
            end
        end
    end

    local maxDist = Config.StoreDistance or 15.0
    if not nearestGarageId or minDistance > maxDist then
        Haze.Client.Notify("Você não está próximo de nenhuma garagem fixa para guardar este veículo.", "error")
        return
    end

    storeVehicleAtGarage(nearestGarageId, veh)
end, false)

-- Comando para Listar Garagens e Marcar no GPS
RegisterCommand("garagens", function()
    local options = {}
    local pedCoords = GetEntityCoords(cache.ped or PlayerPedId())

    for gId, gData in pairs(Config.FixedGarages or {}) do
        if canAccessGarageClient(gData) then
            local dist = math.floor(#(pedCoords - vec3(gData.coords.x, gData.coords.y, gData.coords.z)))
            local icon = "warehouse"
            if gData.category == "boat" then icon = "ship"
            elseif gData.category == "plane" then icon = "plane"
            elseif gData.type == "job" then icon = "shield-halved"
            elseif gData.type == "impound" then icon = "truck-pickup"
            end

            table.insert(options, {
                title = gData.label,
                description = string.format("Distância: %d metros | Tipo: %s", dist, string.upper(gData.type or "Pública")),
                icon = icon,
                onSelect = function()
                    SetNewWaypoint(gData.coords.x + 0.0, gData.coords.y + 0.0)
                    Haze.Client.Notify(string.format("Garagem [%s] marcada no GPS!", gData.label), "success")
                end
            })
        end
    end

    if #options == 0 then
        Haze.Client.Notify("Nenhuma garagem disponível.", "warning")
        return
    end

    lib.registerContext({
        id = 'haze_garages_gps_list',
        title = '📍 Garagens de Los Santos',
        options = options
    })

    lib.showContext('haze_garages_gps_list')
end, false)

-- =================================================================================
-- Ferramenta Administrativa: Marcação dos 4 Pontos da Garagem no Mapa
-- =================================================================================
local tempZonePoints = {}

RegisterCommand("garagemzone", function(source, args)
    local subCmd = args[1] and string.lower(args[1]) or "help"
    local ped = cache.ped or PlayerPedId()
    local coords = GetEntityCoords(ped)

    if subCmd == "add" then
        if #tempZonePoints >= 8 then
            Haze.Client.Notify("Limite máximo de pontos atingido (máx 8). Digite /garagemzone clear para reiniciar.", "warning")
            return
        end

        local p = vec3(math.floor(coords.x * 100) / 100, math.floor(coords.y * 100) / 100, math.floor(coords.z * 100) / 100)
        tempZonePoints[#tempZonePoints + 1] = p
        Haze.Client.Notify(string.format("Ponto %d/4 gravado! [%.2f, %.2f, %.2f]", #tempZonePoints, p.x, p.y, p.z), "success")

        if #tempZonePoints == 4 then
            Haze.Client.Notify("4 Pontos gravados! A área foi fechada com sucesso. Verifique o console F8 para copiar o bloco Lua.", "info")
            print("^2[Haze Garages] === Bloco DropZone Formatado (Copie e cole no config.lua) ===^7")
            print("dropZone = {")
            print("    points = {")
            for i = 1, #tempZonePoints do
                print(string.format("        vec3(%.2f, %.2f, %.2f)%s", tempZonePoints[i].x, tempZonePoints[i].y, tempZonePoints[i].z, i == #tempZonePoints and "" or ","))
            end
            print("    },")
            print("    thickness = 6.0")
            print("}")
            print("^2[Haze Garages] ================================================================^7")
        end
    elseif subCmd == "clear" then
        tempZonePoints = {}
        Haze.Client.Notify("Pontos da zona limpos com sucesso.", "info")
    elseif subCmd == "print" then
        if #tempZonePoints < 3 then
            Haze.Client.Notify("Você precisa gravar pelo menos 3 ou 4 pontos (/garagemzone add) para imprimir.", "error")
            return
        end
        print("^2[Haze Garages] === Bloco DropZone Formatado (Copie e cole no config.lua) ===^7")
        print("dropZone = {")
        print("    points = {")
        for i = 1, #tempZonePoints do
            print(string.format("        vec3(%.2f, %.2f, %.2f)%s", tempZonePoints[i].x, tempZonePoints[i].y, tempZonePoints[i].z, i == #tempZonePoints and "" or ","))
        end
        print("    },")
        print("    thickness = 6.0")
        print("}")
        print("^2[Haze Garages] ================================================================^7")
        Haze.Client.Notify("Bloco Lua exibido no console F8!", "success")
    else
        Haze.Client.Notify("Comandos da Zona de 4 Pontos:", "info")
        print("^3[Haze Garages] Guia de Uso: /garagemzone^7")
        print("1. Vá até o 1º canto da vaga e digite: /garagemzone add")
        print("2. Vá até o 2º canto da vaga e digite: /garagemzone add")
        print("3. Vá até o 3º canto da vaga e digite: /garagemzone add")
        print("4. Vá até o 4º canto da vaga e digite: /garagemzone add")
        print("5. Para reiniciar: /garagemzone clear")
        print("6. Para reimprimir no F8: /garagemzone print")
    end
end, false)

-- Renderiza em tempo real as marcações e as linhas conectando os pontos durante a configuração
CreateThread(function()
    while true do
        if #tempZonePoints > 0 then
            local n = #tempZonePoints
            for i = 1, n do
                local p = tempZonePoints[i]
                DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 180, 0, 220, false, false, 2, false, nil, nil, false)
                if n >= 2 then
                    local nextIdx = (i % n) + 1
                    local nextP = tempZonePoints[nextIdx]
                    if n >= 3 or i < n then
                        DrawLine(p.x, p.y, p.z + 0.1, nextP.x, nextP.y, nextP.z + 0.1, 255, 180, 0, 255)
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)





