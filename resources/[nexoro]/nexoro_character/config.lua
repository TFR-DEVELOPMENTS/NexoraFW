Config = {}

Config.Character = {
    Slots = 3,                          -- base slots; players can have extra via nexoro_players.extra_slots
    MaxOutfits = 20,
    StartingMoney = { cash = 250.00, bank = 1500.00 },

    -- Each player is moved into their own routing bucket while choosing a character,
    -- so nobody sees other players' preview peds.
    SelectionBucketBase = 5000,

    DefaultSpawn = { x = 195.17, y = -933.77, z = 30.69, heading = 144.5 },

    -- Preview scene. Verify these coordinates in-game and adjust to taste.
    Scene = {
        ped = { x = -813.97, y = 176.22, z = 76.74, heading = 352.5 },
        cam = { x = -813.46, y = 178.95, z = 76.85 },
        fov = 38.0,
        lookAtHeight = 0.55,
    },
}
