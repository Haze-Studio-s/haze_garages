Haze = Haze or {}
Haze.Client = Haze.Client or {}

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    TriggerEvent("haze_garages:client:init")
end)

RegisterNetEvent("qbx_core:client:playerLoaded", function()
    TriggerEvent("haze_garages:client:init")
end)

RegisterNetEvent("esx:playerLoaded", function()
    TriggerEvent("haze_garages:client:init")
end)

AddEventHandler("onResourceStart", function(resName)
    if GetCurrentResourceName() == resName then
        TriggerEvent("haze_garages:client:init")
    end
end)

RegisterNetEvent("haze_garages:client:addPoliceBlip", function(coords, plate)
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("🚨 Arrombamento de Veículo: " .. (plate or ""))
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        Wait(60000)
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

