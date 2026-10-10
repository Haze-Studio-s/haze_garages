-- =================================================================================
-- Haze Garages - Sistema de Manobrista NPC Valet (Client-side)
-- Responsável pela criação do NPC, condução autônoma defensiva, encostamento no meio-fio,
-- descida do veículo e animação de entrega das chaves em mãos.
-- =================================================================================

local isValetInProgress = false
local currentValetPed = nil
local currentValetVeh = nil
local currentValetBlip = nil

--- Seleciona a vaga de saída mais livre da lista de vagas
local function getBestValetSpawnCoords(spawnData)
    if not spawnData then
        local pCoords = GetEntityCoords(cache.ped or PlayerPedId())
        return vec4(pCoords.x + 3.0, pCoords.y + 3.0, pCoords.z, GetEntityHeading(cache.ped or PlayerPedId()))
    end

    if spawnData.x and not spawnData[1] then
        return spawnData
    end

    for _, spot in ipairs(spawnData) do
        local checkVec = vec3(spot.x, spot.y, spot.z)
        local isOccupied = IsPositionOccupied(checkVec.x, checkVec.y, checkVec.z, 2.5, false, true, false, false, false, 0, false)
        if not isOccupied then
            local closest = lib.getClosestVehicle(checkVec, 2.5, true)
            if not closest or closest == 0 then
                return spot
            end
        end
    end

    return spawnData[1]
end

--- Limpa qualquer instância ativa de valet em caso de erro ou cancelamento
local function cleanupCurrentValet(returnToGarage, plate)
    if currentValetBlip and DoesBlipExist(currentValetBlip) then
        RemoveBlip(currentValetBlip)
        currentValetBlip = nil
    end

    if currentValetPed and DoesEntityExist(currentValetPed) then
        SetPedAsNoLongerNeeded(currentValetPed)
        currentValetPed = nil
    end

    if returnToGarage and currentValetVeh and DoesEntityExist(currentValetVeh) then
        DeleteEntity(currentValetVeh)
        currentValetVeh = nil
    end

    if isValetInProgress then
        isValetInProgress = false
        if plate then
            TriggerServerEvent("haze_garages:server:valetCancelled", plate, returnToGarage)
        end
    end
end

--- Inicia o ciclo de entrega do Valet com condução defensiva do NPC
RegisterNetEvent("haze_garages:client:requestValet", function(plate)
    if isValetInProgress then
        Haze.Client.Notify(Locale.valet_already_active or "Você já possui um manobrista a caminho!", "warning")
        return
    end

    local playerPed = cache.ped or PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        Haze.Client.Notify("Você precisa estar fora de qualquer veículo para solicitar o manobrista.", "error")
        return
    end

    local playerCoords = GetEntityCoords(playerPed)

    -- Solicita a liberação autoritativa no servidor
    local success, payload = lib.callback.await("haze_garages:server:requestValet", false, plate, playerCoords)
    if not success then
        Haze.Client.Notify(payload or "Erro ao solicitar o manobrista.", "error")
        return
    end

    isValetInProgress = true

    Haze.Client.Notify(string.format(
        Locale.valet_requested or "Manobrista contratado por %s%s! Ele está retirando seu veículo na garagem %s e dirigindo até você.",
        Config.Currency or "$",
        payload.fee or 150,
        payload.garageLabel or "Central"
    ), "info")

    CreateThread(function()
        local spawnCoords = getBestValetSpawnCoords(payload.spawnCoords)

        -- Carrega modelo do veículo
        local vehModelHash = Haze.Shared.GetModelHash(payload.model)
        if not vehModelHash or not Haze.Client.RequestModel(vehModelHash) then
            Haze.Client.Notify("Erro ao carregar o modelo do veículo.", "error")
            cleanupCurrentValet(true, payload.plate)
            return
        end

        -- Carrega modelo do Ped Manobrista
        local pedModelName = Config.ValetPedModel or "s_m_m_valet_01"
        local pedModelHash = GetHashKey(pedModelName)
        if not Haze.Client.RequestModel(pedModelHash) then
            Haze.Client.Notify("Erro ao carregar modelo do manobrista.", "error")
            cleanupCurrentValet(true, payload.plate)
            return
        end

        -- Spawna o veículo
        local veh = CreateVehicle(vehModelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0, true, false)
        currentValetVeh = veh
        SetVehicleNumberPlateText(veh, payload.plate)

        -- Aplica modificações e dados mecânicos salvos
        if payload.mods then
            Haze.Client.SetVehicleProperties(veh, payload.mods)
        end

        if payload.deformation or payload.mechanical then
            TriggerEvent("haze_garages:client:applyVehicleDeformation", veh, payload.deformation, payload.mechanical)
        end

        -- Tranca portas para evitar furtos durante a rota do manobrista
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleEngineOn(veh, true, true, false)

        -- Spawna o Manobrista NPC
        local valetPed = CreatePed(4, pedModelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.0, spawnCoords.w or 0.0, true, false)
        currentValetPed = valetPed

        SetPedIntoVehicle(valetPed, veh, -1)
        SetPedCanRagdoll(valetPed, false)
        SetPedCombatAttributes(valetPed, 17, true)
        SetPedFleeAttributes(valetPed, 0, false)
        SetBlockingOfNonTemporaryEvents(valetPed, true)
        SetDriverAbility(valetPed, 1.0)
        SetDriverAggressiveness(valetPed, 0.0)
        SetPedKeepTask(valetPed, true)

        -- Blip do Valet no mapa
        local blip = AddBlipForEntity(veh)
        currentValetBlip = blip
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 5) -- Amarelo
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format(Locale.valet_blip_label or "Valet a Caminho: %s", payload.plate))
        EndTextCommandSetBlipName(blip)

        local startTime = GetGameTimer()
        local timeoutMs = (Config.ValetTimeoutSeconds or 180) * 1000

        -- Loop de condução até a proximidade do jogador
        local arrivedNearPlayer = false
        while isValetInProgress and DoesEntityExist(valetPed) and DoesEntityExist(veh) do
            local curPlayerCoords = GetEntityCoords(cache.ped or PlayerPedId())
            local vehCoords = GetEntityCoords(veh)
            local distToPlayer = #(vehCoords - curPlayerCoords)

            -- Verifica se chegou na proximidade (raio de 18 metros)
            if distToPlayer <= 18.0 then
                arrivedNearPlayer = true
                break
            end

            -- Verifica timeout de segurança
            if GetGameTimer() - startTime > timeoutMs then
                break
            end

            -- Obtém o nó de pista mais próximo do jogador para navegar
            local hasNode, nodeCoords = GetClosestVehicleNodeWithHeading(curPlayerCoords.x, curPlayerCoords.y, curPlayerCoords.z, 1, 3.0, 0)
            local targetPos = hasNode and nodeCoords or curPlayerCoords

            TaskVehicleDriveToCoordLongrange(
                valetPed,
                veh,
                targetPos.x,
                targetPos.y,
                targetPos.z,
                Config.ValetDrivingSpeed or 16.0,
                Config.ValetDrivingStyle or 786603,
                6.0
            )

            Wait(1500)
        end

        if not isValetInProgress or not DoesEntityExist(veh) or not DoesEntityExist(valetPed) then
            cleanupCurrentValet(false, payload.plate)
            return
        end

        -- Se estourou timeout e ainda estava longe, aproxima com fallback suave
        if not arrivedNearPlayer then
            local fallbackPlayerCoords = GetEntityCoords(cache.ped or PlayerPedId())
            local found, safeNode = GetClosestVehicleNodeWithHeading(fallbackPlayerCoords.x, fallbackPlayerCoords.y, fallbackPlayerCoords.z, 1, 3.0, 0)
            if found then
                SetEntityCoords(veh, safeNode.x, safeNode.y, safeNode.z + 0.5, false, false, false, true)
            end
        end

        -- 1. Encosta no meio-fio e para o veículo suavemente
        BringVehicleToHalt(veh, 8.0, 3, false)
        Wait(2500)

        SetVehicleHandbrake(veh, true)
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleIndicatorLights(veh, 0, true) -- Pisca alerta
        SetVehicleIndicatorLights(veh, 1, true)
        SetVehicleDoorsLocked(veh, 1) -- Destranca portas

        Haze.Client.Notify(Locale.valet_arrived or "Seu manobrista chegou ao local e está trazendo as chaves até você.", "info")

        -- 2. Manobrista sai do carro
        ClearPedTasks(valetPed)
        TaskLeaveVehicle(valetPed, veh, 0)

        local leaveWait = 0
        while IsPedInAnyVehicle(valetPed, false) and leaveWait < 6000 do
            Wait(200)
            leaveWait = leaveWait + 200
        end

        Wait(800)

        -- 3. Manobrista caminha até o jogador
        local targetPed = cache.ped or PlayerPedId()
        TaskGoToEntity(valetPed, targetPed, -1, 1.3, 1.0, 1073741824, 0)

        local walkWait = 0
        while DoesEntityExist(valetPed) and walkWait < 12000 do
            local pCoord = GetEntityCoords(cache.ped or PlayerPedId())
            local vCoord = GetEntityCoords(valetPed)
            if #(pCoord - vCoord) <= 1.8 then
                break
            end
            Wait(250)
            walkWait = walkWait + 250
        end

        -- 4. Animação de entrega das chaves
        targetPed = cache.ped or PlayerPedId()
        TaskTurnPedToFaceEntity(valetPed, targetPed, 1000)
        TaskTurnPedToFaceEntity(targetPed, valetPed, 1000)
        Wait(600)

        local animDict = "mp_common"
        local animName = "givetake2_a"
        if Haze.Client.RequestAnimDict(animDict) then
            -- Cria prop de chaves na mão direita do ped
            local keyPropHash = GetHashKey("p_car_keys_01")
            local keyProp = nil
            if Haze.Client.RequestModel(keyPropHash) then
                local vPos = GetEntityCoords(valetPed)
                keyProp = CreateObject(keyPropHash, vPos.x, vPos.y, vPos.z, true, true, false)
                AttachEntityToEntity(keyProp, valetPed, GetPedBoneIndex(valetPed, 60309), 0.08, 0.02, -0.02, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            end

            TaskPlayAnim(valetPed, animDict, animName, 4.0, -4.0, 2200, 0, 0, false, false, false)
            TaskPlayAnim(targetPed, animDict, animName, 4.0, -4.0, 2200, 0, 0, false, false, false)

            Wait(1800)

            if keyProp and DoesEntityExist(keyProp) then
                DeleteEntity(keyProp)
            end
        end

        -- 5. Concede chaves locais e finaliza
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent("haze_garages:server:giveVehicleKeys", netId, payload.plate)
        TriggerEvent("qb-vehiclekeys:client:AddKeys", payload.plate)

        Haze.Client.Notify(Locale.valet_delivered or "Aqui estão as chaves do seu veículo, senhor! Tenha uma excelente viagem.", "success")

        -- Desliga pisca-alerta após 3 segundos
        SetTimeout(3000, function()
            if DoesEntityExist(veh) then
                SetVehicleIndicatorLights(veh, 0, false)
                SetVehicleIndicatorLights(veh, 1, false)
            end
        end)

        -- 6. Manobrista vai embora a pé tranquilamente
        if currentValetBlip and DoesBlipExist(currentValetBlip) then
            RemoveBlip(currentValetBlip)
            currentValetBlip = nil
        end

        TaskWanderStandard(valetPed, 10.0, 10)
        SetPedAsNoLongerNeeded(valetPed)
        currentValetPed = nil
        currentValetVeh = nil
        isValetInProgress = false

        TriggerServerEvent("haze_garages:server:valetFinished", payload.plate)
    end)
end)

--- Menu de seleção de veículo para o comando /valet
local function openValetSelectionMenu()
    local playerPed = cache.ped or PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        Haze.Client.Notify("Você precisa estar fora de qualquer veículo para solicitar o manobrista.", "error")
        return
    end

    local vehicles = lib.callback.await("haze_garages:server:getValetVehicles", false)
    if not vehicles or #vehicles == 0 then
        Haze.Client.Notify("Você não possui veículos guardados em garagens aptos para o Valet.", "warning")
        return
    end

    local options = {}
    for _, v in ipairs(vehicles) do
        local title = v.model
        if v.nickname and v.nickname ~= "" then
            title = string.format("%s (%s)", v.nickname, v.model)
        end

        table.insert(options, {
            title = title,
            description = string.format("Placa: %s | Garagem: %s | Custo: %s%s", v.plate, v.garageLabel, Config.Currency or "$", Config.ValetPrice or 150),
            icon = "car",
            onSelect = function()
                TriggerEvent("haze_garages:client:requestValet", v.plate)
            end
        })
    end

    lib.registerContext({
        id = "haze_valet_menu",
        title = "🛎️ Solicitar Manobrista (Valet)",
        options = options
    })

    lib.showContext("haze_valet_menu")
end

--- Comando in-game /valet [placa]
RegisterCommand(Config.ValetCommand or "valet", function(source, args)
    if args and args[1] then
        local plate = string.upper(table.concat(args, " "))
        TriggerEvent("haze_garages:client:requestValet", plate)
    else
        openValetSelectionMenu()
    end
end, false)

--- Limpeza em caso de parada do resource
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cleanupCurrentValet(false, nil)
end)
