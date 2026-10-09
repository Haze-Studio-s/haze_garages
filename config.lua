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

-- Adereços de Terminal para Garagens Fixas (Substitui peds por props)
Config.GarageTerminalProp = "prop_parkstat_01"

-- Garagens Fixas no Mapa (Públicas, Corporativas/Job e Gangues)
Config.FixedGarages = {
    ["legion_square"] = {
        label = "Garagem Central - Praça Legion",
        type = "public",
        category = "car",
        coords = vec4(215.12, -810.55, 30.7, 140.0),
        spawnCoords = vec4(222.10, -805.20, 30.6, 140.0),
        price = 0
    },
    ["pillbox_roof"] = {
        label = "Heliponto Hospital Pillbox",
        type = "public",
        category = "plane",
        coords = vec4(352.10, -588.20, 74.16, 70.0),
        spawnCoords = vec4(348.50, -587.10, 74.16, 70.0),
        price = 0
    },
    ["marina_boat"] = {
        label = "Marina de Los Santos",
        type = "public",
        category = "boat",
        coords = vec4(-735.40, -1320.10, 1.6, 180.0),
        spawnCoords = vec4(-730.10, -1330.50, 0.5, 180.0),
        price = 0
    },
    ["police_main"] = {
        label = "Garagem Departamento de Polícia (LSPD)",
        type = "job",
        job = "police",
        category = "car",
        coords = vec4(441.10, -981.20, 30.6, 90.0),
        spawnCoords = vec4(447.20, -981.20, 30.6, 90.0),
        price = 0
    },
    ["vagos_base"] = {
        label = "Garagem Facção Vagos",
        type = "gang",
        gang = "vagos",
        category = "car",
        coords = vec4(335.50, -2012.30, 20.8, 45.0),
        spawnCoords = vec4(340.10, -2015.40, 20.8, 45.0),
        price = 0
    }
}

-- Configurações visuais
Config.DrawMarkerDistance = 20.0
