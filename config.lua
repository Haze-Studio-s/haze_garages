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

-- Garagens Fixas no Mapa (Públicas, Corporativas/Job e Gangues)
Config.FixedGarages = {
    ["legion_square"] = {
        label = "Garagem Central - Praça Legion",
        type = "public",
        category = "car",
        coords = vec4(215.12, -810.55, 30.7, 140.0),
        dropZone = {
            points = {
                vec3(210.50, -792.00, 30.6),
                vec3(220.50, -792.00, 30.6),
                vec3(220.50, -805.00, 30.6),
                vec3(210.50, -805.00, 30.6)
            },
            thickness = 6.0
        },
        spawnCoords = {
            vec4(222.10, -805.20, 30.6, 140.0),
            vec4(225.80, -803.50, 30.6, 140.0),
            vec4(229.50, -801.80, 30.6, 140.0),
            vec4(233.20, -800.10, 30.6, 140.0)
        },
        pedModel = "a_m_y_business_01",
        blip = { sprite = 357, color = 3, scale = 0.75 },
        price = 0
    },
    ["pillbox_roof"] = {
        label = "Heliponto Hospital Pillbox",
        type = "public",
        category = "plane",
        coords = vec4(352.10, -588.20, 74.16, 70.0),
        dropZone = {
            points = {
                vec3(343.00, -580.00, 74.16),
                vec3(358.00, -580.00, 74.16),
                vec3(358.00, -596.00, 74.16),
                vec3(343.00, -596.00, 74.16)
            },
            thickness = 8.0
        },
        spawnCoords = {
            vec4(348.50, -587.10, 74.16, 70.0),
            vec4(354.20, -594.30, 74.16, 70.0)
        },
        pedModel = "s_m_m_doctor_01",
        blip = { sprite = 423, color = 3, scale = 0.75 },
        price = 0
    },
    ["marina_boat"] = {
        label = "Marina de Los Santos",
        type = "public",
        category = "boat",
        coords = vec4(-735.40, -1320.10, 1.6, 180.0),
        dropZone = {
            points = {
                vec3(-716.00, -1320.00, 0.5),
                vec3(-734.00, -1320.00, 0.5),
                vec3(-734.00, -1340.00, 0.5),
                vec3(-716.00, -1340.00, 0.5)
            },
            thickness = 10.0
        },
        spawnCoords = {
            vec4(-730.10, -1330.50, 0.5, 180.0),
            vec4(-723.40, -1335.20, 0.5, 180.0),
            vec4(-716.80, -1339.80, 0.5, 180.0)
        },
        pedModel = "s_m_m_dockwork_01",
        blip = { sprite = 410, color = 3, scale = 0.75 },
        price = 0
    },
    ["police_main"] = {
        label = "Garagem Departamento de Polícia (LSPD)",
        type = "job",
        job = "police",
        category = "car",
        coords = vec4(441.10, -981.20, 30.6, 90.0),
        dropZone = {
            points = {
                vec3(435.00, -988.00, 30.6),
                vec3(447.00, -988.00, 30.6),
                vec3(447.00, -1002.00, 30.6),
                vec3(435.00, -1002.00, 30.6)
            },
            thickness = 6.0
        },
        spawnCoords = {
            vec4(447.20, -981.20, 30.6, 90.0),
            vec4(447.20, -985.40, 30.6, 90.0),
            vec4(447.20, -989.60, 30.6, 90.0),
            vec4(447.20, -993.80, 30.6, 90.0)
        },
        pedModel = "s_m_y_cop_01",
        blip = { sprite = 60, color = 38, scale = 0.8 },
        price = 0
    },
    ["vagos_base"] = {
        label = "Garagem Facção Vagos",
        type = "gang",
        gang = "vagos",
        category = "car",
        coords = vec4(335.50, -2012.30, 20.8, 45.0),
        dropZone = {
            points = {
                vec3(332.00, -2004.00, 20.8),
                vec3(345.00, -2004.00, 20.8),
                vec3(345.00, -2017.00, 20.8),
                vec3(332.00, -2017.00, 20.8)
            },
            thickness = 6.0
        },
        spawnCoords = {
            vec4(340.10, -2015.40, 20.8, 45.0),
            vec4(344.20, -2018.70, 20.8, 45.0),
            vec4(348.50, -2022.10, 20.8, 45.0)
        },
        pedModel = "g_m_y_salvagoon_01",
        blip = { sprite = 84, color = 5, scale = 0.8 },
        price = 0
    },
    ["impound_main"] = {
        label = "Pátio de Apreensão Policial (Impound)",
        type = "impound",
        category = "car",
        coords = vec4(409.12, -1623.55, 29.3, 230.0),
        dropZone = {
            points = {
                vec3(393.00, -1622.00, 29.3),
                vec3(407.00, -1622.00, 29.3),
                vec3(407.00, -1638.00, 29.3),
                vec3(393.00, -1638.00, 29.3)
            },
            thickness = 6.0
        },
        spawnCoords = {
            vec4(404.10, -1630.20, 29.3, 230.0),
            vec4(400.50, -1634.40, 29.3, 230.0),
            vec4(396.80, -1638.60, 29.3, 230.0)
        },
        pedModel = "s_m_y_valet_01",
        blip = { sprite = 67, color = 1, scale = 0.75 },
        price = 0
    }
}

-- Configurações de Rastreador GPS & Jammer
Config.TrackerItem = "vehicle_tracker"
Config.JammerItem = "tracker_jammer"
Config.JammerDurationMinutes = 30

-- Configurações visuais
Config.DrawMarkerDistance = 20.0

