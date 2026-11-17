local cfg = Config.Character
local ui = { open = false, mode = nil }
local cam = nil
local lastApplied = nil

local function setNuiOpen(open)
    SetNuiFocus(open, open)
end

local function closeUi()
    SendNUIMessage({ action = 'close' })
    setNuiOpen(false)
    ui.open, ui.mode = false, nil
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function setupScene()
    local s = cfg.Scene
    DoScreenFadeOut(0)
    local model = GetEntityModel(PlayerPedId())
    if model ~= GetHashKey('mp_m_freemode_01') and model ~= GetHashKey('mp_f_freemode_01') then
        NexoroApp.SetModel('mp_m_freemode_01')
    end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(s.ped.x, s.ped.y, s.ped.z)
    SetEntityCoordsNoOffset(ped, s.ped.x, s.ped.y, s.ped.z, false, false, false)
    SetEntityHeading(ped, s.ped.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    DisplayRadar(false)
    DisplayHud(false)
    NetworkOverrideClockTime(12, 0, 0)

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', s.cam.x, s.cam.y, s.cam.z, 0.0, 0.0, 0.0, s.fov, false, 0)
    PointCamAtCoord(cam, s.ped.x, s.ped.y, s.ped.z + s.lookAtHeight)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    local deadline = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(0) end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(600)
end

local function openSelection()
    if ui.open then return end
    ui.open, ui.mode = true, 'select'
    setupScene()
    local ok, data = NexoroCore.Callback('nexoro_character:list')
    if not ok then
        print(('^1[Nexoro] could not load characters: %s^7'):format(tostring(data)))
        closeUi()
        return
    end
    SendNUIMessage({ action = 'open', screen = 'select', characters = data.characters, slots = data.slots, options = data.options })
    setNuiOpen(true)
end

local function enterWorld(data)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    closeUi()

    local spawn = data.spawn
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    NexoroApp.Apply(data.appearance)
    lastApplied = data.appearance

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.heading + 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, math.max(data.health or 200, 120))
    SetPedArmour(ped, data.armour or 0)
    NetworkClearClockTimeOverride()

    local deadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(0) end
    DisplayRadar(true)
    DisplayHud(true)
    DoScreenFadeIn(800)
    TriggerServerEvent('nexoro:server:characterSpawned')
    TriggerEvent('nexoro:character:spawned')
end

---------------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------------

RegisterNUICallback('select', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:select', { id = data.id })
    if not ok then return cb({ ok = false, error = result }) end
    cb({ ok = true })
    CreateThread(function() enterWorld(result) end)
end)

RegisterNUICallback('create', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:create', { identity = data.identity, appearance = data.appearance })
    if not ok then return cb({ ok = false, error = result }) end
    local selected, spawnData = NexoroCore.Callback('nexoro_character:select', { id = result.id })
    if not selected then return cb({ ok = false, error = spawnData }) end
    cb({ ok = true })
    CreateThread(function() enterWorld(spawnData) end)
end)

RegisterNUICallback('delete', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:delete', { id = data.id, citizenId = data.citizenId })
    if not ok then return cb({ ok = false, error = result }) end
    cb({ ok = true, characters = result.characters, slots = result.slots })
end)

RegisterNUICallback('preview', function(data, cb)
    CreateThread(function()
        NexoroApp.Apply(data.appearance)
        cb({ ok = true, limits = NexoroApp.GetLimits() })
    end)
end)

RegisterNUICallback('rotate', function(data, cb)
    local degrees = tonumber(data.degrees) or 0.0
    SetEntityHeading(PlayerPedId(), cfg.Scene.ped.heading + degrees)
    cb({ ok = true })
end)

RegisterNUICallback('textureCount', function(data, cb)
    cb({ ok = true, count = NexoroApp.TextureCount(data.kind, tonumber(data.id) or 0, tonumber(data.drawable) or 0) })
end)

RegisterNUICallback('saveAppearance', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:saveAppearance', { appearance = data.appearance })
    if ok then lastApplied = data.appearance end
    cb({ ok = ok, error = not ok and result or nil })
end)

RegisterNUICallback('listOutfits', function(_, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:listOutfits')
    cb({ ok = ok, outfits = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:saveOutfit', { name = data.name, appearance = data.appearance })
    cb({ ok = ok, outfits = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    local ok, result = NexoroCore.Callback('nexoro_character:deleteOutfit', { id = data.id })
    cb({ ok = ok, outfits = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('closeWardrobe', function(_, cb)
    if ui.mode == 'wardrobe' then
        if lastApplied then NexoroApp.Apply(lastApplied) end -- discard unsaved changes
        closeUi()
    end
    cb({ ok = true })
end)

---------------------------------------------------------------------------
-- Flow
---------------------------------------------------------------------------

AddEventHandler('nexoro:client:playerReadyLocal', function(state)
    if state and state.characterLoaded then return end
    openSelection()
end)

RegisterNetEvent('nexoro:character:openSelect', function()
    lastApplied = nil
    openSelection()
end)

-- Covers this resource starting after nexoro_core (normal boot order) or restarting mid-session.
CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while GetGameTimer() < deadline do
        local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
        if ok and ready then break end
        Wait(500)
    end
    local ok, state = NexoroCore.Callback('nexoro_core:getSessionState')
    if ok and state and not state.characterLoaded then openSelection() end
end)

RegisterCommand('wardrobe', function()
    if ui.open then return end
    local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
    if not okLoaded or not loaded then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    if not lastApplied then
        local ok, app = NexoroCore.Callback('nexoro_character:getAppearance')
        if not ok then return end
        lastApplied = app
    end
    ui.open, ui.mode = true, 'wardrobe'
    SendNUIMessage({ action = 'open', screen = 'wardrobe', appearance = lastApplied, limits = NexoroApp.GetLimits() })
    setNuiOpen(true)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui.open then closeUi() end
    DisplayRadar(true)
    DisplayHud(true)
end)

exports('ApplyAppearance', function(app) NexoroApp.Apply(app) end)
