lib.callback.register("haze_garages:server:payParkingMeter", function(source, meterKey, hours)
    local src = source
    hours = tonumber(hours) or 1
    if hours <= 0 then return false, "Quantidade de horas inválida." end

    local totalCost = (Config.ParkingMeterPricePerHour or 50) * hours
    local playerMoney = Haze.Server.GetMoney(src)
    if playerMoney < totalCost then
        return false, string.format(Locale.no_money, Config.Currency, totalCost)
    end

    if not Haze.Server.RemoveMoney(src, totalCost) then
        return false, string.format(Locale.no_money, Config.Currency, totalCost)
    end

    local row = MySQL.single.await("SELECT * FROM haze_parking_meters WHERE meter_key = ?", { meterKey })
    local currentHours = row and row.hours_left or 0
    local newHours = currentHours + hours

    MySQL.query([[
        REPLACE INTO haze_parking_meters (meter_key, hours_left, expires_at)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], { meterKey, newHours, newHours })

    local msg = string.format(Locale.meter_paid, hours, Config.Currency, totalCost)
    Haze.Server.Notify(src, msg, "success")

    TriggerClientEvent("haze_garages:client:syncParkingMeter", -1, meterKey, newHours)
    return true
end)

lib.callback.register("haze_garages:server:getParkingMeterStatus", function(source, meterKey)
    local row = MySQL.single.await("SELECT * FROM haze_parking_meters WHERE meter_key = ?", { meterKey })
    if row then
        return row.hours_left
    end
    return 0
end)
