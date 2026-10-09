local spawnedGaragePeds = {}

local function cleanupGaragePeds()
    for _, ped in ipairs(spawnedGaragePeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedGaragePeds = {}
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        cleanupGaragePeds()
    end
end)

AddEventHandler("haze_garages:client:init", function()
    cleanupGaragePeds()

    for garageId, garageData in pairs(Config.FixedGarages or {}) do
        local pedModel = garageData.pedModel or Config.GaragePedModel or "a_m_y_business_01"
        local pedHash = Haze.Shared.GetModelHash(pedModel)

        if pedHash and Haze.Client.RequestModel(pedHash) then
            local ped = CreatePed(4, pedHash, garageData.coords.x, garageData.coords.y, garageData.coords.z - 1.0, garageData.coords.w or 0.0, false, false)
            SetEntityHeading(ped, garageData.coords.w or 0.0)
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
                        name = "haze_garage_" .. garageId,
                        icon = "fas fa-warehouse",
                        label = garageData.label,
                        onSelect = function()
                            TriggerEvent("haze_garages:client:openGarageMenu", garageId)
                        end
                    }
                })
            else
                lib.points.new({
                    coords = vec3(garageData.coords.x, garageData.coords.y, garageData.coords.z),
                    distance = 3.0,
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
            end
        end
    end
end)


RegisterNetEvent("haze_garages:client:openGarageMenu", function(garageId)
    local garage = Config.FixedGarages[garageId]
    if not garage then return end

    local vehicles = lib.callback.await("haze_garages:server:getUserVehicles", false, garageId)
    if not vehicles or #vehicles == 0 then
        Haze.Client.Notify("Você não possui veículos nesta garagem.", "warning")
        return
    end

    local nuiVehicles = {}
    for _, v in ipairs(vehicles) do
        local plate = v.plate
        local model = v.vehicle or v.model or "Desconhecido"
        
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
            engine = v.engine or 1000,
            body = v.body or 1000,
            fuel = v.fuel or 100,
            wear = wearInfo and wearInfo.wear or nil
        }
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openGarage",
        title = garage.label,
        garageId = garageId,
        vehicles = nuiVehicles
    })
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("spawnVehicle", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })
    TriggerEvent("haze_garages:client:spawnVehicle", data.plate, data.garageId)
    cb("ok")
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

    local currentPed = cache.ped or PlayerPedId()
    local currentPedCoords = GetEntityCoords(currentPed)
    local spawnCoords = payload.spawnCoords or vec4(currentPedCoords.x + 2.0, currentPedCoords.y + 2.0, currentPedCoords.z, GetEntityHeading(currentPed))

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

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openVehicleList",
        title = "🚗 Meus Veículos",
        vehicles = nuiVehicles
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

