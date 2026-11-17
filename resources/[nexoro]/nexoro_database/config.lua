Config = {}

-- Migrations are discovered in every resource whose name starts with "nexoro_"
-- (file: sql/migrations.json). Resources listed here run first, in this order.
Config.MigrationOrder = {
    'nexoro_database',
    'nexoro_core',
    'nexoro_identity',
    'nexoro_character',
    'nexoro_banking',
    'nexoro_inventory',
    'nexoro_admin',
    'nexoro_phone',
    'nexoro_vehicles',
    'nexoro_garages',
    'nexoro_dealerships',
    'nexoro_police',
    'nexoro_ambulance',
    'nexoro_fire',
    'nexoro_dispatch',
    'nexoro_prison',
    'nexoro_housing',
    'nexoro_businesses',
    'nexoro_licences',
    'nexoro_auctions',
    'nexoro_farming',
    'nexoro_crime',
    'nexoro_gambling',
    'nexoro_lottery',
    'nexoro_crews',
    'nexoro_encampments',
}

-- How long to wait for oxmysql to accept connections before giving up.
Config.ConnectTimeoutSeconds = 30
Config.Debug = false
