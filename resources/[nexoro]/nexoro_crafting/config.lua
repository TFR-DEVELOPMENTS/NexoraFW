Config = {}

Config.Crafting = {
    Stations = {
        { id = 'workbench_harbour', label = 'Harbour Workbench', x = 215.0, y = -1643.0, z = 29.8, radius = 3.0 },
    },
    -- ingredients: { item, amount }. time: progress bar length in milliseconds.
    Recipes = {
        { id = 'sandwich', label = 'Make a cheese sandwich', time = 3000, result = { item = 'sandwich', amount = 1 },
          ingredients = { { item = 'bread', amount = 1 }, { item = 'cheese', amount = 1 } } },
        { id = 'lockpick', label = 'Cut a lockpick', time = 4000, result = { item = 'lockpick', amount = 1 },
          ingredients = { { item = 'steel_part', amount = 1 } } },
        { id = 'repair_kit', label = 'Build a repair kit', time = 8000, result = { item = 'repair_kit', amount = 1 },
          ingredients = { { item = 'scrap', amount = 3 }, { item = 'steel_part', amount = 1 } } },
    },
}
