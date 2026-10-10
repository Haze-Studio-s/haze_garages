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

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_nicknames (
            plate VARCHAR(32) NOT NULL,
            nickname VARCHAR(64) NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_trackers (
            plate VARCHAR(32) NOT NULL,
            installed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            installed_by VARCHAR(100) DEFAULT NULL,
            jammed_until TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_impounds (
            plate VARCHAR(32) NOT NULL,
            reason VARCHAR(255) DEFAULT 'Apreensão Policial',
            fine_amount INT DEFAULT 0,
            impounded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            duration_minutes INT DEFAULT 0,
            impounded_by VARCHAR(100) DEFAULT NULL,
            impound_lot VARCHAR(64) DEFAULT 'impound_main',
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE haze_vehicle_nicknames CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE haze_vehicle_trackers CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        MySQL.query.await("ALTER TABLE haze_vehicle_impounds CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_garage_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            garage_id VARCHAR(64) NOT NULL,
            plate VARCHAR(32) NOT NULL,
            model VARCHAR(64) DEFAULT 'Desconhecido',
            citizenid VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NOT NULL,
            action VARCHAR(20) NOT NULL,
            fuel FLOAT DEFAULT 100.0,
            engine_health FLOAT DEFAULT 1000.0,
            body_health FLOAT DEFAULT 1000.0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_garage (garage_id),
            INDEX idx_plate (plate),
            INDEX idx_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE haze_garage_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS haze_vehicle_coowners (
            plate VARCHAR(32) NOT NULL PRIMARY KEY,
            owner_citizenid VARCHAR(100) NOT NULL,
            coowner_citizenid VARCHAR(100) NOT NULL,
            coowner_name VARCHAR(100) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_coowner (coowner_citizenid),
            INDEX idx_owner (owner_citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE haze_vehicle_coowners CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    end)

    print("^2[Haze Garages]^7 Tabelas de banco de dados inicializadas e verificadas com sucesso.")
end)


