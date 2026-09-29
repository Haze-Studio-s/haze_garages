local spawnedCustomMeters = {}

local function setupMeterTarget(entity, meterKey)
    if exports.ox_target then
        exports.ox_target:addLocalEntity(entity, {
            {
                name = "haze_meter_" .. meterKey,
                icon = "fas fa-parking",
                label = "Pagar Parquímetro (1h - R$ " .. Config.ParkingMeterPricePerHour .. ")",
                onSelect = function()
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 1)
                end
            },
            {
                name = "haze_meter_10h_" .. meterKey,
                icon = "fas fa-clock",
                label = "Pagar Parquímetro (10h - R$ " .. (Config.ParkingMeterPricePerHour * 10) .. ")",
                onSelect = function()
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 10)
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

    for i, meter in ipairs(Config.CustomParkingMeters or {}) do
        lib.requestModel(meter.model)
        local obj = CreateObject(joaat(meter.model), meter.coords.x, meter.coords.y, meter.coords.z - 1.0, false, false, false)
        SetEntityHeading(obj, meter.coords.w or 0.0)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        spawnedCustomMeters[#spawnedCustomMeters + 1] = obj

        local meterKey = string.format("custom_meter_%d", i)
        setupMeterTarget(obj, meterKey)
    end

    if exports.ox_target and Config.NativeParkingMeterModels then
        exports.ox_target:addModel(Config.NativeParkingMeterModels, {
            {
                name = "haze_native_meter_1h",
                icon = "fas fa-parking",
                label = "Pagar Parquímetro (1h)",
                onSelect = function(data)
                    local eCoords = GetEntityCoords(data.entity)
                    local meterKey = string.format("native_meter_%.2f_%.2f", eCoords.x, eCoords.y)
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 1)
                end
            },
            {
                name = "haze_native_meter_10h",
                icon = "fas fa-clock",
                label = "Pagar Parquímetro (10h)",
                onSelect = function(data)
                    local eCoords = GetEntityCoords(data.entity)
                    local meterKey = string.format("native_meter_%.2f_%.2f", eCoords.x, eCoords.y)
                    lib.callback("haze_garages:server:payParkingMeter", false, function(success) end, meterKey, 10)
                end
            }
        })
    end
end)
