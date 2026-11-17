Config = {}

Config.Scrapping = {
    JobName = 'scrapper',
    JobLabel = 'Scrap Collector',
    Salary = 10.50,
    CollectRadius = 8.0,
    CooldownSeconds = 600,         -- each point can be picked again after this long
    ScrapMin = 2,
    ScrapMax = 4,
    -- Collection points. Coordinates are placeholders: check them in-game. Shown on the map for scrap collectors.
    Points = {
        { id = 'paleto_yard', label = 'Paleto scrapyard', x = -441.0, y = 6024.0, z = 31.5 },
        { id = 'sandy_dump', label = 'Sandy Shores dump', x = 1728.0, y = 3311.0, z = 41.2 },
        { id = 'harmony_heap', label = 'Harmony scrap heap', x = 2661.0, y = 3327.0, z = 55.5 },
    },
}
