local cfg = Config
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroDealerships = {}
NexoroDealerships.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function near(src, id)
    local def = type(id) == 'string' and cfg.Dealerships[id]
    if not def then return nil, 'unknown_dealership' end
    local pos = NexoroDealerships.getCoords(src)
    if not pos then return nil, 'no_position' end
    if math.sqrt((pos.x - def.x) ^ 2 + (pos.y - def.y) ^ 2 + (pos.z - def.z) ^ 2) > def.radius + 2.0 then return nil, 'too_far' end
    return def
end

-- A catalogue entry may name a resource it needs (for example an optional car pack). It is only listed and sold while that resource runs.
local function available(v)
    return v.requires == nil or GetResourceState(v.requires) == 'started'
end

local function find(def, model)
    for _, v in ipairs(def.catalogue) do
        if v.model == model and available(v) then return v end
    end
    return nil
end

local function catalogue(src, p)
    local def, why = near(src, type(p) == 'table' and p.id)
    if not def then return false, why end
    local list = {}
    for _, v in ipairs(def.catalogue) do
        if available(v) then list[#list + 1] = { model = v.model, label = v.label, category = v.category, price = v.price, priceText = core().FormatGBP(math.floor(v.price * 100 + 0.5)) } end
    end
    return true, { label = def.label, vehicles = list }
end

local function terms(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.id)
    if not def then return false, why end
    local v = find(def, p.model)
    if not v then return false, 'not_for_sale' end
    local t, err = exports.nexoro_vehicles:FinanceTerms(v.price, p.deposit)
    if not t then return false, err end
    local fmt = core().FormatGBP
    return true, { deposit = fmt(t.deposit), remaining = fmt(t.remaining), payment = fmt(t.payment) }
end

local function purchase(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.id)
    if not def then return false, why end
    local v = find(def, p.model)
    if not v then return false, 'not_for_sale' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local method = p.method
    if method ~= 'cash' and method ~= 'bank' and method ~= 'finance' then return false, 'invalid_method' end

    local financeTerms, paid
    if method == 'finance' then
        local t, err = exports.nexoro_vehicles:FinanceTerms(v.price, p.deposit)
        if not t then return false, err end
        financeTerms, paid = t, t.deposit
    else
        paid = core().ToPence(v.price)
    end
    local ok, err = core().RemoveMoney(src, paid / 100, method == 'cash' and 'cash' or 'bank', 'dealership: ' .. v.model)
    if not ok then return false, err end

    local plate, id = exports.nexoro_vehicles:Register(c.id, v.model, {
        price = v.price, garage = def.garage, actor = c.firstName .. ' ' .. c.lastName,
        finance = financeTerms and { remaining = financeTerms.remaining, payment = financeTerms.payment, nextDue = financeTerms.nextDue } or nil,
    })
    if not plate then
        core().AddMoney(src, paid / 100, method == 'cash' and 'cash' or 'bank', 'refund')
        return false, 'registration_failed'
    end
    core().Log('dealership', 'purchase', src, { model = v.model, plate = plate, method = method, paidPence = paid })
    return true, { plate = plate, garage = def.garage, model = v.model, paid = core().FormatGBP(paid) }
end

local function sellList(src, p)
    local def, why = near(src, type(p) == 'table' and p.id)
    if not def then return false, why end
    local ok, all = exports.nexoro_vehicles:ListFor(src)
    if not ok then return false, all end
    local out = {}
    for _, v in ipairs(all) do
        if v.mine and v.status == 'stored' and not v.financeRemaining then
            out[#out + 1] = { plate = v.plate, model = v.model, miles = v.miles, price = core().FormatGBP(exports.nexoro_vehicles:BuybackPrice(v.plate) or 0) }
        end
    end
    return true, out
end

local function sell(src, p)
    p = type(p) == 'table' and p or {}
    local def, why = near(src, p.id)
    if not def then return false, why end
    return exports.nexoro_vehicles:SellToDealer(src, p.plate)
end

local function register()
    Core = nil
    local C = core()
    local opts = { requireCharacter = true, rateLimit = { max = 10, windowMs = 10000 } }
    C.RegisterCallback('nexoro_dealerships:catalogue', catalogue, opts)
    C.RegisterCallback('nexoro_dealerships:terms', terms, opts)
    C.RegisterCallback('nexoro_dealerships:purchase', purchase, { requireCharacter = true, rateLimit = { max = 4, windowMs = 10000 } })
    C.RegisterCallback('nexoro_dealerships:sellList', sellList, opts)
    C.RegisterCallback('nexoro_dealerships:sell', sell, { requireCharacter = true, rateLimit = { max = 4, windowMs = 10000 } })
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)
