NexoroApp = {}

local PROP_IDS = { 0, 1, 2, 6, 7 }
-- overlay index (0-based) -> colour type: 1 = hair colours, 2 = makeup colours
local OVERLAY_COLOUR_TYPE = { [1] = 1, [2] = 1, [10] = 1, [4] = 2, [5] = 2, [8] = 2 }

local applying, queued = false, nil

local function loadPlayerModel(name)
    local hash = GetHashKey(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return false end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    return true
end

function NexoroApp.SetModel(name)
    if GetEntityModel(PlayerPedId()) == GetHashKey(name) then return true end
    if not loadPlayerModel(name) then return false end
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

local function applyNow(app)
    if not NexoroApp.SetModel(app.model) then return end
    local ped = PlayerPedId()
    local hb = app.headBlend
    SetPedHeadBlendData(ped, hb.shapeFirst, hb.shapeSecond, 0, hb.skinFirst, hb.skinSecond, 0, hb.shapeMix + 0.0, hb.skinMix + 0.0, 0.0, false)
    for i = 1, 20 do SetPedFaceFeature(ped, i - 1, app.faceFeatures[i] + 0.0) end
    for i = 1, 13 do
        local overlay, index = app.headOverlays[i], i - 1
        SetPedHeadOverlay(ped, index, overlay.style < 0 and 255 or overlay.style, overlay.opacity + 0.0)
        local colourType = OVERLAY_COLOUR_TYPE[index]
        if colourType then SetPedHeadOverlayColor(ped, index, colourType, overlay.color, overlay.color) end
    end
    local hairMax = math.max(GetNumberOfPedDrawableVariations(ped, 2) - 1, 0)
    SetPedComponentVariation(ped, 2, math.min(app.hair.style, hairMax), 0, 0)
    SetPedHairColor(ped, app.hair.color, app.hair.highlight)
    SetPedEyeColor(ped, app.eyeColor)

    for i = 1, 12 do
        local component = i - 1
        if component ~= 0 and component ~= 2 then
            local c = app.components[i]
            local drawable = math.min(c.drawable, math.max(GetNumberOfPedDrawableVariations(ped, component) - 1, 0))
            local texture = math.min(c.texture, math.max(GetNumberOfPedTextureVariations(ped, component, drawable) - 1, 0))
            SetPedComponentVariation(ped, component, drawable, texture, 2)
        end
    end
    for _, p in ipairs(app.props) do
        if p.drawable < 0 or p.drawable >= GetNumberOfPedPropDrawableVariations(ped, p.id) then
            ClearPedProp(ped, p.id)
        else
            local texture = math.min(p.texture, math.max(GetNumberOfPedPropTextureVariations(ped, p.id, p.drawable) - 1, 0))
            SetPedPropIndex(ped, p.id, p.drawable, texture, true)
        end
    end
end

-- Calls made while a model swap is in progress are coalesced: only the latest appearance is applied.
function NexoroApp.Apply(app)
    if type(app) ~= 'table' or type(app.model) ~= 'string' then return end
    if applying then queued = app; return end
    applying = true
    applyNow(app)
    while queued do
        local nextApp = queued
        queued = nil
        applyNow(nextApp)
    end
    applying = false
end

function NexoroApp.GetLimits()
    local ped = PlayerPedId()
    local limits = {
        components = {}, props = {}, overlays = {},
        hairColours = GetNumHairColors(), makeupColours = GetNumMakeupColors(),
    }
    for component = 0, 11 do limits.components[component + 1] = GetNumberOfPedDrawableVariations(ped, component) end
    for i, id in ipairs(PROP_IDS) do limits.props[i] = GetNumberOfPedPropDrawableVariations(ped, id) end
    for index = 0, 12 do limits.overlays[index + 1] = GetPedHeadOverlayNum(index) end
    return limits
end

function NexoroApp.TextureCount(kind, id, drawable)
    local ped = PlayerPedId()
    if kind == 'prop' then return GetNumberOfPedPropTextureVariations(ped, id, drawable) end
    return GetNumberOfPedTextureVariations(ped, id, drawable)
end
