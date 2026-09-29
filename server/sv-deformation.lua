lib.callback.register("haze_garages:server:saveVehicleDeformation", function(source, plate, deformationData, mechanicalData)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if not cleanPlate or cleanPlate == "" then return false end

    MySQL.query([[
        REPLACE INTO haze_vehicle_deformations (plate, deformation, mechanical_damage)
        VALUES (?, ?, ?)
    ]], {
        cleanPlate,
        deformationData and json.encode(deformationData) or nil,
        mechanicalData and json.encode(mechanicalData) or nil
    })

    return true
end)

lib.callback.register("haze_garages:server:getVehicleDeformation", function(source, plate)
    local cleanPlate = Haze.Shared.CleanPlate(plate)
    if not cleanPlate or cleanPlate == "" then return nil end

    local row = MySQL.single.await("SELECT * FROM haze_vehicle_deformations WHERE plate = ?", { cleanPlate })
    if not row then return nil end

    return {
        deformation = row.deformation and json.decode(row.deformation) or nil,
        mechanical = row.mechanical_damage and json.decode(row.mechanical_damage) or nil
    }
end)
