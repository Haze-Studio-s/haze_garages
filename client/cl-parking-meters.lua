local spawnedCustomMeters = {}
local activeMetersCache = {}

RegisterNetEvent("haze_garages:client:syncParkingMeter", function(meterKey, data)
    if type(data) == "table" then
        activeMetersCache[meterKey] = data
    else
        activeMetersCache[meterKey] = { paid = true, minsLeft = (tonumber(data) or 1) * 60 }
    end
end)

local function getMeterKeyForEntity(entity)
    if not entity or not DoesEntityExist(entity) then return "meter_unknown" end
    local coords = GetEntityCoords(entity)
    return string.format("native_meter_%.2f_%.2f", coords.x, coords.y)
end

local function inspectMeterWithProgressBar(meterKey)
    local animDict = "amb@world_human_clipboard@male@base"
    lib.requestAnimDict(animDict)

    local completed = lib.progressBar({
        duration = 3000,
        label = "Fiscalizando Parquímetro...",
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = animDict,
            clip = "base"
        }
    })

    if not completed then
        Haze.Client.Notify("Fiscalização cancelada.", "warning")
        return
    end

    local success, res = lib.callback.await("haze_garages:server:policeInspectMeter", false, meterKey)
    if success and res then
        lib.notify({
            title = "📋 Relatório de Fiscalização",
            description = res.message,
            type = res.expired and "error" or "success",
            duration = 10000
        })
    end
end

local function setupMeterTarget(entity, meterKey)
    if exports.ox_target then
        exports.ox_target:addLocalEntity(entity, {
            {
                name = "haze_meter_status_" .. meterKey,
                icon = "fas fa-info-circle",
                label = "Ver Status do Parquímetro",
                onSelect = function()
                    local data = activeMetersCache[meterKey]
                    if data and data.paid and data.minsLeft > 0 then
                        lib.notify({
                            title = "🟢 Parquímetro PAGO",
                            description = string.format("Tempo Restante: %d min\nPagador: %s\nContato: %s", data.minsLeft, data.payerName or "N/A", data.payerPhone or "N/A"),
                            type = "success",
                            duration = 8000
                        })
                    else
                        lib.notify({
                            title = "🔴 Parquímetro NÃO PAGO",
                            description = "Esta vaga não possui comprovante ativo ou o tempo expirou.",
                            type = "error",
                            duration = 8000
                        })
                    end
                end
            },
            {
                name = "haze_meter_pay1h_" .. meterKey,
                icon = "fas fa-parking",
                label = "Pagar Parquímetro (1h - R$ " .. Config.ParkingMeterPricePerHour .. ")",
                onSelect = function()
                    local veh = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
                    local plate = (veh and veh ~= 0) and GetVehicleNumberPlateText(veh) or nil
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 1, plate)
                end
            },
            {
                name = "haze_meter_pay10h_" .. meterKey,
                icon = "fas fa-clock",
                label = "Pagar Parquímetro (10h - R$ " .. (Config.ParkingMeterPricePerHour * 10) .. ")",
                onSelect = function()
                    local veh = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
                    local plate = (veh and veh ~= 0) and GetVehicleNumberPlateText(veh) or nil
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 10, plate)
                end
            },
            {
                name = "haze_meter_police_" .. meterKey,
                icon = "fas fa-shield-alt",
                label = "Fiscalizar Parquímetro (Polícia)",
                groups = Config.PoliceJobs or { "police", "sheriff" },
                onSelect = function()
                    inspectMeterWithProgressBar(meterKey)
                end
            }
        })
    end
end

AddEventHandler("haze_garages:client:init", function()
    for _, obj in ipairs(spawnedCustomMeters) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawnedCustomMeters = {}

    local initialMeters = lib.callback.await("haze_garages:server:getActiveMeters", false)
    if initialMeters then
        activeMetersCache = initialMeters
    end

    for i, meter in ipairs(Config.CustomParkingMeters or {}) do
        local modelHash = Haze.Shared.GetModelHash(meter.model)
        Haze.Client.RequestModel(modelHash)
        local obj = CreateObject(modelHash, meter.coords.x, meter.coords.y, meter.coords.z, false, false, false)
        SetEntityHeading(obj, meter.coords.w or 0.0)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        spawnedCustomMeters[#spawnedCustomMeters + 1] = obj

        local meterKey = string.format("custom_meter_%d", i)
        setupMeterTarget(obj, meterKey)
    end

    if exports.ox_target and Config.NativeParkingMeterModels then
        exports.ox_target:addModel(Config.NativeParkingMeterModels, {
            {
                name = "haze_native_meter_status",
                icon = "fas fa-info-circle",
                label = "Ver Status do Parquímetro",
                onSelect = function(data)
                    local meterKey = getMeterKeyForEntity(data.entity)
                    local meterData = activeMetersCache[meterKey]
                    if meterData and meterData.paid and meterData.minsLeft > 0 then
                        lib.notify({
                            title = "🟢 Parquímetro PAGO",
                            description = string.format("Tempo Restante: %d min\nPagador: %s\nContato: %s", meterData.minsLeft, meterData.payerName or "N/A", meterData.payerPhone or "N/A"),
                            type = "success",
                            duration = 8000
                        })
                    else
                        lib.notify({
                            title = "🔴 Parquímetro NÃO PAGO",
                            description = "Esta vaga não possui comprovante ativo ou o tempo expirou.",
                            type = "error",
                            duration = 8000
                        })
                    end
                end
            },
            {
                name = "haze_native_meter_1h",
                icon = "fas fa-parking",
                label = "Pagar Parquímetro (1h - R$ " .. Config.ParkingMeterPricePerHour .. ")",
                onSelect = function(data)
                    local meterKey = getMeterKeyForEntity(data.entity)
                    local veh = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
                    local plate = (veh and veh ~= 0) and GetVehicleNumberPlateText(veh) or nil
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 1, plate)
                end
            },
            {
                name = "haze_native_meter_10h",
                icon = "fas fa-clock",
                label = "Pagar Parquímetro (10h - R$ " .. (Config.ParkingMeterPricePerHour * 10) .. ")",
                onSelect = function(data)
                    local meterKey = getMeterKeyForEntity(data.entity)
                    local veh = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
                    local plate = (veh and veh ~= 0) and GetVehicleNumberPlateText(veh) or nil
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 10, plate)
                end
            },
            {
                name = "haze_native_meter_police",
                icon = "fas fa-shield-alt",
                label = "Fiscalizar Parquímetro (Polícia)",
                groups = Config.PoliceJobs or { "police", "sheriff" },
                onSelect = function(data)
                    local meterKey = getMeterKeyForEntity(data.entity)
                    inspectMeterWithProgressBar(meterKey)
                end
            }
        })

        exports.ox_target:addGlobalVehicle({
            {
                name = "haze_police_fine_vehicle",
                icon = "fas fa-file-invoice-dollar",
                label = "Multar Estacionamento Irregular",
                groups = Config.PoliceJobs or { "police", "sheriff" },
                onSelect = function(data)
                    local plate = GetVehicleNumberPlateText(data.entity)
                    local success, msg = lib.callback.await("haze_garages:server:policeFineOwner", false, plate)
                    if not success then
                        Haze.Client.Notify(msg or "Erro ao aplicar multa.", "error")
                    end
                end
            }
        })
    end
end)

