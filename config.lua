Config = {}

-- Idioma e Identificação
Config.Locale = "pt-BR"
Config.Currency = "$"

-- Framework & Integrações
Config.Framework = "auto" -- "auto" (detecta qbx_core, qb-core ou ESX)
Config.FuelSystem = "auto" -- "ox_fuel", "LegacyFuel", "ps-fuel", "none"
Config.VehicleKeys = "auto" -- "qbx_vehiclekeys", "qb-vehiclekeys", "none"
Config.EnableGranollaMechanic = true -- Integração com granolla_mechanic (desgaste de peças)
Config.EnableDVNearestGarage = true -- Enviar veículo próprio para a garagem mais próxima ao dar /dv
Config.DVCommandRestricted = false -- Restrição do comando /dv (false para todos, ou 'group.admin')


-- Configurações de Estacionamento de Rua (/estacionar)
Config.StreetParkCommand = "estacionar"
Config.StreetParkingFee = 250 -- Custo na primeira vez em um novo ponto dinâmico de rua
Config.DynamicSpotTolerance = 10.0 -- Distância (em metros) para considerar o mesmo ponto dinâmico salvo
Config.StreetParkingExpirationHours = 72 -- Horas de inatividade para expirar e enviar o carro para a garagem mais próxima
Config.StreetParkVIPLimits = {
    default = 50,
    vip_gold = 100,
    vip_diamond = 200
}

-- Configurações de Parquímetros e Tickets
Config.ParkingMeterPricePerHour = 50 -- Custo por hora no parquímetro
Config.ParkingTicketItem = "parking_ticket" -- Item emitido no ox_inventory
Config.PoliceJobs = { "police", "sheriff" } -- Jobs autorizados a fiscalizar e aplicar multas
Config.PoliceFineAmount = 500 -- Valor da multa por parquímetro vencido

Config.NativeParkingMeterModels = {
    "prop_parkstat_01",
    "prop_parkstat_02",
    "prop_parkstat_03",
    "prop_parkingpay_01",
    "prop_parknmeter_01",
    "prop_parknmeter_02"
}

-- Parquímetros Customizados (Coordenadas extras onde props serão gerados automaticamente)
Config.CustomParkingMeters = {
    {
        model = "prop_parkstat_01",
        coords = vec4(232.11, -770.14, 30.6, 90.0)
    },
    {
        model = "prop_parkingpay_01",
        coords = vec4(-342.15, -890.45, 31.0, 180.0)
    }
}

-- Atendentes/NPCs (Peds) Padrão de Garagens Fixas
Config.GaragePedModel = "a_m_y_business_01"
Config.StoreDistance = 15.0 -- Raio máximo em metros para guardar veículo na garagem

Config.StoreCountdownSeconds = 5 -- Tempo em segundos até o veículo sumir após a saída de todos os ocupantes
Config.TowRecoveryFee = 500 -- Taxa para rebocar veículo retido de empresa/facção para a garagem central
Config.DefaultPublicGarage = "legion_square" -- Garagem de destino padrão do reboque de veículos retidos

-- Configurações de Manobrista NPC (Valet)
Config.ValetPrice = 150 -- Taxa de serviço do manobrista
Config.ValetPedModel = "s_m_m_valet_01" -- Modelo do Ped Manobrista (uniformizado)
Config.ValetDrivingStyle = 786603 -- Condução defensiva e respeitando tráfego
Config.ValetDrivingSpeed = 16.0 -- Velocidade de direção moderada (m/s)
Config.ValetTimeoutSeconds = 180 -- Timeout de segurança caso o trânsito tranque totalmente
Config.ValetCommand = "valet" -- Comando in-game para chamar o manobrista

-- =================================================================================
-- Gestão Avançada para Corporações (Fase 2)
-- Registro de Bordo (Logs da Corporação) & Restrição por Patente Mínima (minGrade)
-- =================================================================================
Config.LogCorporateGarages = true -- Habilita registro de histórico de uso em garagens job e gang
Config.MinGradeToViewLogs = 2 -- Patente mínima necessária para consultar o Livro de Bordo (0 = todos)
Config.CorporateLogCommand = "livrodebordo" -- Comando in-game para consultar o histórico

-- Tabela de patentes mínimas padrão por modelo para jobs e facções
Config.CorporateMinGrades = {
    -- Departamento de Polícia (LSPD)
    police = {
        ["police"] = 0,   -- Viatura Patrulha Cruiser (Recruta+)
        ["police2"] = 1,  -- Viatura Interceptor Buffalo (Oficial+)
        ["police3"] = 2,  -- Viatura SUV Interceptor (Sargento+)
        ["corvette"] = 3, -- Corvette High Speed Interceptor (Tenente/Capitão+)
        ["riot"] = 4,     -- Bearcat Blindado Tático (Comando+)
        ["polmav"] = 3    -- Helicóptero Águia Policial (Piloto Certificado 3+)
    },
    -- Departamento Médico / SAMU
    ambulance = {
        ["ambulance"] = 0,
        ["emsnspeedo"] = 1,
        ["polmav"] = 2
    },
    -- Gangues / Facções (ex: Vagos)
    vagos = {
        ["buccaneer"] = 0,
        ["primo"] = 0,
        ["chino"] = 1,
        ["manana"] = 1,
        ["tornado"] = 2,
        ["voodoo"] = 3
    }
}

-- =================================================================================
-- Garagens Fixas (Arquivo Exclusivo e Dedicado)
-- As garagens foram completamente desacopladas deste config.lua e ficam
-- armazenadas exclusivamente no arquivo dedicado:
--
--              📁 data/garages.json
--
-- Como gerenciar:
--   • In-Game: /criargaragem (ou /novagaragem) - Criação guiada em 4 passos
--   • In-Game: /gerenciargaragens (ou /garagensadmin) - Teleporte, edição e exclusão
--   • Manual: Edite diretamente o arquivo data/garages.json (com hot-reload imediato)
-- =================================================================================
Config.FixedGarages = {}

-- Configurações de Rastreador GPS & Jammer
Config.TrackerItem = "vehicle_tracker"
Config.JammerItem = "tracker_jammer"
Config.JammerDurationMinutes = 30

-- Configurações visuais
Config.DrawMarkerDistance = 20.0

