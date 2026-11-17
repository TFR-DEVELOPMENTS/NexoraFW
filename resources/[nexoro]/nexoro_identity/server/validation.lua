NexoroIdentity = {}
local cfg = Config.Identity

local ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function cleanText(s, maxChars)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[\0-\8\11\12\14-\31\127]', '')
    s = trim(s)
    local len = utf8.len(s)
    if not len then return nil end
    if len > maxChars then s = s:sub(1, utf8.offset(s, maxChars + 1) - 1) end
    return s
end

local function isLeap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
local function daysInMonth(y, m)
    local days = { 31, isLeap(y) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    return days[m]
end

local function nameAllowed(s)
    for _, cp in utf8.codes(s) do
        local ok = (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
            or (cp >= 0xC0 and cp <= 0x24F and cp ~= 0xD7 and cp ~= 0xF7)
            or cp == 32 or cp == 45 or cp == 39 or cp == 0x2019
        if not ok then return false end
    end
    return true
end

local function capitalise(s)
    local out, boundary = {}, true
    for _, cp in utf8.codes(s) do
        local ch = utf8.char(cp)
        if boundary and cp >= 97 and cp <= 122 then ch = ch:upper() end
        boundary = (cp == 32 or cp == 45 or cp == 39 or cp == 0x2019)
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function fail(field, code, message) return false, { field = field, code = code, message = message } end

local function validateName(field, label, value)
    local s = cleanText(value, 64)
    if not s then return fail(field, 'invalid', label .. ' is not valid text.') end
    s = s:gsub('%s+', ' ')
    local len = utf8.len(s)
    if len < cfg.MinNameLength or len > cfg.MaxNameLength then
        return fail(field, 'length', ('%s must be %d to %d characters.'):format(label, cfg.MinNameLength, cfg.MaxNameLength))
    end
    if not nameAllowed(s) then
        return fail(field, 'characters', label .. ' may only contain letters, spaces, hyphens and apostrophes.')
    end
    return true, capitalise(s)
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- now = { year, month, day } (defaults to today). Returns true, cleanData  or  false, { field, code, message }.
function NexoroIdentity.ValidateCharacter(data, now)
    if type(data) ~= 'table' then return fail('form', 'invalid', 'Invalid form data.') end
    local clean = {}

    local ok, first = validateName('firstName', 'First name', data.firstName)
    if not ok then return false, first end
    local ok2, last = validateName('lastName', 'Last name', data.lastName)
    if not ok2 then return false, last end
    local combined = (first .. ' ' .. last):lower()
    for _, part in ipairs(cfg.BlockedNameParts) do
        if combined:find(part, 1, true) then
            return fail('firstName', 'blocked', 'That name is not allowed. Choose a realistic name.')
        end
    end
    clean.firstName, clean.lastName = first, last

    local y, m, d = tostring(data.dob or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > daysInMonth(y, m) then
        return fail('dob', 'invalid', 'Enter a real date of birth.')
    end
    local today = now or os.date('*t')
    local age = today.year - y
    if today.month < m or (today.month == m and today.day < d) then age = age - 1 end
    if age < cfg.MinAge or age > cfg.MaxAge then
        return fail('dob', 'age', ('Your character must be between %d and %d years old.'):format(cfg.MinAge, cfg.MaxAge))
    end
    clean.dob = string.format('%04d-%02d-%02d', y, m, d)

    if type(data.gender) ~= 'string' or not contains(cfg.Genders, data.gender) then
        return fail('gender', 'invalid', 'Choose a gender from the list.')
    end
    clean.gender = data.gender

    if type(data.nationality) ~= 'string' or not contains(cfg.Nationalities, data.nationality) then
        return fail('nationality', 'invalid', 'Choose a nationality from the list.')
    end
    clean.nationality = data.nationality

    local height = tonumber(data.height)
    if not height or height ~= height or height < cfg.MinHeight or height > cfg.MaxHeight then
        return fail('height', 'range', ('Height must be %d to %d cm.'):format(cfg.MinHeight, cfg.MaxHeight))
    end
    clean.height = math.floor(height)

    local bio = data.biography == nil and '' or cleanText(data.biography, cfg.MaxBiography)
    if bio == nil then return fail('biography', 'invalid', 'Biography is not valid text.') end
    clean.biography = bio

    return true, clean
end

math.randomseed(os.time() + GetGameTimer())

function NexoroIdentity.GenerateCitizenId()
    local id = {}
    for i = 1, cfg.CitizenIdRandomLength do
        local n = math.random(1, #ALPHABET)
        id[i] = ALPHABET:sub(n, n)
    end
    return cfg.CitizenIdPrefix .. table.concat(id)
end

function NexoroIdentity.IsValidCitizenId(id)
    if type(id) ~= 'string' then return false end
    local expected = #cfg.CitizenIdPrefix + cfg.CitizenIdRandomLength
    return #id == expected and id:sub(1, #cfg.CitizenIdPrefix) == cfg.CitizenIdPrefix
        and id:sub(#cfg.CitizenIdPrefix + 1):match('^[' .. ALPHABET .. ']+$') ~= nil
end
