Config = {}

Config.Civilian = {
    -- The job centre: where people take a job. Coordinates are placeholders: check in-game.
    JobCentre = { label = 'Job Centre', x = 230.0, y = -415.0, z = 47.1, radius = 3.0 },
    TaskRadius = 6.0,
    -- Each job: pay per task, seconds before the same point can pay again for the same player, and the points.
    Jobs = {
        bus_driver = { label = 'Bus Driver', salary = 12.00, pay = 40.00, cooldown = 300, points = {
            { id = 'bus_depot', label = 'Bus depot', x = 452.0, y = -602.0, z = 28.6 },
            { id = 'bus_stop_hw', label = 'Bus stop, Hawick', x = 233.0, y = -1321.0, z = 29.3 } } },
        mechanic = { label = 'Mechanic', salary = 13.00, pay = 60.00, cooldown = 300, points = {
            { id = 'garage_bay_1', label = 'Garage bay 1', x = -337.0, y = -136.0, z = 39.0 },
            { id = 'garage_bay_2', label = 'Garage bay 2', x = -331.0, y = -141.0, z = 39.0 } } },
        cleaner = { label = 'Cleaner', salary = 10.50, pay = 25.00, cooldown = 180, points = {
            { id = 'office_block', label = 'Office block', x = -141.0, y = -621.0, z = 168.8 },
            { id = 'shop_back', label = 'Shop back room', x = 26.0, y = -1345.0, z = 29.5 } } },
        builder = { label = 'Builder', salary = 13.50, pay = 55.00, cooldown = 420, points = {
            { id = 'site_north', label = 'North building site', x = -140.0, y = -1000.0, z = 24.0 },
            { id = 'site_south', label = 'South building site', x = 480.0, y = -1040.0, z = 28.0 } } },
        cashier = { label = 'Cashier', salary = 11.00, pay = 30.00, cooldown = 240, points = {
            { id = 'till_convenience', label = 'Convenience till', x = 25.7, y = -1347.3, z = 29.5 } } },
        gardener = { label = 'Gardener', salary = 10.00, pay = 25.00, cooldown = 240, points = {
            { id = 'park_beds', label = 'Park flower beds', x = -1398.0, y = -1487.0, z = 2.4 },
            { id = 'vinewood_lawn', label = 'Vinewood lawn', x = 225.0, y = 40.0, z = 88.0 } } },
        courier = { label = 'Courier', salary = 12.00, pay = 45.00, cooldown = 300, points = {
            { id = 'depot_collect', label = 'Depot collection', x = -20.0, y = -1100.0, z = 26.7 },
            { id = 'depot_drop', label = 'Depot drop-off', x = 240.0, y = -1000.0, z = 29.3 } } },
        lifeguard = { label = 'Lifeguard', salary = 12.50, pay = 35.00, cooldown = 300, points = {
            { id = 'vespucci_tower', label = 'Vespucci beach tower', x = -1436.0, y = -1482.0, z = 3.0 } } },
    },
}
