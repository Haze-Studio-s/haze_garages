local function isPolice(src)
    local job = Haze.Server.GetPlayerJob(src)
    for _, pJob in ipairs(Config.PoliceJobs or { "police", "sheriff" }) do
        if job == pJob then return true end
    end
    return false
end

lib.callback.register("haze_garages:server:getActiveMeters", function(source)
    local rows = MySQL.query.await([[
        SELECT meter_key, payer_name, payer_phone, TIMESTAMPDIFF(MINUTE, NOW(), expires_at) AS mins_left
        FROM haze_parking_meters
        WHERE expires_at > NOW()
    ]])

    local result = {}
    for _, row in ipairs(rows or {}) do
        if row.mins_left and row.mins_left > 0 then
            result[row.meter_key] = {
                paid = true,
                minsLeft = row.mins_left,
                payerName = row.payer_name or "Desconhecido",
                payerPhone = row.payer_phone or "N/A"
            }
        end
    end
    return result
end)

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

    local citizenid = Haze.Server.GetPlayerIdentifier(src)
    local payerName = Haze.Server.GetPlayerFullName(src)
    local payerPhone = Haze.Server.GetPlayerPhone(src)

    local row = MySQL.single.await("SELECT * FROM haze_parking_meters WHERE meter_key = ?", { meterKey })
    local currentHours = row and row.hours_left or 0
    local newHours = currentHours + hours

    MySQL.query([[
        REPLACE INTO haze_parking_meters (meter_key, hours_left, expires_at, payer_name, payer_phone, citizenid)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR), ?, ?, ?)
    ]], { meterKey, newHours, newHours, payerName, payerPhone, citizenid })

    local ticketItem = Config.ParkingTicketItem or "parking_ticket"
    local cleanPlate = vehiclePlate and Haze.Shared.CleanPlate(vehiclePlate) or "SEM PLACA"

    if GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            exports.ox_inventory:AddItem(src, ticketItem, 1, {
                plate = cleanPlate,
                meterKey = meterKey,
                hours = hours,
                paid_by = payerName,
                payer_phone = payerPhone,
                description = string.format("Ticket Parquímetro | Placa: %s | Pagador: %s (%s) | %d Hora(s)", cleanPlate, payerName, payerPhone, hours)
            })
        end)
    end

    local msg = string.format(Locale.meter_paid, hours, Config.Currency, totalCost)
    Haze.Server.Notify(src, msg, "success")

    local minsLeft = newHours * 60
    TriggerClientEvent("haze_garages:client:syncParkingMeter", -1, meterKey, {
        paid = true,
        minsLeft = minsLeft,
        payerName = payerName,
        payerPhone = payerPhone
    })
    return true
end)

lib.callback.register("haze_garages:server:policeInspectMeter", function(source, meterKey)
    local src = source
    if not isPolice(src) then return false, Locale.no_permission end

    local row = MySQL.single.await("SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), expires_at) as mins_left FROM haze_parking_meters WHERE meter_key = ?", { meterKey })
    if not row or not row.mins_left or row.mins_left <= 0 then
        return true, {
            expired = true,
            message = "⚠️ Parquímetro VENCIDO ou NÃO PAGO!\nNenhum comprovante ativo nesta vaga."
        }
    end

    local hoursLeft = math.ceil(row.mins_left / 60)
    local payerName = row.payer_name or "Não registrado"
    local payerPhone = row.payer_phone or "Não informado"

    local msg = string.format(
        "📋 Fiscalização de Parquímetro\nStatus: VÁLIDO\nTempo Restante: %d min (~%dh)\nPagador: %s\nTelefone: %s",
        row.mins_left,
        hoursLeft,
        payerName,
        payerPhone
    )

    return true, {
        expired = false,
        minsLeft = row.mins_left,
        hoursLeft = hoursLeft,
        payerName = payerName,
        payerPhone = payerPhone,
        message = msg
    }
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

