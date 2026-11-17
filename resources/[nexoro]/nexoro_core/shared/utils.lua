Nexoro = Nexoro or {}
Nexoro.Utils = Nexoro.Utils or {}
local U = Nexoro.Utils

function U.Trim(s)
    return (tostring(s):gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.IsFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

function U.Clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

-- Accepts numbers or numeric strings; returns an integer or nil.
function U.ToInt(v)
    local n = tonumber(v)
    if not n or not U.IsFinite(n) then return nil end
    return math.tointeger(n)
end

-- Pounds (number) -> integer pence. Rejects negatives, NaN/inf and sub-penny precision.
function U.ToPence(amount)
    if not U.IsFinite(amount) then return nil, 'not_a_number' end
    if amount < 0 then return nil, 'negative' end
    local pence = math.floor(amount * 100 + 0.5)
    if math.abs(amount * 100 - pence) > 1e-6 then return nil, 'sub_penny_precision' end
    if pence > 9007199254740991 then return nil, 'too_large' end
    return math.tointeger(pence)
end

-- Integer pence -> "£1,250.00"
function U.FormatGBP(pence)
    pence = math.floor(tonumber(pence) or 0)
    local sign = pence < 0 and '-' or ''
    local n = math.abs(pence)
    local pounds, rest = n // 100, n % 100
    local grouped = tostring(pounds):reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if grouped:sub(1, 1) == ',' then grouped = grouped:sub(2) end
    return string.format('%s£%s.%02d', sign, grouped, rest)
end

-- Strips control characters, trims, validates UTF-8 and limits length (in characters).
function U.SanitizeText(s, maxChars)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[\0-\8\11\12\14-\31\127]', '')
    s = U.Trim(s)
    local len = utf8.len(s)
    if not len then return nil end
    if len > maxChars then s = s:sub(1, utf8.offset(s, maxChars + 1) - 1) end
    return s
end

-- Permission matching: exact, "*" and "prefix.*".
function U.PermissionMatches(pattern, permission)
    if pattern == '*' or pattern == permission then return true end
    if pattern:sub(-2) == '.*' then
        local prefix = pattern:sub(1, -3)
        return permission == prefix or permission:sub(1, #prefix + 1) == prefix .. '.'
    end
    return false
end

function U.DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do copy[U.DeepCopy(k, seen)] = U.DeepCopy(v, seen) end
    return copy
end
