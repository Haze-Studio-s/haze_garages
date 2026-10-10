-- =================================================================================
-- Haze Garages - Wizard In-Game de Criação e Gerenciamento de Garagens
-- Permite criar garagens 100% in-game com atualização física em data/garages.json
-- NENHUMA linha ou marcador 3D permanece no asfalto após a criação (100% limpo)
-- =================================================================================

local isCreatingGarage = false

local function cancelCreation()
    isCreatingGarage = false
    lib.hideTextUI()
    lib.notify({
        title = "Haze Garages",
        description = "Sessão de criação de garagem cancelada.",
        type = "inform"
    })
end

local function sanitizeId(str)
    if not str then return nil end
    local s = string.lower(tostring(str)):gsub("%s+", "_"):gsub("%-", "_"):gsub("[^%w_]", "")
    return s ~= "" and s or nil
end

--- Inicia o Wizard Guiado de Criação de Garagens
local function startGarageCreationWizard()
    if isCreatingGarage then
        lib.notify({
            title = "Haze Garages",
            description = "Você já está em uma sessão de criação. Finalize ou cancele primeiro.",
            type = "error"
        })
        return
    end

    -- Passo 1: Formulário Inicial via ox_lib inputDialog
    local form = lib.inputDialog("Criar Nova Garagem", {
        {
            type = 'input',
            label = 'ID Único da Garagem',
            description = 'Identificador único no sistema (ex: pillbox_public, dp_policia)',
            placeholder = 'garagem_exemplo',
            required = true,
            min = 2,
            max = 32
        },
        {
            type = 'input',
            label = 'Nome de Exibição (Label)',
            description = 'Nome exibido no mapa, menus e notificações (ex: Garagem Central)',
            placeholder = 'Garagem Central',
            required = true,
            min = 2,
            max = 50
        },
        {
            type = 'select',
            label = 'Tipo de Garagem',
            options = {
                { value = 'public', label = 'Pública (Acesso para todos os cidadãos)' },
                { value = 'job', label = 'Trabalho / Job (Apenas membros do emprego)' },
                { value = 'gang', label = 'Gangue / Facção (Apenas membros da facção)' },
                { value = 'impound', label = 'Apreensão / Pátio de Apreendidos' }
            },
            default = 'public',
            required = true
        },
        {
            type = 'input',
            label = 'Nome do Emprego ou Gangue',
            description = 'Preencha se o tipo for Job ou Gangue (ex: police, ambulance, vagos)',
            placeholder = 'police'
        },
        {
            type = 'select',
            label = 'Categoria de Veículos',
            options = {
                { value = 'car', label = 'Terrestre (Carros, Motocicletas, Caminhões)' },
                { value = 'boat', label = 'Náutico (Barcos, Jet-Skis)' },
                { value = 'air', label = 'Aéreo (Helicópteros, Aviões)' }
            },
            default = 'car',
            required = true
        },
        {
            type = 'input',
            label = 'Modelo do Atendente NPC',
            description = 'Nome do modelo do ped atendente (padrão: s_m_m_valet_01)',
            placeholder = 's_m_m_valet_01'
        },
        {
            type = 'number',
            label = 'Ícone do Blip (Sprite ID)',
            description = 'Sprite do radar (padrão: 357 = garagem)',
            default = 357
        },
        {
            type = 'number',
            label = 'Cor do Blip (Color ID)',
            description = 'Cor do radar (padrão: 3 = azul claro, 38 = azul escuro, 1 = vermelho)',
            default = 3
        }
    })

    if not form then
        lib.notify({
            title = "Haze Garages",
            description = "Criação de garagem cancelada.",
            type = "inform"
        })
        return
    end

    local rawId = form[1]
    local label = form[2]
    local gType = form[3] or "public"
    local jobOrGang = form[4] or ""
    local category = form[5] or "car"
    local pedModel = (form[6] and form[6] ~= "") and form[6] or "s_m_m_valet_01"
    local blipSprite = tonumber(form[7]) or 357
    local blipColor = tonumber(form[8]) or 3

    local cleanId = sanitizeId(rawId)
    if not cleanId then
        lib.notify({
            title = "Haze Garages",
            description = "ID da garagem inválido. Use apenas letras e números.",
            type = "error"
        })
        return
    end

    local jobName = (gType == "job" and jobOrGang ~= "") and jobOrGang or nil
    local gangName = (gType == "gang" and jobOrGang ~= "") and jobOrGang or nil

    if gType == "job" and not jobName then
        lib.notify({
            title = "Haze Garages",
            description = "Para garagem do tipo Job, você precisa informar o nome do emprego!",
            type = "error"
        })
        return
    end

    if gType == "gang" and not gangName then
        lib.notify({
            title = "Haze Garages",
            description = "Para garagem do tipo Gangue, você precisa informar o nome da gangue!",
            type = "error"
        })
        return
    end

    isCreatingGarage = true

    -- Passo 2: Posicionamento do Atendente NPC
    lib.notify({
        title = "Passo 2/4: Atendente NPC",
        description = "Posicione seu personagem onde o Atendente NPC deve ficar e pressione [E].",
        type = "inform",
        duration = 8000
    })

    lib.showTextUI("[E] Confirmar Posição do NPC | [X] Cancelar", { position = "top-center" })

    local npcCoords = nil
    while isCreatingGarage do
        Wait(0)
        DisableControlAction(0, 73, true) -- X

        local ped = cache.ped or PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- Marcador discreto no local temporário do admin para feedback visual instantâneo
        DrawMarker(2, pos.x, pos.y, pos.z + 1.1, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.25, 0.25, 0.25, 16, 185, 129, 200, false, true, 2, false, nil, nil, false)

        if IsControlJustPressed(0, 38) then -- [E]
            local h = GetEntityHeading(ped)
            npcCoords = {
                x = math.floor(pos.x * 100) / 100,
                y = math.floor(pos.y * 100) / 100,
                z = math.floor(pos.z * 100) / 100,
                w = math.floor(h * 100) / 100
            }
            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            lib.notify({
                title = "Haze Garages",
                description = "Posição e ângulo do Atendente registrados com sucesso!",
                type = "success"
            })
            break
        elseif IsDisabledControlJustPressed(0, 73) then -- [X]
            cancelCreation()
            return
        end
    end

    if not isCreatingGarage or not npcCoords then return end

    -- Passo 3: Marcação dos 4 Pontos da DropZone Poligonal
    lib.notify({
        title = "Passo 3/4: Área de Devolução (DropZone)",
        description = "Caminhe até cada um dos 4 cantos da área de devolução e pressione [E].",
        type = "inform",
        duration = 9000
    })

    local polygonPoints = {}
    lib.showTextUI(string.format("[E] Marcar Canto (0/4) | [BACKSPACE] Desfazer | [X] Cancelar", #polygonPoints), { position = "top-center" })

    while isCreatingGarage and #polygonPoints < 4 do
        Wait(0)
        DisableControlAction(0, 73, true)   -- X
        DisableControlAction(0, 177, true)  -- BACKSPACE
        DisableControlAction(0, 194, true)  -- BACKSPACE Alternate

        -- Renderização temporária apenas durante o modo de criação para orientação do admin
        for i = 1, #polygonPoints do
            local pt = polygonPoints[i]
            DrawMarker(28, pt.x, pt.y, pt.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 16, 185, 129, 220, false, false, 2, false, nil, nil, false)
            if i > 1 then
                local prev = polygonPoints[i - 1]
                DrawLine(prev.x, prev.y, prev.z + 0.15, pt.x, pt.y, pt.z + 0.15, 16, 185, 129, 255)
            end
        end

        if #polygonPoints == 3 then
            -- Linha guia pontilhada mental até o ped atual
            local pedPos = GetEntityCoords(cache.ped or PlayerPedId())
            local p3 = polygonPoints[3]
            DrawLine(p3.x, p3.y, p3.z + 0.15, pedPos.x, pedPos.y, pedPos.z + 0.15, 106, 254, 135, 180)
        end

        if IsControlJustPressed(0, 38) then -- [E]
            local pedPos = GetEntityCoords(cache.ped or PlayerPedId())
            polygonPoints[#polygonPoints + 1] = {
                x = math.floor(pedPos.x * 100) / 100,
                y = math.floor(pedPos.y * 100) / 100,
                z = math.floor(pedPos.z * 100) / 100
            }
            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

            if #polygonPoints < 4 then
                lib.showTextUI(string.format("[E] Marcar Canto (%d/4) | [BACKSPACE] Desfazer | [X] Cancelar", #polygonPoints), { position = "top-center" })
                lib.notify({
                    title = "Haze Garages",
                    description = string.format("Canto %d/4 registrado! Vá até o próximo canto.", #polygonPoints),
                    type = "inform"
                })
            else
                PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
                lib.notify({
                    title = "Haze Garages",
                    description = "Área de devolução (4 cantos) demarcada com sucesso!",
                    type = "success"
                })
                break
            end
        elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then -- [BACKSPACE]
            if #polygonPoints > 0 then
                table.remove(polygonPoints)
                PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                lib.showTextUI(string.format("[E] Marcar Canto (%d/4) | [BACKSPACE] Desfazer | [X] Cancelar", #polygonPoints), { position = "top-center" })
            end
        elseif IsDisabledControlJustPressed(0, 73) then -- [X]
            cancelCreation()
            return
        end
    end

    if not isCreatingGarage or #polygonPoints ~= 4 then return end

    -- Passo 4: Marcação das Vagas de Spawn dos Veículos
    lib.notify({
        title = "Passo 4/4: Vagas de Retirada (Spawn)",
        description = "Posicione-se (a pé ou de carro) nas vagas de saída e pressione [E]. Pressione [G] para concluir.",
        type = "inform",
        duration = 9000
    })

    local spawns = {}
    lib.showTextUI(string.format("[E] Gravar Vaga (#%d) | [G] Concluir (Mín: 1) | [BACKSPACE] Desfazer | [X] Cancelar", #spawns), { position = "top-center" })

    while isCreatingGarage do
        Wait(0)
        DisableControlAction(0, 47, true)   -- G
        DisableControlAction(0, 73, true)   -- X
        DisableControlAction(0, 177, true)  -- BACKSPACE
        DisableControlAction(0, 194, true)  -- BACKSPACE Alternate

        -- Renderização temporária das vagas já adicionadas durante a sessão de criação
        for i = 1, #spawns do
            local sp = spawns[i]
            DrawMarker(0, sp.x, sp.y, sp.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, sp.w, 0.8, 0.8, 0.5, 106, 254, 135, 200, false, false, 2, false, nil, nil, false)
        end

        if IsControlJustPressed(0, 38) then -- [E]
            local targetEntity = cache.ped or PlayerPedId()
            if cache.vehicle and DoesEntityExist(cache.vehicle) then
                targetEntity = cache.vehicle
            end

            local c = GetEntityCoords(targetEntity)
            local h = GetEntityHeading(targetEntity)
            spawns[#spawns + 1] = {
                x = math.floor(c.x * 100) / 100,
                y = math.floor(c.y * 100) / 100,
                z = math.floor(c.z * 100) / 100,
                w = math.floor(h * 100) / 100
            }

            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            lib.notify({
                title = "Haze Garages",
                description = string.format("Vaga de saída #%d gravada com sucesso!", #spawns),
                type = "inform"
            })
            lib.showTextUI(string.format("[E] Gravar Vaga (#%d) | [G] Concluir (Mín: 1) | [BACKSPACE] Desfazer | [X] Cancelar", #spawns), { position = "top-center" })
        elseif IsDisabledControlJustPressed(0, 47) then -- [G]
            if #spawns < 1 then
                lib.notify({
                    title = "Haze Garages",
                    description = "Você precisa registrar pelo menos 1 vaga de saída antes de concluir!",
                    type = "error"
                })
            else
                PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
                break
            end
        elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then -- [BACKSPACE]
            if #spawns > 0 then
                table.remove(spawns)
                PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                lib.showTextUI(string.format("[E] Gravar Vaga (#%d) | [G] Concluir (Mín: 1) | [BACKSPACE] Desfazer | [X] Cancelar", #spawns), { position = "top-center" })
            end
        elseif IsDisabledControlJustPressed(0, 73) then -- [X]
            cancelCreation()
            return
        end
    end

    lib.hideTextUI()
    isCreatingGarage = false

    if #spawns < 1 then return end

    -- Montagem do Payload Final
    local garagePayload = {
        id = cleanId,
        label = label,
        type = gType,
        job = jobName,
        gang = gangName,
        category = category,
        coords = npcCoords,
        dropZone = {
            points = polygonPoints,
            thickness = 6.0
        },
        spawnCoords = spawns,
        pedModel = pedModel,
        blip = {
            sprite = blipSprite,
            color = blipColor,
            scale = 0.75
        },
        price = 0,
        overwrite = false
    }

    -- Passo 5: Diálogo de Confirmação Final
    local confirm = lib.alertDialog({
        header = 'Confirmar Criação de Garagem',
        content = string.format([[
### Resumo da Garagem
- **ID:** `%s`
- **Nome:** %s
- **Tipo:** %s %s
- **Categoria:** %s
- **NPC Atendente:** `%s` (x: %.1f, y: %.1f, z: %.1f, h: %.1f)
- **Área DropZone:** 4 Pontos poligonais demarcados
- **Vagas de Saída:** %d vaga(s)

Deseja gravar fisicamente no arquivo `data/garages.json` e aplicar no servidor agora?
        ]], garagePayload.id, garagePayload.label, garagePayload.type, (garagePayload.job or garagePayload.gang or ""), garagePayload.category, garagePayload.pedModel, garagePayload.coords.x, garagePayload.coords.y, garagePayload.coords.z, garagePayload.coords.w, #garagePayload.spawnCoords),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then
        lib.notify({
            title = "Haze Garages",
            description = "Operação de criação cancelada pelo usuário.",
            type = "inform"
        })
        return
    end

    -- Envio assíncrono para o servidor
    local res = lib.callback.await("haze_garages:server:saveGarage", false, garagePayload)

    if res and res.needsConfirm then
        local overwriteConfirm = lib.alertDialog({
            header = 'Garagem Já Existente',
            content = res.msg or string.format("Já existe uma garagem cadastrada com o ID '%s'. Deseja sobrescrever os dados?", garagePayload.id),
            centered = true,
            cancel = true
        })

        if overwriteConfirm == 'confirm' then
            garagePayload.overwrite = true
            res = lib.callback.await("haze_garages:server:saveGarage", false, garagePayload)
        else
            lib.notify({
                title = "Haze Garages",
                description = "Gravação cancelada. O registro existente foi mantido intacto.",
                type = "inform"
            })
            return
        end
    end

    if res and res.success then
        lib.notify({
            title = "Haze Garages",
            description = res.msg or "Garagem salva em data/garages.json e ativada em tempo real!",
            type = "success"
        })
    else
        lib.notify({
            title = "Haze Garages",
            description = (res and res.msg) or "Ocorreu um erro ao salvar a garagem no servidor.",
            type = "error"
        })
    end
end

--- Painel de Gerenciamento Administrativo de Garagens
local function openAdminGaragesMenu()
    CreateThread(function()
        local garagesList = lib.callback.await("haze_garages:server:getAdminGaragesList", false)
        if not garagesList then
            lib.notify({
                title = "Haze Garages",
                description = "Você não possui permissão administrativa para gerenciar garagens.",
                type = "error"
            })
            return
        end

        local options = {
            {
                title = '[+] Criar Nova Garagem',
                description = 'Inicia o assistente interativo de criação guiada',
                icon = 'plus',
                iconColor = '#10b981',
                onSelect = function()
                    CreateThread(function()
                        startGarageCreationWizard()
                    end)
                end
            }
        }

        for _, g in ipairs(garagesList) do
            local typeBadge = g.type
            if g.job then typeBadge = typeBadge .. " (" .. g.job .. ")" end
            if g.gang then typeBadge = typeBadge .. " (" .. g.gang .. ")" end

            options[#options + 1] = {
                title = g.label,
                description = string.format("ID: %s | Tipo: %s | Vagas: %d | Cantos: %d", g.id, typeBadge, g.spawnsCount, g.pointsCount),
                icon = 'warehouse',
                arrow = true,
                onSelect = function()
                    lib.registerContext({
                        id = 'haze_garage_action_' .. g.id,
                        title = g.label,
                        menu = 'haze_garages_admin_list',
                        options = {
                            {
                                title = 'Teleportar até a Garagem',
                                description = string.format("Coordenadas: x: %.1f, y: %.1f, z: %.1f", g.coords.x, g.coords.y, g.coords.z),
                                icon = 'location-dot',
                                onSelect = function()
                                    local ped = cache.ped or PlayerPedId()
                                    SetEntityCoords(ped, g.coords.x, g.coords.y, g.coords.z + 0.5, false, false, false, true)
                                    lib.notify({
                                        title = "Haze Garages",
                                        description = string.format("Teleportado para a garagem '%s'!", g.label),
                                        type = "success"
                                    })
                                end
                            },
                            {
                                title = 'Excluir Garagem',
                                description = 'Remove permanentemente do arquivo data/garages.json',
                                icon = 'trash',
                                iconColor = '#ef4444',
                                onSelect = function()
                                    CreateThread(function()
                                        local confirmDelete = lib.alertDialog({
                                            header = 'Excluir Garagem',
                                            content = string.format("Tem certeza que deseja excluir permanentemente a garagem **%s** (`%s`)?\n\nEsta ação apagará a entrada do `data/garages.json` e atualizará o servidor em tempo real.", g.label, g.id),
                                            centered = true,
                                            cancel = true
                                        })

                                        if confirmDelete == 'confirm' then
                                            local delRes = lib.callback.await("haze_garages:server:deleteGarage", false, g.id)
                                            if delRes and delRes.success then
                                                lib.notify({
                                                    title = "Haze Garages",
                                                    description = delRes.msg or "Garagem excluída com sucesso!",
                                                    type = "success"
                                                })
                                                openAdminGaragesMenu()
                                            else
                                                lib.notify({
                                                    title = "Haze Garages",
                                                    description = (delRes and delRes.msg) or "Falha ao excluir garagem.",
                                                    type = "error"
                                                })
                                            end
                                        end
                                    end)
                                end
                            }
                        }
                    })
                    lib.showContext('haze_garage_action_' .. g.id)
                end
            }
        end

        lib.registerContext({
            id = 'haze_garages_admin_list',
            title = 'Gerenciador de Garagens (Admin)',
            options = options
        })

        lib.showContext('haze_garages_admin_list')
    end)
end

-- =================================================================================
-- Comandos Administrativos
-- =================================================================================

RegisterCommand("criargaragem", function()
    CreateThread(function()
        local garagesList = lib.callback.await("haze_garages:server:getAdminGaragesList", false)
        if not garagesList then
            lib.notify({
                title = "Haze Garages",
                description = "Você não possui permissão administrativa para criar garagens.",
                type = "error"
            })
            return
        end
        startGarageCreationWizard()
    end)
end, false)

RegisterCommand("novagaragem", function()
    ExecuteCommand("criargaragem")
end, false)

RegisterCommand("gerenciargaragens", function()
    openAdminGaragesMenu()
end, false)

RegisterCommand("garagensadmin", function()
    openAdminGaragesMenu()
end, false)
