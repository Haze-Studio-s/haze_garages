-- =================================================================================
-- Haze Garages - Seguradora de Veículos Mors Mutual (Client-side)
-- Detecção de veículos destruídos, menu interativo de sinistros e liberação expressa.
-- =================================================================================

local reportedDestroyed = {}

--- Menu interativo da Seguradora Mors Mutual
local function openInsuranceMenu()
    local vehicles = lib.callback.await("haze_garages:server:getInsuranceVehicles", false)

    if not vehicles or #vehicles == 0 then
        lib.alertDialog({
            header = "🛡️ Seguradora Mors Mutual",
            content = "Você não possui nenhum veículo sinistrado ou com perda total no momento.\n\nSuas apólices estão todas em dia!",
            centered = true,
            cancel = false
        })
        return
    end

    local options = {}

    for _, veh in ipairs(vehicles) do
        local title = string.format("%s [%s]", veh.model, veh.plate)
        if veh.nickname and veh.nickname ~= "" then
            title = string.format("%s - %s [%s]", veh.nickname, veh.model, veh.plate)
        end

        local desc = ""
        local icon = "car-crash"
        local iconColor = "#ef4444"

        if veh.status == "destroyed" then
            desc = string.format("🔴 Perda Total | Franquia: %s%s (15 min) ou Expresso: %s%s (Imediato)", 
                Config.Currency or "$", veh.deductible, Config.Currency or "$", (veh.deductible + veh.expressFee))
        elseif veh.status == "pending" then
            icon = "hourglass-half"
            iconColor = "#f59e0b"
            desc = string.format("🟡 Em Reparo | Faltam aprox. %d minuto(s). Ou libere agora com Guincho Expresso por %s%s", 
                veh.minutesLeft, Config.Currency or "$", veh.expressFee)
        elseif veh.status == "ready" then
            icon = "check-circle"
            iconColor = "#10b981"
            desc = "🟢 Veículo restaurado e pronto para retirada imediata!"
        end

        table.insert(options, {
            title = title,
            description = desc,
            icon = icon,
            iconColor = iconColor,
            onSelect = function()
                if veh.status == "destroyed" then
                    local alert = lib.alertDialog({
                        header = "🛡️ Acionar Sinistro - Mors Mutual",
                        content = string.format(
                            "Veículo: **%s** (Placa: `%s`)\n\n" ..
                            "Escolha a modalidade de resgate da seguradora:\n\n" ..
                            "• **Normal (%s%s)**: Cobertura padrão com carência de 15 minutos para transporte e restauração.\n" ..
                            "• **Expresso (%s%s)**: Guincho de emergência prioritário com liberação imediata sem espera.",
                            veh.model, veh.plate,
                            Config.Currency or "$", veh.deductible,
                            Config.Currency or "$", (veh.deductible + veh.expressFee)
                        ),
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = string.format("⚡ Expresso (%s%s)", Config.Currency or "$", (veh.deductible + veh.expressFee)),
                            cancel = string.format("⏱️ Normal (%s%s)", Config.Currency or "$", veh.deductible)
                        }
                    })

                    if alert == "confirm" then
                        -- Acionamento Expresso
                        local success, res = lib.callback.await("haze_garages:server:claimInsurance", false, veh.plate, true)
                        if success then
                            SetTimeout(500, openInsuranceMenu)
                        end
                    elseif alert == "cancel" then
                        -- Acionamento Normal
                        local success, res = lib.callback.await("haze_garages:server:claimInsurance", false, veh.plate, false)
                        if success then
                            SetTimeout(500, openInsuranceMenu)
                        end
                    end

                elseif veh.status == "pending" then
                    local alert = lib.alertDialog({
                        header = "⏳ Reparo em Andamento",
                        content = string.format(
                            "Veículo: **%s** (Placa: `%s`)\n" ..
                            "Tempo restante de carência: **%d minuto(s)**.\n\n" ..
                            "Deseja pagar a taxa do **Guincho Expresso (%s%s)** para liberar o veículo imediatamente agora?",
                            veh.model, veh.plate, veh.minutesLeft,
                            Config.Currency or "$", veh.expressFee
                        ),
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "⚡ Liberar Imediatamente",
                            cancel = "Aguardar Tempo Normal"
                        }
                    })

                    if alert == "confirm" then
                        local success, res = lib.callback.await("haze_garages:server:claimInsurance", false, veh.plate, true)
                        if success then
                            SetTimeout(500, openInsuranceMenu)
                        end
                    end

                elseif veh.status == "ready" then
                    local success, res = lib.callback.await("haze_garages:server:retrieveInsuranceVehicle", false, veh.plate, "mors_mutual")
                    if success then
                        lib.alertDialog({
                            header = "✅ Veículo Restaurado",
                            content = string.format("Seu veículo [%s] está totalmente novo e foi liberado na **%s**!\n\nVocê já pode retirá-lo da vaga ou usar seu dia a dia.", veh.plate, res.garageLabel or "Garagem Mors Mutual"),
                            centered = true,
                            cancel = false
                        })
                    end
                end
            end
        })
    end

    lib.registerContext({
        id = "mors_mutual_menu",
        title = "🛡️ Seguradora Mors Mutual",
        options = options
    })

    lib.showContext("mors_mutual_menu")
end

--- Comando in-game /seguro
RegisterCommand(Config.Insurance and Config.Insurance.Command or "seguro", function()
    openInsuranceMenu()
end, false)

--- Evento para abrir o menu do seguro
RegisterNetEvent("haze_garages:client:openInsuranceMenu", function()
    openInsuranceMenu()
end)

--- NUI Callback disparado do card do veículo no celular ou NUI
RegisterNUICallback("openInsuranceManager", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })
    SetTimeout(200, function()
        openInsuranceMenu()
    end)
    cb("ok")
end)

--- Monitoramento de veículos destruídos / afundados
CreateThread(function()
    while true do
        Wait(2000)
        local ped = cache.ped or PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, true)

        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local isDead = IsEntityDead(veh)
            local health = GetEntityHealth(veh)
            local engHealth = GetVehicleEngineHealth(veh)
            local inWater = IsEntityInWater(veh)

            local isDestroyed = isDead or (health <= 0) or (engHealth <= -3900)

            -- Se estiver submerso com o capô debaixo d'água
            if inWater and not isDestroyed then
                local coords = GetEntityCoords(veh)
                local retval, waterHeight = GetWaterHeight(coords.x, coords.y, coords.z)
                if retval and (waterHeight > (coords.z + 0.4)) then
                    isDestroyed = true
                end
            end

            if isDestroyed then
                local plate = GetVehicleNumberPlateText(veh)
                local cleanPlate = Haze.Shared.CleanPlate(plate)

                if cleanPlate and not reportedDestroyed[cleanPlate] then
                    reportedDestroyed[cleanPlate] = true
                    TriggerServerEvent("haze_garages:server:reportDestroyedVehicle", cleanPlate)

                    -- Limpa do cache após 60 segundos
                    SetTimeout(60000, function()
                        reportedDestroyed[cleanPlate] = nil
                    end)
                end
            end
        end
    end
end)
