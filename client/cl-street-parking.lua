local streetPoints = {}

local function clearStreetPoints()
    for _, pt in ipairs(streetPoints) do
        pt:remove()
    end
    streetPoints = {}
end

local function safeDeleteVehicle(veh)
    if not veh or not DoesEntityExist(veh) then return end
    SetEntityAsMissionEntity(veh, true, true)
    local tries = 0
    while DoesEntityExist(veh) and tries < 20 do
        NetworkRequestControlOfEntity(veh)
        DeleteVehicle(veh)
        DeleteEntity(veh)
        Wait(50)
        tries = tries + 1
    end
end

RegisterNetEvent("haze_garages:client:requestStreetPark", function()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if not veh or veh == 0 then
        Haze.Client.Notify(Locale.not_in_vehicle, "error")
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        Haze.Client.Notify("Você precisa estar no banco do motorista.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local model = GetEntityModel(veh)

    local props = Haze.Client.GetVehicleProperties(veh)

    local vehData = {
        plate = plate,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        model = model,
        props = props
    }

    local check = lib.callback.await("haze_garages:server:checkStreetParkFee", false, vehData)
    if not check or not check.isOwner then
        Haze.Client.Notify(check and check.reason or Locale.not_vehicle_owner, "error")
        return
    end

    if check.limitReached then
        Haze.Client.Notify(check.reason, "error")
        return
    end

    if check.fee and check.fee > 0 then
        local alert = lib.alertDialog({
            header = "Estacionamento de Rua",
            content = string.format("Estacionar neste ponto de rua custará **%s%s**.\n\nDeseja confirmar o pagamento e estacionar o veículo?", Config.Currency or "R$", check.fee),
            centered = true,
            cancel = true,
            labels = {
                confirm = "Estacionar (Pagar)",
                cancel = "Cancelar"
            }
        })
        if alert ~= "confirm" then
            Haze.Client.Notify("Estacionamento cancelado.", "info")
            return
        end
    end

    local success, errReason = lib.callback.await("haze_garages:server:handleStreetPark", false, vehData)
    if success then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1500)
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            FreezeEntityPosition(veh, true)
            SetVehicleDoorsLocked(veh, 2)
        end
        TriggerEvent("haze_garages:client:refreshStreetVehicles", veh)

        -- Despawn automático do veículo físico 60 segundos após estacionar
        CreateThread(function()
            Wait(60000)
            if DoesEntityExist(veh) then
                safeDeleteVehicle(veh)
            end
        end)
    else
        Haze.Client.Notify(errReason or "Erro ao estacionar.", "error")
    end
end)

RegisterNetEvent("haze_garages:client:refreshStreetVehicles", function(existingVeh)
    clearStreetPoints()

    local vehicles = lib.callback.await("haze_garages:server:getStreetParkedVehicles", false)
    for _, item in ipairs(vehicles or {}) do
        local spotCoords = vec3(item.coords.x, item.coords.y, item.coords.z)
        local cleanItemPlate = Haze.Shared.CleanPlate(item.plate)

        local point = lib.points.new({
            coords = spotCoords,
            distance = 60.0,
            onEnter = function(self)
                if not self.entity or not DoesEntityExist(self.entity) then
                    if existingVeh and DoesEntityExist(existingVeh) then
                        local cleanExistingPlate = Haze.Shared.CleanPlate(GetVehicleNumberPlateText(existingVeh))
                        if cleanExistingPlate == cleanItemPlate then
                            self.entity = existingVeh
                            return
                        end
                    end
                end
            end,
            onLeave = function(self)
                if self.entity and DoesEntityExist(self.entity) then
                    safeDeleteVehicle(self.entity)
                    self.entity = nil
                end
            end,
            nearby = function(self)
                if self.currentDistance < 3.0 and IsControlJustReleased(0, 38) then -- Key E to unpark
                    local isOfflineLocked = lib.callback.await("haze_garages:server:checkVehicleOfflineLock", false, item.plate)
                    if isOfflineLocked then
                        Haze.Client.Notify(Locale.vehicle_offline_locked, "error")
                        local pedCoords = GetEntityCoords(cache.ped or PlayerPedId())
                        TriggerServerEvent("haze_garages:server:reportLockpickAttempt", item.plate, pedCoords)
                        return
                    end

                    local success = lib.callback.await("haze_garages:server:unparkStreetVehicle", false, item.plate)
                    if success and self.entity and DoesEntityExist(self.entity) then
                        FreezeEntityPosition(self.entity, false)
                        SetVehicleDoorsLocked(self.entity, 1)
                        self.entity = nil
                        self:remove()
                    end
                end
            end
        })

        streetPoints[#streetPoints + 1] = point
    end
end)

AddEventHandler("haze_garages:client:init", function()
    TriggerEvent("haze_garages:client:refreshStreetVehicles")
end)
