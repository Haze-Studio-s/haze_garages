-- =================================================================================
-- Haze Garages - Cliente de Rastreador GPS Veicular & Jammer de Sinal
-- =================================================================================

RegisterNetEvent("haze_garages:client:useVehicleTracker", function()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if not veh or veh == 0 then
        local pedCoords = GetEntityCoords(ped)
        veh = lib.getClosestVehicle(pedCoords, 3.5, true)
    end

    if not veh or not DoesEntityExist(veh) then
        Haze.Client.Notify("Nenhum veículo próximo para instalar o rastreador.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local cleanPlate = Haze.Shared.CleanPlate(plate)

    local success = lib.progressBar({
        duration = 5000,
        label = "Instalando Rastreador GPS...",
        useReplay = false,
        canCancel = true,
        anim = {
            dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
            clip = "machinic_loop_mecheckbox"
        },
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    if success then
        local installed, payload = lib.callback.await("haze_garages:server:installTracker", false, cleanPlate)
        if installed then
            Haze.Client.Notify(string.format("Rastreador GPS instalado com sucesso no veículo [%s]!", cleanPlate), "success")
        else
            Haze.Client.Notify(payload or "Erro ao instalar rastreador.", "error")
        end
    else
        Haze.Client.Notify("Instalação cancelada.", "warning")
    end
end)

RegisterNetEvent("haze_garages:client:useTrackerJammer", function()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if not veh or veh == 0 then
        local pedCoords = GetEntityCoords(ped)
        veh = lib.getClosestVehicle(pedCoords, 3.5, true)
    end

    if not veh or not DoesEntityExist(veh) then
        Haze.Client.Notify("Nenhum veículo próximo para usar o jammer de sinal.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local cleanPlate = Haze.Shared.CleanPlate(plate)

    local success = lib.progressBar({
        duration = 5000,
        label = "Instalando Jammer de Sinal GPS...",
        useReplay = false,
        canCancel = true,
        anim = {
            dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
            clip = "machinic_loop_mecheckbox"
        },
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    if success then
        local jammed, payload = lib.callback.await("haze_garages:server:installJammer", false, cleanPlate)
        if jammed then
            Haze.Client.Notify(string.format("Sinal GPS do veículo [%s] bloqueado por %d minutos!", cleanPlate, payload.duration or 30), "success")
        else
            Haze.Client.Notify(payload or "Erro ao aplicar jammer de sinal.", "error")
        end
    else
        Haze.Client.Notify("Instalação do jammer cancelada.", "warning")
    end
end)
