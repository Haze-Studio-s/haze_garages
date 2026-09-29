local function isPolice(src)
    local job = Haze.Server.GetPlayerJob(src)
    for _, pJob in ipairs(Config.PoliceJobs or { "police", "sheriff" }) do
        if job == pJob then return true end
    end
    return false
end

lib.callback.register("haze_garages:server:payParkingMeter", function(source, meterKey, hours, vehiclePlate)
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

    local ticketItem = Config.ParkingTicketItem or "parking_ticket"
    local cleanPlate = vehiclePlate and Haze.Shared.CleanPlate(vehiclePlate) or "SEM PLACA"

    if GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            exports.ox_inventory:AddItem(src, ticketItem, 1, {
                plate = cleanPlate,
                meterKey = meterKey,
                hours = newHours,
                description = string.format("Ticket Válido por %d hora(s) | Placa: %s", newHours, cleanPlate)
            })
        end)
    end

    local msg = string.format(Locale.meter_paid, hours, Config.Currency, totalCost)
    Haze.Server.Notify(src, msg, "success")

    TriggerClientEvent("haze_garages:client:syncParkingMeter", -1, meterKey, newHours)
    return true
end)

lib.callback.register("haze_garages:server:policeInspectMeter", function(source, meterKey)
    local src = source
    if not isPolice(src) then return false, Locale.no_permission end

    local row = MySQL.single.await("SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), expires_at) as mins_left FROM haze_parking_meters WHERE meter_key = ?", { meterKey })
    if not row or not row.mins_left or row.mins_left <= 0 then
        return true, { expired = true, message = Locale.police_inspect_expired }
    end

    local hoursLeft = math.ceil(row.mins_left / 60)
    return true, { expired = false, message = string.format(Locale.police_inspect_valid, hoursLeft) }
end)

lib.callback.register("haze_garages:server:policeFineOwner", function(source, plate)
    local src = source
    if not isPolice(src) then return false, Locale.no_permission end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local ownerRow = MySQL.single.await("SELECT citizenid FROM player_vehicles WHERE plate = ?", { cleanPlate })
    if not ownerRow then
        ownerRow = MySQL.single.await("SELECT citizenid FROM haze_street_parking WHERE plate = ?", { cleanPlate })
    end

    if not ownerRow or not ownerRow.citizenid then
        return false, "Proprietário do veículo não foi localizado no sistema."
    end

    local fineAmount = Config.PoliceFineAmount or 500

    if exports.qbx_core then
        local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(ownerRow.citizenid)
        if targetPlayer then
            targetPlayer.Functions.RemoveMoney('bank', fineAmount, "multa-parquimetro-vencido")
        end
    end

    local msg = string.format(Locale.police_fine_issued, Config.Currency, fineAmount, cleanPlate)
    Haze.Server.Notify(src, msg, "success")
    return true
end)
