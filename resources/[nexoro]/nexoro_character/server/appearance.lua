NexoroAppearance = {}

local MALE, FEMALE = 'mp_m_freemode_01', 'mp_f_freemode_01'
local PROP_IDS = { 0, 1, 2, 6, 7 }
local MAX_DRAWABLE, MAX_TEXTURE = 600, 80

local function int(v, lo, hi, default)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return default end
    n = math.floor(n)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function num(v, lo, hi, default)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return default end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function tbl(v) return type(v) == 'table' and v or {} end

function NexoroAppearance.Default(model)
    return NexoroAppearance.Validate({ model = model == FEMALE and FEMALE or MALE })
end

-- Returns true, cleanAppearance  or  false, errorCode. Unknown keys are dropped; every value is clamped.
function NexoroAppearance.Validate(data)
    if type(data) ~= 'table' then return false, 'invalid_appearance' end
    if data.model ~= MALE and data.model ~= FEMALE then return false, 'invalid_model' end

    local out = { model = data.model }
    local hb = tbl(data.headBlend)
    out.headBlend = {
        shapeFirst = int(hb.shapeFirst, 0, 45, 0), shapeSecond = int(hb.shapeSecond, 0, 45, 0),
        skinFirst = int(hb.skinFirst, 0, 45, 0), skinSecond = int(hb.skinSecond, 0, 45, 0),
        shapeMix = num(hb.shapeMix, 0, 1, 0.5), skinMix = num(hb.skinMix, 0, 1, 0.5),
    }

    local ff = tbl(data.faceFeatures)
    out.faceFeatures = {}
    for i = 1, 20 do out.faceFeatures[i] = num(ff[i], -1, 1, 0.0) end

    local ov = tbl(data.headOverlays)
    out.headOverlays = {}
    for i = 1, 13 do
        local o = tbl(ov[i])
        out.headOverlays[i] = { style = int(o.style, -1, 255, -1), opacity = num(o.opacity, 0, 1, 1.0), color = int(o.color, 0, 63, 0) }
    end

    local h = tbl(data.hair)
    out.hair = { style = int(h.style, 0, 255, 0), color = int(h.color, 0, 63, 0), highlight = int(h.highlight, 0, 63, 0) }
    out.eyeColor = int(data.eyeColor, 0, 31, 0)

    local comps = tbl(data.components)
    out.components = {}
    for i = 1, 12 do
        local c = tbl(comps[i])
        out.components[i] = { drawable = int(c.drawable, 0, MAX_DRAWABLE, 0), texture = int(c.texture, 0, MAX_TEXTURE, 0) }
    end

    local props = tbl(data.props)
    out.props = {}
    for i, id in ipairs(PROP_IDS) do
        local p = tbl(props[i])
        out.props[i] = { id = id, drawable = int(p.drawable, -1, MAX_DRAWABLE, -1), texture = int(p.texture, 0, MAX_TEXTURE, 0) }
    end

    if #json.encode(out) > 6000 then return false, 'appearance_too_large' end
    return true, out
end

-- Clothing-only subset used for saved outfits.
function NexoroAppearance.OutfitFrom(clean)
    return { components = clean.components, props = clean.props }
end

function NexoroAppearance.ValidateOutfit(data)
    if type(data) ~= 'table' then return false, 'invalid_outfit' end
    local ok, clean = NexoroAppearance.Validate({ model = MALE, components = data.components, props = data.props })
    if not ok then return false, clean end
    return true, NexoroAppearance.OutfitFrom(clean)
end
