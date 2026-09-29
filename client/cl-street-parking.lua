local streetPoints = {}

local function clearStreetPoints()
    for _, pt in ipairs(streetPoints) do
        pt:remove()
    end
    streetPoints = {}
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

    local props = {}
    if exports.qbx_core then
        props = exports.qbx_core:getVehicleProperties(veh)
    elseif exports['qb-core'] then
        props = exports['qb-core']:GetCoreObject().Functions.GetVehicleProperties(veh)
    end

    local vehData = {
        plate = plate,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        model = model,
        props = props
    }

    local success, errReason = lib.callback.await("haze_garages:server:handleStreetPark", false, vehData)
    if success then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1000)
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
        TriggerEvent("haze_garages:client:refreshStreetVehicles")
    else
        Haze.Client.Notify(errReason or "Erro ao estacionar.", "error")
    end
end)

RegisterNetEvent("haze_garages:client:refreshStreetVehicles", function()
    clearStreetPoints()

    local vehicles = lib.callback.await("haze_garages:server:getStreetParkedVehicles", false)
    for _, item in ipairs(vehicles or {}) do
        local spotCoords = vec3(item.coords.x, item.coords.y, item.coords.z)

        local point = lib.points.new({
            coords = spotCoords,
            distance = 60.0,
            onEnter = function(self)
                if not self.entity or not DoesEntityExist(self.entity) then
                    lib.requestModel(item.model or "adder")
                    local veh = CreateVehicle(item.model or joaat("adder"), item.coords.x, item.coords.y, item.coords.z, item.coords.w or 0.0, false, false)
                    SetVehicleNumberPlateText(veh, item.plate)
                    SetEntityAsMissionEntity(veh, true, true)
                    FreezeEntityPosition(veh, true)
                    SetVehicleDoorsLocked(veh, 2)
                    self.entity = veh
                end
            end,
            onLeave = function(self)
                if self.entity and DoesEntityExist(self.entity) then
                    DeleteEntity(self.entity)
                    self.entity = nil
                end
            end,
            nearby = function(self)
                if self.currentDistance < 3.0 and IsControlJustReleased(0, 38) then -- Key E to unpark
                    local isOfflineLocked = lib.callback.await("haze_garages:server:checkVehicleOfflineLock", false, item.plate)
                    if isOfflineLocked then
                        Haze.Client.Notify(Locale.vehicle_offline_locked, "error")
                        return
                    end

                    local success = lib.callback.await("haze_garages:server:unparkStreetVehicle", false, item.plate)
                    if success and self.entity and DoesEntityExist(self.entity) then
                        FreezeEntityPosition(self.entity, false)
                        SetVehicleDoorsLocked(self.entity, 1)
                        TaskWarpPedIntoVehicle(cache.ped or PlayerPedId(), self.entity, -1)
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
