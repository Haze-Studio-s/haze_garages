MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_street_parking (
            plate VARCHAR(32) NOT NULL,
            citizenid VARCHAR(100) NOT NULL,
            coords TEXT NOT NULL,
            cost_paid INT DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_fixed_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            garage_id VARCHAR(64) NOT NULL,
            citizenid VARCHAR(100) NOT NULL,
            purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY (garage_id, citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_parking_meters (
            id INT AUTO_INCREMENT PRIMARY KEY,
            meter_key VARCHAR(128) NOT NULL UNIQUE,
            hours_left INT DEFAULT 0,
            expires_at TIMESTAMP NULL DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_deformations (
            plate VARCHAR(32) NOT NULL,
            deformation LONGTEXT NULL,
            mechanical_damage LONGTEXT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    print("^2[Haze Garages]^7 Tabelas de banco de dados inicializadas e verificadas com sucesso.")
end)
