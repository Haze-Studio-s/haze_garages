MySQL.ready(function()
    pcall(function()
        MySQL.query.await("ALTER TABLE haze_street_parking CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE haze_fixed_garages CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE haze_parking_meters CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE haze_vehicle_deformations CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE granolla_vehicle_wear CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_street_parking (
            plate VARCHAR(32) NOT NULL,
            citizenid VARCHAR(100) NOT NULL,
            coords TEXT NOT NULL,
            model VARCHAR(64) DEFAULT NULL,
            cost_paid INT DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE haze_street_parking ADD COLUMN IF NOT EXISTS model VARCHAR(64) DEFAULT NULL;")
        MySQL.query.await("UPDATE haze_street_parking SET model = NULL WHERE model LIKE '-%' OR model = '3345191406';")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_fixed_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            garage_id VARCHAR(64) NOT NULL,
            citizenid VARCHAR(100) NOT NULL,
            purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY (garage_id, citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_parking_meters (
            id INT AUTO_INCREMENT PRIMARY KEY,
            meter_key VARCHAR(128) NOT NULL UNIQUE,
            hours_left INT DEFAULT 0,
            expires_at TIMESTAMP NULL DEFAULT NULL,
            payer_name VARCHAR(100) DEFAULT NULL,
            payer_phone VARCHAR(50) DEFAULT NULL,
            citizenid VARCHAR(100) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE haze_parking_meters ADD COLUMN IF NOT EXISTS payer_name VARCHAR(100) DEFAULT NULL;")
        MySQL.query.await("ALTER TABLE haze_parking_meters ADD COLUMN IF NOT EXISTS payer_phone VARCHAR(50) DEFAULT NULL;")
        MySQL.query.await("ALTER TABLE haze_parking_meters ADD COLUMN IF NOT EXISTS citizenid VARCHAR(100) DEFAULT NULL;")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_deformations (
            plate VARCHAR(32) NOT NULL,
            deformation LONGTEXT NULL,
            mechanical_damage LONGTEXT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS granolla_vehicle_wear (
            plate VARCHAR(32) NOT NULL,
            wear_data LONGTEXT NULL,
            mileage FLOAT DEFAULT 0.0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    print("^2[Haze Garages]^7 Tabelas de banco de dados inicializadas e verificadas com sucesso.")
end)
