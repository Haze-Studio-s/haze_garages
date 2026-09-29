local spawnedGarageProps = {}

AddEventHandler("haze_garages:client:init", function()
    for id, prop in ipairs(spawnedGarageProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    spawnedGarageProps = {}

    for garageId, garageData in pairs(Config.FixedGarages or {}) do
        local propModel = Config.GarageTerminalProp or "prop_parkstat_01"
        lib.requestModel(propModel)

        local prop = CreateObject(joaat(propModel), garageData.coords.x, garageData.coords.y, garageData.coords.z - 1.0, false, false, false)
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
    lib.requestModel(payload.model)

    local veh = CreateVehicle(joaat(payload.model), coords.x, coords.y, coords.z, coords.w, true, false)
    SetVehicleNumberPlateText(veh, payload.plate)

    if payload.mods then
        if exports.qbx_core then
            exports.qbx_core:setVehicleProperties(veh, payload.mods)
        elseif exports['qb-core'] then
            exports['qb-core']:GetCoreObject().Functions.SetVehicleProperties(veh, payload.mods)
        end
    end

    if payload.deformation or payload.mechanical then
        TriggerEvent("haze_garages:client:applyVehicleDeformation", veh, payload.deformation, payload.mechanical)
    end

    TaskWarpPedIntoVehicle(cache.ped or PlayerPedId(), veh, -1)
    Haze.Client.Notify(Locale.vehicle_spawned, "success")
end)
