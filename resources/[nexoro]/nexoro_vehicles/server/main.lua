local cfg = Config.Vehicles
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroVehicles = {}
local V = NexoroVehicles
local spawned = {}      -- [plate] = { src, netId, at, confirmed }
local lastReport = {}   -- [plate] = { t, mileage }
local offers, nextOffer = {}, 0

-- Overridable (tests): clock, player position, entity checks.
V.now = os.time
V.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
V.entityExists = function(netId)
    if not netId then return false end
    local e = NetworkGetEntityFromNetworkId(netId)
    return e and e ~= 0 and DoesEntityExist(e)
end
V.entityEngineHealth = function(netId)
    local e = NetworkGetEntityFromNetworkId(netId)
    if not e or e == 0 then return nil end
    return GetVehicleEngineHealth(e)
end
V.deleteEntity = function(netId)
    local e = NetworkGetEntityFromNetworkId(netId)
    if e and e ~= 0 and DoesEntityExist(e) then DeleteEntity(e) end
end

local function started(res) return GetResourceState(res) == 'started' end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function toInt(v) local n = tonumber(v); if not n or n ~= n or n == math.huge or n == -math.huge then return nil end return math.tointeger(n) end
local function finite(v) v = tonumber(v); if not v or v ~= v or v == math.huge or v == -math.huge then return nil end return v end
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------

local LETTERS = 'ABCDEFGHJKLMNOPRSTUVWXY'      -- no I, Q, Z

local function randomLetters(n)
    local out = {}
    for i = 1, n do local k = math.random(1, #LETTERS); out[i] = LETTERS:sub(k, k) end
    return table.concat(out)
end

function V.GeneratePlate()
    return randomLetters(2) .. cfg.AgeIdentifiers[math.random(1, #cfg.AgeIdentifiers)] .. ' ' .. randomLetters(3)
end

function V.NormalisePlate(p)
    if type(p) ~= 'string' then return nil end
    p = p:upper():gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    if #p == 7 then p = p:sub(1, 4) .. ' ' .. p:sub(5) end
    return p:match('^[A-Z][A-Z]%d%d [A-Z][A-Z][A-Z]$') and p or nil
end

---------------------------------------------------------------------------
-- Data access
---------------------------------------------------------------------------

local COLS = 'id, plate, owner_id, model, status, garage, fuel, engine, body, mileage_m, props, UNIX_TIMESTAMP(insurance_expires) AS insurance_ts, ' ..
    'UNIX_TIMESTAMP(mot_expires) AS mot_ts, impound_reason, impound_fee_pence, purchase_price_pence, finance_remaining_pence, finance_payment_pence, ' ..
    'UNIX_TIMESTAMP(finance_next_due) AS finance_next_ts, finance_missed'

local function getVehicle(plate)
    plate = V.NormalisePlate(plate)
    if not plate then return nil end
    return NexoroDB.single('SELECT ' .. COLS .. ' FROM nexoro_vehicles WHERE plate = ?', { plate })
end
V.Get = getVehicle

local function history(vehicleId, event, detail, actor)
    NexoroDB.insert('INSERT INTO nexoro_vehicle_history (vehicle_id, event, detail, actor) VALUES (?,?,?,?)',
        { vehicleId, event, tostring(detail or ''):sub(1, 200), tostring(actor or ''):sub(1, 60) })
end

local function characterOf(src) return core().GetCharacter(src) end
local function actorName(src) local c = characterOf(src); return c and (c.firstName .. ' ' .. c.lastName) or 'system' end

local function isOwner(src, row)
    local c = characterOf(src)
    return c ~= nil and row ~= nil and row.owner_id == c.id
end

local function hasKey(src, row)
    if isOwner(src, row) then return true end
    local c = characterOf(src)
    if not c or not row then return false end
    return NexoroDB.scalar('SELECT 1 FROM nexoro_vehicle_keys WHERE vehicle_id = ? AND character_id = ?', { row.id, c.id }) ~= nil
end

local function date(ts) return ts and os.date('%d/%m/%Y', ts) or nil end

local function view(row)
    local now = V.now()
    return {
        plate = row.plate, model = row.model, status = row.status, garage = row.garage,
        fuel = math.floor(row.fuel + 0.5), engine = math.floor(row.engine / 10 + 0.5), body = math.floor(row.body / 10 + 0.5),
        miles = math.floor(row.mileage_m / 1609.344 * 10 + 0.5) / 10,
        insured = row.insurance_ts ~= nil and row.insurance_ts > now, insuranceExpires = date(row.insurance_ts),
        motValid = row.mot_ts ~= nil and row.mot_ts > now, motExpires = date(row.mot_ts),
        financeRemaining = row.finance_remaining_pence > 0 and core().FormatGBP(row.finance_remaining_pence) or nil,
        financePayment = row.finance_payment_pence > 0 and core().FormatGBP(row.finance_payment_pence) or nil,
        financeDue = date(row.finance_next_ts),
        impoundFee = row.status == 'impounded' and core().FormatGBP(row.impound_fee_pence) or nil, impoundReason = row.status == 'impounded' and row.impound_reason or nil,
        value = core().FormatGBP(row.purchase_price_pence),
    }
end

local function account(a) if a == 'cash' then return 'cash' end return 'bank' end

local function charge(src, pence, acct, reason)
    if pence <= 0 then return true end
    return core().RemoveMoney(src, pence / 100, account(acct), reason)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

-- opts = { price (pounds), garage, fuel, finance = { remaining, payment, nextDue } }. Returns plate.
function V.Register(characterId, model, opts)
    opts = opts or {}
    if type(model) ~= 'string' or not model:match('^[%w_]+$') or #model < 3 or #model > 32 then return nil, 'invalid_model' end
    characterId = toInt(characterId)
    if not characterId then return nil, 'invalid_character' end
    local price = core().ToPence(tonumber(opts.price or 0)) or 0
    local fin = opts.finance
    for _ = 1, 20 do
        local plate = V.GeneratePlate()
        local id = NexoroDB.insert(
            'INSERT IGNORE INTO nexoro_vehicles (plate, owner_id, model, status, garage, fuel, props, purchase_price_pence, finance_remaining_pence, finance_payment_pence, finance_next_due) VALUES (?,?,?,?,?,?,?,?,?,?,' ..
            (fin and 'FROM_UNIXTIME(?)' or 'NULL') .. ')',
            fin and { plate, characterId, model:lower(), 'stored', opts.garage or cfg.DefaultGarage, opts.fuel or 100, '{}', price, fin.remaining, fin.payment, fin.nextDue }
                or { plate, characterId, model:lower(), 'stored', opts.garage or cfg.DefaultGarage, opts.fuel or 100, '{}', price, 0, 0 })
        if id and id > 0 then
            history(id, 'registered', ('%s registered, %s'):format(model, core().FormatGBP(price)), opts.actor or 'dealer')
            return plate, id
        end
    end
    return nil, 'plate_generation_failed'
end

---------------------------------------------------------------------------
-- Listing and access
---------------------------------------------------------------------------

local function list(src)
    local c = characterOf(src)
    if not c then return false, 'no_character' end
    local rows = NexoroDB.query('SELECT ' .. COLS .. " FROM nexoro_vehicles WHERE (owner_id = ? OR id IN (SELECT vehicle_id FROM nexoro_vehicle_keys WHERE character_id = ?)) AND status NOT IN ('scrapped','sold') ORDER BY plate",
        { c.id, c.id }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local v = view(r)
        v.mine = r.owner_id == c.id
        out[#out + 1] = v
    end
    return true, out
end

local function access(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    return hasKey(src, row) and row.status ~= 'scrapped' and row.status ~= 'repossessed', row.status
end

---------------------------------------------------------------------------
-- Spawning, storing and state reports
---------------------------------------------------------------------------

-- Called by nexoro_garages after it validated the location. Marks the vehicle out (atomic: only one retrieval can succeed).
function V.Spawn(src, plate, garage)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'stored' then return false, 'not_stored' end
    if row.garage ~= garage then return false, 'wrong_garage' end
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE id = ? AND status = 'stored'", { row.id })
    if affected ~= 1 then return false, 'not_stored' end
    spawned[row.plate] = { src = src, at = V.now(), confirmed = false }
    lastReport[row.plate] = { t = V.now(), mileage = row.mileage_m }
    history(row.id, 'retrieved', garage, actorName(src))
    return true, { plate = row.plate, model = row.model, fuel = row.fuel, engine = row.engine, body = row.body, mileage = row.mileage_m, props = row.props }
end

function V.ConfirmSpawn(src, plate, netId)
    plate = V.NormalisePlate(plate)
    local s = plate and spawned[plate]
    netId = toInt(netId)
    if not s or s.src ~= src or not netId then return false end
    s.netId, s.confirmed = netId, true
    return true
end

local function sanitiseState(row, state)
    state = type(state) == 'table' and state or {}
    local fuel = finite(state.fuel) and clamp(finite(state.fuel), 0, 100) or row.fuel
    local engine = finite(state.engine) and clamp(finite(state.engine), 0, 1000) or row.engine
    local body = finite(state.body) and clamp(finite(state.body), 0, 1000) or row.body
    local mileage = toInt(state.mileage) or row.mileage_m
    local last = lastReport[row.plate] or { t = V.now() - 30, mileage = row.mileage_m }
    local elapsed = math.max(1, V.now() - last.t)
    -- Values can only get worse via client reports: fuel burns, parts wear, mileage grows at a believable speed.
    fuel, engine, body = math.min(fuel, row.fuel), math.min(engine, row.engine), math.min(body, row.body)
    mileage = clamp(mileage, row.mileage_m, row.mileage_m + math.floor(elapsed * 80 + 200))
    local props = row.props
    if type(state.props) == 'table' then
        local ok, enc = pcall(json.encode, state.props)
        if ok and #enc <= 4096 then props = enc end
    end
    return { fuel = fuel, engine = engine, body = body, mileage = mileage, props = props }
end

local function reportState(src, plate, state)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not hasKey(src, row) then return false, 'no_access' end
    if row.status ~= 'out' then return false, 'not_out' end
    local s = sanitiseState(row, state)
    NexoroDB.update("UPDATE nexoro_vehicles SET fuel = ?, engine = ?, body = ?, mileage_m = ?, props = ? WHERE id = ? AND status = 'out'",
        { s.fuel, s.engine, s.body, s.mileage, s.props, row.id })
    lastReport[row.plate] = { t = V.now(), mileage = s.mileage }
    return true
end

function V.Store(src, plate, garage, state)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'out' then return false, 'not_out' end
    local s = sanitiseState(row, state)
    local affected = NexoroDB.update(
        "UPDATE nexoro_vehicles SET status = 'stored', garage = ?, fuel = ?, engine = ?, body = ?, mileage_m = ?, props = ? WHERE id = ? AND status = 'out'",
        { garage, s.fuel, s.engine, s.body, s.mileage, s.props, row.id })
    if affected ~= 1 then return false, 'not_out' end
    local sp = spawned[row.plate]
    if sp and sp.netId then V.deleteEntity(sp.netId) end
    spawned[row.plate], lastReport[row.plate] = nil, nil
    history(row.id, 'stored', garage, actorName(src))
    return true
end

---------------------------------------------------------------------------
-- Fuel
---------------------------------------------------------------------------

local function nearAny(src, points, radius)
    local pos = V.getCoords(src)
    if not pos then return false end
    for _, p in ipairs(points) do if dist(pos, p) <= radius then return true end end
    return false
end

local function refuel(src, plate, litres, acct)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not hasKey(src, row) then return false, 'no_access' end
    if row.status ~= 'out' then return false, 'not_out' end
    if not nearAny(src, cfg.Pumps, cfg.PumpRadius) then return false, 'not_at_pump' end
    litres = finite(litres)
    if not litres or litres <= 0 then return false, 'invalid_amount' end
    local room = (100 - row.fuel) / 100 * cfg.FuelTankLitres
    if room < 0.1 then return false, 'tank_full' end
    litres = math.floor(math.min(litres, room) * 10 + 0.5) / 10
    if litres <= 0 then return false, 'invalid_amount' end
    local pence = math.floor(litres * cfg.FuelPricePerLitre * 100 + 0.5)
    local ok, why = charge(src, pence, acct, 'fuel')
    if not ok then return false, why end
    local newFuel = math.min(100, row.fuel + litres / cfg.FuelTankLitres * 100)
    NexoroDB.update('UPDATE nexoro_vehicles SET fuel = ? WHERE id = ?', { newFuel, row.id })
    return true, { fuel = newFuel, litres = litres, cost = core().FormatGBP(pence) }
end

---------------------------------------------------------------------------
-- Insurance
---------------------------------------------------------------------------

local function buyInsurance(src, plate, days, acct)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    days = toInt(days)
    local rate = days and cfg.InsurancePlans[days]
    if not rate then return false, 'invalid_plan' end
    local pence = math.max(math.floor(row.purchase_price_pence * rate + 0.5), math.floor(cfg.InsuranceMinimumPounds * 100))
    local ok, why = charge(src, pence, acct, 'vehicle insurance')
    if not ok then return false, why end
    local start = math.max(V.now(), row.insurance_ts or 0)
    local expires = start + days * 86400
    NexoroDB.update('UPDATE nexoro_vehicles SET insurance_expires = FROM_UNIXTIME(?) WHERE id = ?', { expires, row.id })
    history(row.id, 'insurance', ('%d days, %s'):format(days, core().FormatGBP(pence)), actorName(src))
    return true, { expires = date(expires), cost = core().FormatGBP(pence) }
end

local function reportWrecked(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'out' then return false, 'not_out' end
    local sp = spawned[row.plate]
    -- The SERVER decides whether the vehicle is really destroyed.
    local gone = not (sp and sp.netId and V.entityExists(sp.netId))
    local engine = sp and sp.netId and V.entityEngineHealth(sp.netId)
    if not gone and not (engine and engine <= 0) then return false, 'vehicle_not_wrecked' end
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET status = 'wrecked', engine = 0 WHERE id = ? AND status = 'out'", { row.id })
    if affected ~= 1 then return false, 'not_out' end
    if sp and sp.netId then V.deleteEntity(sp.netId) end
    spawned[row.plate] = nil
    history(row.id, 'wrecked', '', actorName(src))
    return true
end

local function claimInsurance(src, plate, acct)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'wrecked' then return false, 'not_wrecked' end
    if not (row.insurance_ts and row.insurance_ts > V.now()) then return false, 'not_insured' end
    local excess = math.floor(row.purchase_price_pence * cfg.InsuranceExcessRate + 0.5)
    local ok, why = charge(src, excess, acct, 'insurance excess')
    if not ok then return false, why end
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET status = 'stored', garage = ?, engine = 500, body = 500, fuel = 20, insurance_expires = NULL WHERE id = ? AND status = 'wrecked'", { cfg.DefaultGarage, row.id })
    if affected ~= 1 then core().AddMoney(src, excess / 100, 'bank', 'refund'); return false, 'not_wrecked' end
    history(row.id, 'claim', 'excess ' .. core().FormatGBP(excess), actorName(src))
    return true, { garage = cfg.DefaultGarage, excess = core().FormatGBP(excess) }
end

local function scrap(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'wrecked' then return false, 'not_wrecked' end
    if row.finance_remaining_pence > 0 then return false, 'finance_outstanding' end
    NexoroDB.update("UPDATE nexoro_vehicles SET status = 'scrapped' WHERE id = ? AND status = 'wrecked'", { row.id })
    history(row.id, 'scrapped', '', actorName(src))
    return true
end

---------------------------------------------------------------------------
-- MOT
---------------------------------------------------------------------------

local function testMot(src, plate, acct)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'out' then return false, 'not_out' end
    if not nearAny(src, cfg.MotStations, cfg.MotRadius) then return false, 'not_at_station' end
    local ok, why = charge(src, math.floor(cfg.MotFeePounds * 100 + 0.5), acct, 'MOT test')
    if not ok then return false, why end
    local failures = {}
    if row.engine < cfg.MotMinEngine then failures[#failures + 1] = 'Engine condition' end
    if row.body < cfg.MotMinBody then failures[#failures + 1] = 'Bodywork' end
    if #failures > 0 then
        history(row.id, 'mot_fail', table.concat(failures, ', '), actorName(src))
        return true, { passed = false, failures = failures, fee = core().FormatGBP(math.floor(cfg.MotFeePounds * 100 + 0.5)) }
    end
    local expires = V.now() + cfg.MotValidDays * 86400
    NexoroDB.update('UPDATE nexoro_vehicles SET mot_expires = FROM_UNIXTIME(?) WHERE id = ?', { expires, row.id })
    history(row.id, 'mot_pass', 'expires ' .. date(expires), actorName(src))
    return true, { passed = true, expires = date(expires), fee = core().FormatGBP(math.floor(cfg.MotFeePounds * 100 + 0.5)) }
end

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------

local function giveKey(src, plate, target)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    target = toInt(target)
    local tc = target and core().GetCharacter(target)
    if not tc then return false, 'target_not_found' end
    if tc.id == row.owner_id then return false, 'already_owner' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_vehicle_keys WHERE vehicle_id = ?', { row.id }) or 0
    if count >= cfg.MaxSharedKeys then return false, 'key_limit' end
    NexoroDB.update('INSERT IGNORE INTO nexoro_vehicle_keys (vehicle_id, character_id) VALUES (?, ?)', { row.id, tc.id })
    history(row.id, 'key_given', tc.firstName .. ' ' .. tc.lastName, actorName(src))
    core().Notify(target, ('You were given a key for %s (%s).'):format(row.model, row.plate), 'info')
    return true
end

local function revokeKey(src, plate, characterId)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    characterId = toInt(characterId)
    if not characterId then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_vehicle_keys WHERE vehicle_id = ? AND character_id = ?', { row.id, characterId })
    history(row.id, 'key_revoked', tostring(characterId), actorName(src))
    return true
end

local function listKeys(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    return true, NexoroDB.query('SELECT k.character_id AS id, c.first_name, c.last_name FROM nexoro_vehicle_keys k JOIN nexoro_characters c ON c.id = k.character_id WHERE k.vehicle_id = ?', { row.id }) or {}
end

---------------------------------------------------------------------------
-- Transfers between players
---------------------------------------------------------------------------

local function offerTransfer(src, plate, target, price)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'stored' then return false, 'not_stored' end
    if row.finance_remaining_pence > 0 then return false, 'finance_outstanding' end
    target = toInt(target)
    local tc = target and core().GetCharacter(target)
    if not tc or target == src then return false, 'target_not_found' end
    local pence = core().ToPence(tonumber(price or 0))
    if not pence or pence > cfg.TransferMaxPricePounds * 100 then return false, 'invalid_price' end
    local a, b = V.getCoords(src), V.getCoords(target)
    if not a or not b or dist(a, b) > cfg.TransferMaxDistance then return false, 'too_far' end
    nextOffer = nextOffer + 1
    offers[nextOffer] = { id = nextOffer, plate = row.plate, vehicleId = row.id, seller = src, sellerCharacter = row.owner_id, buyer = target, pence = pence, expires = V.now() + cfg.TransferOfferSeconds }
    TriggerClientEvent('nexoro_vehicles:offer', target, { id = nextOffer, model = row.model, plate = row.plate, price = core().FormatGBP(pence), seller = actorName(src), miles = view(row).miles })
    return true, { id = nextOffer }
end

local function respondTransfer(src, offerId, accept)
    offerId = toInt(offerId)
    local offer = offerId and offers[offerId]
    if not offer or offer.buyer ~= src then return false, 'no_such_offer' end
    offers[offerId] = nil
    if V.now() > offer.expires then return false, 'offer_expired' end
    if accept ~= true then core().Notify(offer.seller, 'Your vehicle offer was declined.', 'info'); return true, { accepted = false } end
    local buyerChar, sellerChar = characterOf(src), characterOf(offer.seller)
    if not buyerChar then return false, 'no_character' end
    local ok, why = charge(src, offer.pence, 'bank', 'vehicle purchase ' .. offer.plate)
    if not ok then return false, why end
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET owner_id = ? WHERE id = ? AND owner_id = ? AND status = 'stored' AND finance_remaining_pence = 0",
        { buyerChar.id, offer.vehicleId, offer.sellerCharacter })
    if affected ~= 1 then
        core().AddMoney(src, offer.pence / 100, 'bank', 'refund')
        return false, 'transfer_failed'
    end
    NexoroDB.update('DELETE FROM nexoro_vehicle_keys WHERE vehicle_id = ?', { offer.vehicleId })
    if offer.pence > 0 and sellerChar then core().AddMoney(offer.seller, offer.pence / 100, 'bank', 'vehicle sale ' .. offer.plate)
    elseif offer.pence > 0 then
        NexoroDB.update('UPDATE nexoro_characters SET bank_pence = bank_pence + ? WHERE id = ?', { offer.pence, offer.sellerCharacter })
    end
    history(offer.vehicleId, 'transferred', ('to %s for %s'):format(actorName(src), core().FormatGBP(offer.pence)), sellerChar and actorName(offer.seller) or 'seller')
    core().Notify(offer.seller, ('%s sold for %s.'):format(offer.plate, core().FormatGBP(offer.pence)), 'banking')
    return true, { accepted = true, plate = offer.plate }
end

---------------------------------------------------------------------------
-- Dealer buyback and finance
---------------------------------------------------------------------------

function V.BuybackPrice(row)
    local miles = row.mileage_m / 1609.344
    local factor = math.max(0.4, 1 - miles / 100000)
    return math.floor(row.purchase_price_pence * cfg.BuybackRate * factor + 0.5)
end

function V.SellToDealer(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'stored' then return false, 'not_stored' end
    if row.finance_remaining_pence > 0 then return false, 'finance_outstanding' end
    local pence = V.BuybackPrice(row)
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET status = 'sold' WHERE id = ? AND owner_id = ? AND status = 'stored'", { row.id, row.owner_id })
    if affected ~= 1 then return false, 'not_stored' end
    core().AddMoney(src, pence / 100, 'bank', 'vehicle buyback ' .. row.plate)
    history(row.id, 'sold_dealer', core().FormatGBP(pence), actorName(src))
    return true, { price = core().FormatGBP(pence) }
end

function V.FinanceTerms(pricePounds, depositPounds)
    local price = core().ToPence(pricePounds)
    local deposit = core().ToPence(depositPounds or 0)
    if not price or not deposit or price <= 0 then return nil, 'invalid_amount' end
    if deposit < math.floor(price * cfg.FinanceMinDepositRate) then return nil, 'deposit_too_small' end
    if deposit >= price then return nil, 'deposit_covers_price' end
    local remaining = math.floor((price - deposit) * (1 + cfg.FinanceInterestRate) + 0.5)
    local payment = math.ceil(remaining / cfg.FinancePayments)
    return { deposit = deposit, remaining = remaining, payment = payment, nextDue = V.now() + cfg.FinancePeriodDays * 86400 }
end

local function payFinance(src, plate, amount)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.finance_remaining_pence <= 0 then return false, 'no_finance' end
    local pence = core().ToPence(tonumber(amount))
    if not pence or pence <= 0 then return false, 'invalid_amount' end
    pence = math.min(pence, row.finance_remaining_pence)
    local ok, why = charge(src, pence, 'bank', 'finance ' .. row.plate)
    if not ok then return false, why end
    -- status is assigned FIRST: MariaDB evaluates SET left to right, so it must see the balance before this payment.
    NexoroDB.update("UPDATE nexoro_vehicles SET status = IF(status = 'repossessed' AND finance_remaining_pence - ? = 0, 'stored', status), finance_remaining_pence = finance_remaining_pence - ?, finance_missed = 0 WHERE id = ?", { pence, pence, row.id })
    history(row.id, 'finance_paid', core().FormatGBP(pence), actorName(src))
    return true, { remaining = core().FormatGBP(row.finance_remaining_pence - pence) }
end

-- Takes due payments from online owners. Offline owners are never penalised.
function V.ProcessFinance()
    local now = V.now()
    local rows = NexoroDB.query('SELECT ' .. COLS .. " FROM nexoro_vehicles WHERE finance_remaining_pence > 0 AND finance_next_due <= FROM_UNIXTIME(?) AND status NOT IN ('repossessed','scrapped','sold')", { now }) or {}
    local processed = 0
    for _, row in ipairs(rows) do
        local src = core().GetSourceByCharacterId(row.owner_id)
        if src then
            local pay = math.min(row.finance_payment_pence, row.finance_remaining_pence)
            local ok = charge(src, pay, 'bank', 'finance ' .. row.plate)
            local nextDue = now + cfg.FinancePeriodDays * 86400
            if ok then
                NexoroDB.update('UPDATE nexoro_vehicles SET finance_remaining_pence = finance_remaining_pence - ?, finance_missed = 0, finance_next_due = FROM_UNIXTIME(?) WHERE id = ?', { pay, nextDue, row.id })
                history(row.id, 'finance_paid', core().FormatGBP(pay), 'automatic')
                core().Notify(src, ('Finance payment of %s taken for %s.'):format(core().FormatGBP(pay), row.plate), 'banking')
            else
                local missed = row.finance_missed + 1
                if missed >= cfg.FinanceRepossessAfterMissed then
                    NexoroDB.update("UPDATE nexoro_vehicles SET status = 'repossessed', finance_missed = ? WHERE id = ?", { missed, row.id })
                    local sp = spawned[row.plate]
                    if sp and sp.netId then V.deleteEntity(sp.netId) end
                    spawned[row.plate] = nil
                    history(row.id, 'repossessed', 'missed payments', 'automatic')
                    core().Notify(src, ('%s has been repossessed. Pay the arrears to get it back.'):format(row.plate), 'warning', 10000)
                else
                    NexoroDB.update('UPDATE nexoro_vehicles SET finance_missed = ?, finance_next_due = FROM_UNIXTIME(?) WHERE id = ?', { missed, nextDue, row.id })
                    core().Notify(src, ('Missed finance payment on %s (%d of %d).'):format(row.plate, missed, cfg.FinanceRepossessAfterMissed), 'warning', 8000)
                end
            end
            processed = processed + 1
        end
    end
    return processed
end

---------------------------------------------------------------------------
-- Impound, abandoned vehicles, recovery
---------------------------------------------------------------------------

local function canImpound(src)
    if core().HasPermission(src, 'nexoro.admin.vehicles') then return true end
    local job = core().GetJob(src)
    return job ~= nil and job.category == 'police' and job.onDuty == true
end

function V.Impound(src, plate, reason, feePounds)
    if not canImpound(src) then return false, 'forbidden' end
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if row.status ~= 'out' and row.status ~= 'stored' then return false, 'cannot_impound' end
    reason = type(reason) == 'string' and reason:gsub('[%c]', ''):sub(1, 100) or ''
    local fee = core().ToPence(tonumber(feePounds or 0)) or 0
    if fee > 1000000 then fee = 1000000 end
    NexoroDB.update("UPDATE nexoro_vehicles SET status = 'impounded', garage = '', impound_reason = ?, impound_fee_pence = ? WHERE id = ?", { reason, fee, row.id })
    local sp = spawned[row.plate]
    if sp and sp.netId then V.deleteEntity(sp.netId) end
    spawned[row.plate] = nil
    history(row.id, 'impounded', reason, src ~= 0 and actorName(src) or 'system')
    return true
end

-- Owner pays the fee; the vehicle is then waiting in the lot garage.
local function releaseImpound(src, plate, lot, acct)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not isOwner(src, row) then return false, 'not_owner' end
    if row.status ~= 'impounded' then return false, 'not_impounded' end
    local lotDef = cfg.ImpoundLots[lot]
    if not lotDef then return false, 'unknown_lot' end
    local ok, why = charge(src, row.impound_fee_pence, acct, 'impound fee ' .. row.plate)
    if not ok then return false, why end
    local affected = NexoroDB.update("UPDATE nexoro_vehicles SET status = 'stored', garage = ?, impound_fee_pence = 0, impound_reason = '' WHERE id = ? AND status = 'impounded'", { lotDef.garage, row.id })
    if affected ~= 1 then core().AddMoney(src, row.impound_fee_pence / 100, 'bank', 'refund'); return false, 'not_impounded' end
    history(row.id, 'released', core().FormatGBP(row.impound_fee_pence), actorName(src))
    return true, { garage = lotDef.garage }
end
V.ReleaseImpound = releaseImpound

-- Run periodically: returns vehicles that never appeared to their garage, impounds ones that vanished.
function V.SweepOut()
    local now, reverted, impounded = V.now(), 0, 0
    for plate, sp in pairs(spawned) do
        local row = getVehicle(plate)
        if not row or row.status ~= 'out' then spawned[plate] = nil
        elseif not sp.confirmed then
            if now - sp.at > cfg.SpawnConfirmSeconds then
                NexoroDB.update("UPDATE nexoro_vehicles SET status = 'stored' WHERE id = ? AND status = 'out'", { row.id })
                spawned[plate] = nil; reverted = reverted + 1
            end
        elseif not V.entityExists(sp.netId) then
            sp.missingSince = sp.missingSince or now
            if now - sp.missingSince > cfg.AbandonAfterSeconds then
                NexoroDB.update("UPDATE nexoro_vehicles SET status = 'impounded', garage = '', impound_reason = 'Abandoned', impound_fee_pence = ? WHERE id = ? AND status = 'out'",
                    { math.floor(cfg.AbandonedFeePounds * 100 + 0.5), row.id })
                history(row.id, 'impounded', 'Abandoned', 'system')
                spawned[plate] = nil; impounded = impounded + 1
            end
        else
            sp.missingSince = nil
        end
    end
    return reverted, impounded
end

function V.RecoverOut()
    if cfg.OutVehiclesOnRestart == 'stored' then
        return NexoroDB.update("UPDATE nexoro_vehicles SET status = 'stored' WHERE status = 'out'") or 0
    end
    return 0
end

---------------------------------------------------------------------------
-- Lookups, history and admin helpers
---------------------------------------------------------------------------

function V.LookupPlate(plate)
    local row = getVehicle(plate)
    if not row then return nil end
    local owner = NexoroDB.single('SELECT first_name, last_name, citizen_id FROM nexoro_characters WHERE id = ?', { row.owner_id })
    local v = view(row)
    v.owner = owner and (owner.first_name .. ' ' .. owner.last_name) or 'Unknown'
    v.ownerCitizenId = owner and owner.citizen_id or nil
    return v
end

function V.Search(term)
    term = type(term) == 'string' and term:upper():gsub('[^%w ]', ''):sub(1, 12) or ''
    if term == '' then return {} end
    local like = '%' .. term .. '%'
    local rows = NexoroDB.query([[
        SELECT v.plate, v.model, v.status, v.garage, c.first_name, c.last_name, c.citizen_id
        FROM nexoro_vehicles v JOIN nexoro_characters c ON c.id = v.owner_id
        WHERE v.plate LIKE ? OR UPPER(c.citizen_id) LIKE ? OR UPPER(CONCAT(c.first_name, ' ', c.last_name)) LIKE ? OR UPPER(v.model) LIKE ?
        ORDER BY v.plate LIMIT 50]], { like, like, like, like }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { plate = r.plate, model = r.model, status = r.status, garage = r.garage, owner = r.first_name .. ' ' .. r.last_name, citizenId = r.citizen_id } end
    return out
end

function V.AdminTransfer(plate, citizenId, actor)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not exports.nexoro_identity:IsValidCitizenId(citizenId) then return false, 'invalid_citizen_id' end
    local target = NexoroDB.single('SELECT id FROM nexoro_characters WHERE citizen_id = ?', { citizenId })
    if not target then return false, 'recipient_not_found' end
    if row.status == 'out' then return false, 'vehicle_is_out' end
    NexoroDB.update('UPDATE nexoro_vehicles SET owner_id = ? WHERE id = ?', { target.id, row.id })
    NexoroDB.update('DELETE FROM nexoro_vehicle_keys WHERE vehicle_id = ?', { row.id })
    history(row.id, 'admin_transfer', citizenId, actor or 'admin')
    return true
end

function V.AdminRepair(plate, actor)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    NexoroDB.update('UPDATE nexoro_vehicles SET engine = 1000, body = 1000 WHERE id = ?', { row.id })
    history(row.id, 'repaired', '', actor or 'admin')
    return true
end

function V.AdminDelete(plate, actor)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    local sp = spawned[row.plate]
    if sp and sp.netId then V.deleteEntity(sp.netId) end
    spawned[row.plate] = nil
    NexoroDB.update("UPDATE nexoro_vehicles SET status = 'scrapped' WHERE id = ?", { row.id })
    history(row.id, 'admin_deleted', '', actor or 'admin')
    return true
end

function V.AdminRelease(plate, lot, actor)
    local row = getVehicle(plate)
    if not row or row.status ~= 'impounded' then return false, 'not_impounded' end
    local lotDef = cfg.ImpoundLots[lot or 'mrpd_lot']
    if not lotDef then return false, 'unknown_lot' end
    NexoroDB.update("UPDATE nexoro_vehicles SET status = 'stored', garage = ?, impound_fee_pence = 0, impound_reason = '' WHERE id = ?", { lotDef.garage, row.id })
    history(row.id, 'released', 'by staff', actor or 'admin')
    return true
end

local function vehicleHistory(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not hasKey(src, row) and not core().HasPermission(src, 'nexoro.admin.vehicles') then return false, 'no_access' end
    return true, NexoroDB.query("SELECT event, detail, actor, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date FROM nexoro_vehicle_history WHERE vehicle_id = ? ORDER BY id DESC LIMIT 25", { row.id }) or {}
end

---------------------------------------------------------------------------
-- Registration of callbacks and lifecycle
---------------------------------------------------------------------------

-- Car wash: needs the vehicle to be out and you to be at a wash. Cleaning is only cosmetic.
function V.Wash(src, plate)
    local row = getVehicle(plate)
    if not row then return false, 'not_found' end
    if not hasKey(src, row) then return false, 'no_access' end
    if row.status ~= 'out' then return false, 'not_out' end
    local pos = V.getCoords(src)
    if not pos then return false, 'no_position' end
    local near = false
    for _, w in ipairs(cfg.CarWashes) do
        if dist(pos, w) <= cfg.CarWashRadius + 2.0 then near = true end
    end
    if not near then return false, 'not_at_wash' end
    local pence = core().ToPence(cfg.WashPriceFine)
    local ok, why = charge(src, pence, 'bank', 'car wash')
    if not ok then return false, why end
    history(row.id, 'washed', core().FormatGBP(pence), actorName(src))
    return true, { cost = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback('nexoro_vehicles:' .. name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('list', list)
    cb('access', function(src, p) return access(src, arg(p, 'plate')) end, 30, 10000)
    cb('state', function(src, p) return reportState(src, arg(p, 'plate'), arg(p, 'state')) end, 6, 30000)
    cb('refuel', function(src, p) return refuel(src, arg(p, 'plate'), arg(p, 'litres'), arg(p, 'account')) end, 10, 10000)
    cb('insurance:buy', function(src, p) return buyInsurance(src, arg(p, 'plate'), arg(p, 'days'), arg(p, 'account')) end, 5, 10000)
    cb('insurance:claim', function(src, p) return claimInsurance(src, arg(p, 'plate'), arg(p, 'account')) end, 5, 10000)
    cb('wrecked', function(src, p) return reportWrecked(src, arg(p, 'plate')) end, 5, 10000)
    cb('scrap', function(src, p) return scrap(src, arg(p, 'plate')) end, 5, 10000)
    cb('wash', function(src, p) return V.Wash(src, arg(p, 'plate')) end, 10)
    cb('mot', function(src, p) return testMot(src, arg(p, 'plate'), arg(p, 'account')) end, 5, 10000)
    cb('keys:list', function(src, p) return listKeys(src, arg(p, 'plate')) end)
    cb('keys:give', function(src, p) return giveKey(src, arg(p, 'plate'), arg(p, 'target')) end, 5, 10000)
    cb('keys:revoke', function(src, p) return revokeKey(src, arg(p, 'plate'), arg(p, 'characterId')) end, 5, 10000)
    cb('transfer:offer', function(src, p) return offerTransfer(src, arg(p, 'plate'), arg(p, 'target'), arg(p, 'price')) end, 5, 30000)
    cb('transfer:respond', function(src, p) return respondTransfer(src, arg(p, 'id'), arg(p, 'accept') == true) end, 5, 10000)
    cb('finance:pay', function(src, p) return payFinance(src, arg(p, 'plate'), arg(p, 'amount')) end, 5, 10000)
    cb('history', function(src, p) return vehicleHistory(src, arg(p, 'plate')) end)
    C.RegisterCallback('nexoro_vehicles:impound', function(src, p)
        return V.Impound(src, arg(p, 'plate'), arg(p, 'reason'), arg(p, 'fee'))
    end, { requireCharacter = true, rateLimit = { max = 5, windowMs = 10000 } })
end

RegisterNetEvent('nexoro_vehicles:spawned', function(plate, netId)
    local src = source
    V.ConfirmSpawn(src, plate, netId)
end)

AddEventHandler('nexoro:core:ready', function() register(); V.RecoverOut() end)
AddEventHandler('nexoro:server:characterLoaded', function() CreateThread(function() V.ProcessFinance() end) end)
AddEventHandler('nexoro:server:playerDropped', function(src)
    for id, o in pairs(offers) do if o.buyer == src or o.seller == src then offers[id] = nil end end
end)

CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register(); V.RecoverOut() end
    local tick = 0
    while true do
        Wait(30000)
        tick = tick + 1
        V.SweepOut()
        if tick % 20 == 0 then V.ProcessFinance() end
    end
end)

exports('Register', V.Register)
exports('Spawn', V.Spawn)
exports('Store', V.Store)
exports('Get', function(plate) local r = getVehicle(plate); return r and view(r) or nil end)
exports('HasAccess', function(src, plate) return (access(src, plate)) end)
exports('LookupPlate', V.LookupPlate)
exports('Search', V.Search)
exports('Impound', V.Impound)
exports('ReleaseImpound', V.ReleaseImpound)
exports('SellToDealer', V.SellToDealer)
exports('FinanceTerms', V.FinanceTerms)
exports('BuybackPrice', function(plate) local r = getVehicle(plate); return r and V.BuybackPrice(r) or nil end)
exports('AdminTransfer', V.AdminTransfer)
exports('AdminRepair', V.AdminRepair)
exports('AdminDelete', V.AdminDelete)
exports('AdminRelease', V.AdminRelease)
exports('ListFor', list)
