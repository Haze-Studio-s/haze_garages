Haze = Haze or {}
Haze.Client = Haze.Client or {}

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
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
