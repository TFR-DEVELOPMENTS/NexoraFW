Config = {}

-- price: what the shop charges. buyPrice (optional): what the shop pays when you sell to it.
-- stock: starting stock. restockPerHour: stock added per hour. maxStock: the most it holds.
Config.Shops = {
    high_street_convenience = { label = '24/7 High Street', x = 25.7, y = -1347.3, z = 29.5, radius = 3.0, items = {
        { item = 'water', price = 1.50, buyPrice = 0.60, stock = 40, restockPerHour = 10, maxStock = 60 },
        { item = 'sandwich', price = 3.20, buyPrice = 1.00, stock = 25, restockPerHour = 6, maxStock = 40 },
        { item = 'bread', price = 1.20, stock = 20, restockPerHour = 5, maxStock = 30 },
        { item = 'cheese', price = 2.10, stock = 15, restockPerHour = 4, maxStock = 25 },
        { item = 'bandage', price = 5.00, stock = 10, restockPerHour = 2, maxStock = 15 },
        { item = 'radio', price = 49.99, buyPrice = 20.00, stock = 4, restockPerHour = 1, maxStock = 6 },
        { item = 'phone', price = 199.99, buyPrice = 60.00, stock = 3, restockPerHour = 1, maxStock = 5 },
    } },
    hardware_yard = { label = 'Builders Yard', x = 199.0, y = -1647.0, z = 29.8, radius = 3.0, items = {
        { item = 'repair_kit', price = 75.00, buyPrice = 30.00, stock = 8, restockPerHour = 2, maxStock = 12 },
        { item = 'steel_part', price = 18.00, buyPrice = 6.00, stock = 20, restockPerHour = 4, maxStock = 30 },
        { item = 'scrap', price = 9.00, buyPrice = 3.00, stock = 30, restockPerHour = 6, maxStock = 40 },
    } },
}
