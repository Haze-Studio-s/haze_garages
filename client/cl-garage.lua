local spawnedGarageProps = {}

AddEventHandler("haze_garages:client:init", function()
    for id, prop in ipairs(spawnedGarageProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    spawnedGarageProps = {}

    for garageId, garageData in pairs(Config.FixedGarages or {}) do
        local propModel = Config.GarageTerminalProp or "prop_parkstat_01"
        local propHash = Haze.Shared.GetModelHash(propModel)
        Haze.Client.RequestModel(propHash)

        local prop = CreateObject(propHash, garageData.coords.x, garageData.coords.y, garageData.coords.z - 1.0, false, false, false)
        SetEntityHeading(prop, garageData.coords.w or 0.0)
        FreezeEntityPosition(prop, true)
        SetEntityInvincible(prop, true)
        spawnedGarageProps[#spawnedGarageProps + 1] = prop

        if exports.ox_target then
            exports.ox_target:addLocalEntity(prop, {
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

RegisterNetEvent("haze_garages:client:spawnVehicle", function(plate, garageId)
    local success, payload = lib.callback.await("haze_garages:server:spawnVehicle", false, plate, garageId)
    if not success then
        Haze.Client.Notify(payload or Locale.spawn_blocked, "error")
        return
    end

    local coords = payload.spawnCoords
    local modelHash = Haze.Shared.GetModelHash(payload.model)
    Haze.Client.RequestModel(modelHash)

    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.w, true, false)
    SetVehicleNumberPlateText(veh, payload.plate)

    if payload.mods then
        Haze.Client.SetVehicleProperties(veh, payload.mods)
    end

    if payload.deformation or payload.mechanical then
        TriggerEvent("haze_garages:client:applyVehicleDeformation", veh, payload.deformation, payload.mechanical)
    end

    TaskWarpPedIntoVehicle(cache.ped or PlayerPedId(), veh, -1)
    Haze.Client.Notify(Locale.vehicle_spawned, "success")
end)

RegisterCommand("listarveiculos", function()
    local vehicles = lib.callback.await("haze_garages:server:getDetailedPlayerVehicles", false)
    if not vehicles or #vehicles == 0 then
        Haze.Client.Notify("Você não possui nenhum veículo cadastrado.", "info")
        return
    end

    local options = {}

    local ped = cache.ped or PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    for _, v in ipairs(vehicles) do
        local isStreetVehicle = (v.spawnType == "street" and v.streetCoords)
        local distToStreetSpot = isStreetVehicle and #(pedCoords - vec3(v.streetCoords.x, v.streetCoords.y, v.streetCoords.z)) or 999999.0
        local isNearStreetSpot = (isStreetVehicle and distToStreetSpot <= 30.0)

        local metadata = {
            { label = "Placa", value = v.plate },
            { label = "Status", value = v.statusLabel },
            { label = "Motor", value = string.format("%.0f%%", (v.engineHealth / 10) or 100) },
            { label = "Lataria", value = string.format("%.0f%%", (v.bodyHealth / 10) or 100) },
            { label = "Combustível", value = string.format("%.0f%%", v.fuel or 100) },
            { label = "Quilometragem", value = string.format("%.1f", v.mileage or 0) }
        }

        if v.wearData and type(v.wearData) == "table" then
            for part, val in pairs(v.wearData) do
                table.insert(metadata, {
                    label = "Peça " .. string.upper(part),
                    value = string.format("%.0f%%", val)
                })
            end
        end

        local desc = string.format("📍 Status: **%s**\n🔧 Motor: %d%% | Lataria: %d%%", 
            v.statusLabel, 
            math.floor(v.engineHealth / 10), 
            math.floor(v.bodyHealth / 10)
        )

        local icon = isStreetVehicle and "fas fa-road" or "fas fa-car"

        table.insert(options, {
            title = string.upper(v.model) .. " [" .. v.plate .. "]",
            description = desc,
            metadata = metadata,
            icon = icon,
            disabled = not v.isSpawnable,
            onSelect = function()
                if isStreetVehicle and not isNearStreetSpot then
                    SetNewWaypoint(v.streetCoords.x, v.streetCoords.y)
                    Haze.Client.Notify(string.format("Localização do veículo %s marcada no GPS! Vá até o local para retirá-lo.", string.upper(v.model)), "info")
                    return
                end

                if not v.isSpawnable then
                    Haze.Client.Notify("Este veículo não pode ser retirado agora (" .. v.statusLabel .. ").", "error")
                    return
                end

                local confirm = lib.alertDialog({
                    header = "Retirar Veículo",
                    content = string.format("Deseja retirar o veículo **%s** [%s]?\n\nLocalização atual: **%s**", string.upper(v.model), v.plate, v.statusLabel),
                    centered = true,
                    cancel = true,
                    labels = { confirm = "Retirar / Spawn", cancel = "Cancelar" }
                })

                if confirm == "confirm" then
                    local success, payload = lib.callback.await("haze_garages:server:unparkOrSpawnVehicle", false, v.plate)
                    if not success then
                        Haze.Client.Notify(payload or "Erro ao retirar veículo.", "error")
                        return
                    end

                    local currentPed = cache.ped or PlayerPedId()
                    local currentPedCoords = GetEntityCoords(currentPed)

                    local spawnCoords = payload.spawnCoords or vec4(currentPedCoords.x + 2.0, currentPedCoords.y + 2.0, currentPedCoords.z, GetEntityHeading(currentPed))
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

                    local distToPed = #(currentPedCoords - vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z))
                    if distToPed < 15.0 then
                        TaskWarpPedIntoVehicle(currentPed, veh, -1)
                    end

                    Haze.Client.Notify("Veículo retirado com sucesso!", "success")
                end
            end
        })
    end

    lib.registerContext({
        id = "haze_garages_list_vehicles",
        title = "🚗 Meus Veículos",
        options = options
    })

    lib.showContext("haze_garages_list_vehicles")
end, false)
