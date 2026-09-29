RegisterNetEvent("haze_garages:client:applyVehicleDeformation", function(vehicle, deformationData, mechanicalData)
    if not DoesEntityExist(vehicle) then return end

    if mechanicalData then
        if mechanicalData.engineHealth then
            SetVehicleEngineHealth(vehicle, mechanicalData.engineHealth + 0.0)
        end
        if mechanicalData.bodyHealth then
            SetVehicleBodyHealth(vehicle, mechanicalData.bodyHealth + 0.0)
        end
        if mechanicalData.tankHealth then
            SetVehiclePetrolTankHealth(vehicle, mechanicalData.tankHealth + 0.0)
        end
    end

    if type(deformationData) == "table" and #deformationData > 0 then
        for _, def in ipairs(deformationData) do
            if def.x and def.y and def.z and def.damage then
                SetVehicleDamage(vehicle, def.x + 0.0, def.y + 0.0, def.z + 0.0, def.damage + 0.0, 50.0, true)
            end
        end
    end
end)

function Haze.Client.GetVehicleDeformation(vehicle)
    if not DoesEntityExist(vehicle) then return nil, nil end

    local mechanical = {
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle)
    }

    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local deformation = {}
    local step = 0.4

    for x = minDim.x, maxDim.x, step do
        for y = minDim.y, maxDim.y, step do
            for z = minDim.z, maxDim.z, step do
                local offset = vec3(x, y, z)
                local damage = GetVehicleDeformationAtPos(vehicle, offset)
                if damage and #damage > 0.05 then
                    deformation[#deformation + 1] = {
                        x = x,
                        y = y,
                        z = z,
                        damage = #damage
                    }
                end
            end
        end
    end

    return deformation, mechanical
end
