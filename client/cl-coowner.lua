-- =================================================================================
-- Haze Garages - Sistema de Coproprietário / Condutor Autorizado (Client-side)
-- Interface interativa para gerenciar condutores autorizados de veículos próprios ($1.000).
-- =================================================================================

local function openCoOwnerDialog(plate)
    if not plate or plate == "" then
        Haze.Client.Notify("Placa inválida.", "error")
        return
    end

    local cleanPlate = Haze.Shared.CleanPlate(plate)
    local res = lib.callback.await("haze_garages:server:getVehicleCoOwner", false, cleanPlate)

    if not res or not res.success then
        Haze.Client.Notify("Não foi possível carregar as informações deste veículo.", "error")
        return
    end

    if not res.isOwner then
        if res.coowner then
            lib.alertDialog({
                header = "👥 Condutor Autorizado",
                content = string.format("Você é o condutor autorizado deste veículo (Placa: **%s**). Apenas o proprietário registrado pode alterar as permissões.", cleanPlate),
                centered = true,
                cancel = false
            })
        else
            Haze.Client.Notify("Apenas o proprietário legítimo deste veículo pode gerenciar condutores autorizados.", "error")
        end
        return
    end

    -- Se o veículo já possui um coproprietário cadastrado
    if res.coowner then
        local co = res.coowner
        local alert = lib.alertDialog({
            header = "👥 Condutor Autorizado Ativo",
            content = string.format(
                "Veículo: **%s**\nCondutor Autorizado: **%s**\nIdentificador: `%s`\n\nEssa pessoa tem permissão total para retirar e guardar seu veículo na garagem mesmo quando você estiver offline.",
                cleanPlate, co.coowner_name or "Desconhecido", co.coowner_citizenid or "N/A"
            ),
            centered = true,
            cancel = true,
            labels = {
                confirm = "❌ Revogar Autorização",
                cancel = "Voltar"
            }
        })

        if alert == "confirm" then
            local success, msg = lib.callback.await("haze_garages:server:removeVehicleCoOwner", false, cleanPlate)
            if success then
                Haze.Client.Notify(msg or "Autorização revogada com sucesso.", "success")
            else
                Haze.Client.Notify(msg or "Erro ao revogar autorização.", "error")
            end
        end
        return
    end

    -- Se o veículo NÃO possui coproprietário (Cadastrar novo por $1.000)
    local input = lib.inputDialog("👥 Cadastrar Condutor Autorizado", {
        {
            type = "input",
            label = "ID do Jogador ou Passaporte",
            description = string.format("Permite que esta pessoa retire e guarde o veículo (%s) na garagem a qualquer momento. Taxa única: %s%s", cleanPlate, Config.Currency or "$", res.fee or 1000),
            placeholder = "Ex: 1, 2 ou QBX1234",
            required = true
        }
    })

    if not input or not input[1] then return end

    local targetIdentifier = input[1]
    local success, payload = lib.callback.await("haze_garages:server:setVehicleCoOwner", false, cleanPlate, targetIdentifier)
    if not success then
        Haze.Client.Notify(payload or "Erro ao cadastrar condutor autorizado.", "error")
    else
        Haze.Client.Notify(string.format("Condutor autorizado %s cadastrado com sucesso!", payload.coownerName or "amigo"), "success")
    end
end

--- NUI Callback disparado do card do veículo
RegisterNUICallback("openCoOwnerManager", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeGarage" })
    if data and data.plate then
        SetTimeout(200, function()
            openCoOwnerDialog(data.plate)
        end)
    end
    cb("ok")
end)

--- Evento para abrir o gerenciador de condutores autorizados
RegisterNetEvent("haze_garages:client:openCoOwnerManager", function(plate)
    openCoOwnerDialog(plate)
end)

--- Comando in-game /condutor [placa]
RegisterCommand(Config.CoOwnerCommand or "condutor", function(source, args)
    local targetPlate = nil
    if args and args[1] then
        targetPlate = string.upper(table.concat(args, " "))
    else
        local ped = cache.ped or PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if not veh or veh == 0 then
            veh = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, true)
        end

        if veh and veh ~= 0 and DoesEntityExist(veh) then
            targetPlate = GetVehicleNumberPlateText(veh)
        end
    end

    if not targetPlate then
        Haze.Client.Notify("Você precisa estar dentro de um veículo ou informar a placa: /condutor [placa]", "error")
        return
    end

    openCoOwnerDialog(targetPlate)
end, false)
