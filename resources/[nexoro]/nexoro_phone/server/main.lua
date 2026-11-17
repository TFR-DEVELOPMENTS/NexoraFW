local cfg = Config.Phone
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroPhone = {}
local numbers, bySrc = {}, {}            -- [src] = number ; [number] = src
local calls = { byId = {}, byPlayer = {} }
local nextCall = 0
local adCooldown = {}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function started(res) return GetResourceState(res) == 'started' end

local function text(s, min, max)
    if type(s) ~= 'string' then return nil end
    s = trim(s:gsub('[\0-\8\11\12\14-\31\127]', ''))
    local len = utf8.len(s)
    if not len or len < min or len > max then return nil end
    return s
end

-- 07xxx xxxxxx. Digits only, 11 characters.
local function mobile(s)
    if type(s) ~= 'string' and type(s) ~= 'number' then return nil end
    s = tostring(s):gsub('[%s%-]', '')
    return s:match('^07%d%d%d%d%d%d%d%d%d$') and s or nil
end

local function ascii(s) return (s:lower():gsub('[^a-z]', '')) end

---------------------------------------------------------------------------
-- Phone identity (created on first use, persists with the character)
---------------------------------------------------------------------------

local MOBILE_PREFIX = { '1', '2', '3', '4', '5', '7', '8', '9' }
local function randomNumber()
    local digits = {}
    for i = 1, 8 do digits[i] = tostring(math.random(0, 9)) end
    return '07' .. MOBILE_PREFIX[math.random(1, #MOBILE_PREFIX)] .. table.concat(digits)
end
NexoroPhone.RandomNumber = randomNumber

local function uniqueValue(column, base, suffixFormat)
    local candidate = base
    for i = 1, 50 do
        if not NexoroDB.scalar('SELECT 1 FROM nexoro_phones WHERE ' .. column .. ' = ?', { candidate }) then return candidate end
        candidate = suffixFormat(base, i + 1)
    end
    return nil
end

local function ensurePhone(src)
    local c = core().GetCharacter(src)
    if not c then return nil end
    local row = NexoroDB.single('SELECT phone_number, email, handle, wallpaper, ringtone FROM nexoro_phones WHERE character_id = ?', { c.id })
    if not row then
        local first, last = ascii(c.firstName), ascii(c.lastName)
        if first == '' then first = 'user' end
        if last == '' then last = 'nexoro' end
        local email = uniqueValue('email', ('%s.%s@%s'):format(first, last, cfg.EmailDomain), function(_, n) return ('%s.%s%d@%s'):format(first, last, n, cfg.EmailDomain) end)
        local handle = uniqueValue('handle', ('@%s_%s'):format(first, last), function(b, n) return b .. n end)
        if not email or not handle then return nil end
        for _ = 1, 20 do
            local number = randomNumber()
            local affected = NexoroDB.update('INSERT IGNORE INTO nexoro_phones (character_id, phone_number, email, handle) VALUES (?,?,?,?)', { c.id, number, email, handle })
            if affected == 1 then break end
        end
        row = NexoroDB.single('SELECT phone_number, email, handle, wallpaper, ringtone FROM nexoro_phones WHERE character_id = ?', { c.id })
        if not row then return nil end
    end
    numbers[src], bySrc[row.phone_number] = row.phone_number, src
    if core().GetMetadata(src, 'phone_battery') == nil then core().SetMetadata(src, 'phone_battery', 100) end
    return { characterId = c.id, number = row.phone_number, email = row.email, handle = row.handle, wallpaper = row.wallpaper, ringtone = row.ringtone }
end
NexoroPhone.Ensure = ensurePhone

local function battery(src) return tonumber(core().GetMetadata(src, 'phone_battery')) or 100 end

-- Returns phone info, or false + reason. Applies the item and battery rules.
local function usable(src)
    if not core().GetCharacter(src) then return false, 'no_character' end
    if cfg.RequireItem and started('nexoro_inventory') then
        local ok, has = pcall(function() return exports.nexoro_inventory:HasItem(src, cfg.RequireItem, 1) end)
        if ok and not has then return false, 'no_phone' end
    end
    if battery(src) <= 0 then return false, 'battery_dead' end
    local phone = ensurePhone(src)
    if not phone then return false, 'phone_error' end
    return phone
end

function NexoroPhone.Charge(src, amount)
    local c = core().GetCharacter(src)
    if not c then return false end
    local level = math.min(100, battery(src) + (tonumber(amount) or cfg.ChargeAmount))
    core().SetMetadata(src, 'phone_battery', level)
    TriggerClientEvent('nexoro_phone:battery', src, level)
    return true, level
end

---------------------------------------------------------------------------
-- Contacts
---------------------------------------------------------------------------

local function contactsOf(characterId)
    return NexoroDB.query('SELECT id, name, number FROM nexoro_phone_contacts WHERE character_id = ? ORDER BY name', { characterId }) or {}
end

local function saveContact(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    p = type(p) == 'table' and p or {}
    local name, number = text(p.name, 1, 30), mobile(p.number)
    if not name then return false, 'invalid_name' end
    if not number then return false, 'invalid_number' end
    if number == phone.number then return false, 'own_number' end
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_phone_contacts WHERE character_id = ?', { phone.characterId }) or 0
    local exists = NexoroDB.scalar('SELECT 1 FROM nexoro_phone_contacts WHERE character_id = ? AND number = ?', { phone.characterId, number })
    if not exists and count >= cfg.MaxContacts then return false, 'contact_limit' end
    NexoroDB.update('INSERT INTO nexoro_phone_contacts (character_id, name, number) VALUES (?,?,?) ON DUPLICATE KEY UPDATE name = VALUES(name)', { phone.characterId, name, number })
    return true, contactsOf(phone.characterId)
end

local function deleteContact(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    local id = type(p) == 'table' and math.tointeger(tonumber(p.id))
    if not id then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_phone_contacts WHERE id = ? AND character_id = ?', { id, phone.characterId })
    return true, contactsOf(phone.characterId)
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------

local function sendMessage(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    p = type(p) == 'table' and p or {}
    local to, body = mobile(p.to), text(p.body, 1, cfg.MaxMessageLength)
    if not to then return false, 'invalid_number' end
    if not body then return false, 'invalid_message' end
    if to == phone.number then return false, 'own_number' end
    if not NexoroDB.scalar('SELECT 1 FROM nexoro_phones WHERE phone_number = ?', { to }) then return false, 'number_not_found' end
    NexoroDB.insert('INSERT INTO nexoro_phone_messages (sender, recipient, body) VALUES (?,?,?)', { phone.number, to, body })
    local dest = bySrc[to]
    if dest then
        TriggerClientEvent('nexoro_phone:message', dest, { from = phone.number, body = body, time = os.date('%H:%M') })
        core().Notify(dest, 'New message from ' .. phone.number, 'info', 4000)
    end
    return true
end

local function conversations(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local rows = NexoroDB.query([[
        SELECT other, MAX(id) AS last_id, SUM(unread) AS unread FROM (
            SELECT recipient AS other, id, 0 AS unread FROM nexoro_phone_messages WHERE sender = ?
            UNION ALL
            SELECT sender AS other, id, IF(read_at IS NULL, 1, 0) AS unread FROM nexoro_phone_messages WHERE recipient = ?
        ) t GROUP BY other ORDER BY last_id DESC LIMIT 50]], { phone.number, phone.number }) or {}
    if #rows == 0 then return true, {} end
    local ids, marks = {}, {}
    for i, r in ipairs(rows) do ids[i] = r.last_id; marks[i] = '?' end
    local bodies = {}
    for _, m in ipairs(NexoroDB.query('SELECT id, body FROM nexoro_phone_messages WHERE id IN (' .. table.concat(marks, ',') .. ')', ids) or {}) do bodies[m.id] = m.body end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { number = r.other, last = bodies[r.last_id] or '', unread = tonumber(r.unread) or 0 } end
    return true, out
end

local function thread(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    local other = mobile(type(p) == 'table' and p.number)
    if not other then return false, 'invalid_number' end
    local rows = NexoroDB.query(
        "SELECT id, sender, body, DATE_FORMAT(created_at, '%H:%i') AS time, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM nexoro_phone_messages " ..
        'WHERE (sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?) ORDER BY id DESC LIMIT 50',
        { phone.number, other, other, phone.number }) or {}
    NexoroDB.update('UPDATE nexoro_phone_messages SET read_at = NOW() WHERE recipient = ? AND sender = ? AND read_at IS NULL', { phone.number, other })
    local out = {}
    for i = #rows, 1, -1 do out[#out + 1] = { body = rows[i].body, time = rows[i].time, date = rows[i].date, mine = rows[i].sender == phone.number } end
    return true, out
end

---------------------------------------------------------------------------
-- Calls (signalling and state; voice is handed to pma-voice when installed)
---------------------------------------------------------------------------

local function voice(src, channel)
    if cfg.Voice == 'pma-voice' and started('pma-voice') then
        pcall(function() exports['pma-voice']:setPlayerCall(src, channel) end)
    end
end

local function logCall(caller, callee, status, seconds)
    NexoroDB.insert('INSERT INTO nexoro_phone_calls (caller, callee, status, duration_seconds) VALUES (?,?,?,?)', { caller, callee, status, seconds or 0 })
end

local function endCall(id, status)
    local call = calls.byId[id]
    if not call then return false end
    calls.byId[id] = nil
    calls.byPlayer[call.caller], calls.byPlayer[call.callee] = nil, nil
    local seconds = call.answeredAt and (os.time() - call.answeredAt) or 0
    logCall(call.callerNumber, call.calleeNumber, call.answeredAt and 'answered' or status, seconds)
    voice(call.caller, 0); voice(call.callee, 0)
    for _, who in ipairs({ call.caller, call.callee }) do TriggerClientEvent('nexoro_phone:ended', who, { id = id, status = status, seconds = seconds }) end
    return true
end
NexoroPhone.EndCall = endCall

local function startCall(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    if calls.byPlayer[src] then return false, 'already_in_call' end
    local raw = type(p) == 'table' and tostring(p.to or ''):gsub('[%s%-]', '') or ''
    local kind = cfg.EmergencyNumbers[raw]
    if kind then
        logCall(phone.number, raw, 'answered', 0)
        TriggerEvent('nexoro:server:emergencyCall', src, raw, kind)   -- nexoro_dispatch (Phase 6) listens for this
        return true, { emergency = kind }
    end
    local to = mobile(raw)
    if not to then return false, 'invalid_number' end
    if to == phone.number then return false, 'own_number' end
    local dest = bySrc[to]
    if not dest or not core().GetCharacter(dest) or not usable(dest) then
        logCall(phone.number, to, 'missed', 0)
        return false, 'unavailable'
    end
    if calls.byPlayer[dest] then return false, 'busy' end
    nextCall = nextCall + 1
    local id = nextCall
    calls.byId[id] = { id = id, caller = src, callee = dest, callerNumber = phone.number, calleeNumber = to, started = os.time() }
    calls.byPlayer[src], calls.byPlayer[dest] = id, id
    TriggerClientEvent('nexoro_phone:incoming', dest, { id = id, from = phone.number })
    SetTimeout(cfg.RingSeconds * 1000, function()
        local c = calls.byId[id]
        if c and not c.answeredAt then endCall(id, 'missed') end
    end)
    return true, { id = id }
end

local function answerCall(src, p)
    local id = type(p) == 'table' and math.tointeger(tonumber(p.id))
    local call = id and calls.byId[id]
    if not call or call.callee ~= src or call.answeredAt then return false, 'no_such_call' end
    call.answeredAt = os.time()
    voice(call.caller, id); voice(call.callee, id)
    TriggerClientEvent('nexoro_phone:answered', call.caller, { id = id })
    return true, { id = id }
end

local function hangUp(src)
    local id = calls.byPlayer[src]
    if not id then return false, 'not_in_call' end
    local call = calls.byId[id]
    local status = call.answeredAt and 'answered' or (call.callee == src and 'declined' or 'cancelled')
    return endCall(id, status)
end

local function callLog(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local rows = NexoroDB.query(
        "SELECT caller, callee, status, duration_seconds, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date FROM nexoro_phone_calls WHERE caller = ? OR callee = ? ORDER BY id DESC LIMIT 30",
        { phone.number, phone.number }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local outgoing = r.caller == phone.number
        out[#out + 1] = { number = outgoing and r.callee or r.caller, direction = outgoing and 'outgoing' or 'incoming', status = r.status, seconds = r.duration_seconds, date = r.date }
    end
    return true, out
end

---------------------------------------------------------------------------
-- Email, adverts, social
---------------------------------------------------------------------------

local function sendMail(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    p = type(p) == 'table' and p or {}
    local to = type(p.to) == 'string' and p.to:lower():gsub('%s', '') or ''
    local subject, body = text(p.subject, 1, 60), text(p.body, 1, 1000)
    if not to:match('^[%w%.]+@[%w%.]+$') or #to > 80 then return false, 'invalid_address' end
    if not subject then return false, 'invalid_subject' end
    if not body then return false, 'invalid_message' end
    local row = NexoroDB.single('SELECT character_id FROM nexoro_phones WHERE email = ?', { to })
    if not row then return false, 'address_not_found' end
    NexoroDB.insert('INSERT INTO nexoro_phone_emails (to_address, from_address, subject, body) VALUES (?,?,?,?)', { to, phone.email, subject, body })
    local dest = core().GetSourceByCharacterId(row.character_id)
    if dest then
        TriggerClientEvent('nexoro_phone:mail', dest, { from = phone.email, subject = subject })
        core().Notify(dest, 'New email: ' .. subject, 'info', 4000)
    end
    return true
end

local function inbox(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    return true, NexoroDB.query(
        "SELECT id, from_address, subject, body, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date, IF(read_at IS NULL, 0, 1) AS is_read FROM nexoro_phone_emails WHERE to_address = ? AND deleted = 0 ORDER BY id DESC LIMIT 40",
        { phone.email }) or {}
end

local function mailAction(src, p, sql)
    local phone, why = usable(src)
    if not phone then return false, why end
    local id = type(p) == 'table' and math.tointeger(tonumber(p.id))
    if not id then return false, 'invalid_request' end
    NexoroDB.update(sql, { id, phone.email })
    return true
end

local function postAdvert(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    p = type(p) == 'table' and p or {}
    local title, body = text(p.title, 1, 40), text(p.body, 1, 250)
    if not title then return false, 'invalid_title' end
    if not body then return false, 'invalid_message' end
    local pricePence
    if p.price ~= nil and p.price ~= '' then
        pricePence = core().ToPence(tonumber(p.price))
        if not pricePence or pricePence > 1000000000 then return false, 'invalid_price' end
    end
    local now = GetGameTimer()
    if adCooldown[src] and now - adCooldown[src] < cfg.AdCooldownSeconds * 1000 then return false, 'advert_cooldown' end
    local paid, payWhy = core().RemoveMoney(src, cfg.AdCostPounds, 'bank', 'phone advert')
    if not paid then return false, payWhy == 'insufficient_funds' and 'cannot_afford_advert' or payWhy end
    adCooldown[src] = now
    NexoroDB.insert('INSERT INTO nexoro_phone_adverts (character_id, number, title, body, price_pence, expires_at) VALUES (?,?,?,?,?,DATE_ADD(NOW(), INTERVAL ? HOUR))',
        { phone.characterId, phone.number, title, body, pricePence or 0, cfg.AdLifetimeHours })
    return true
end

local function adverts(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local rows = NexoroDB.query(
        "SELECT a.id, a.number, a.title, a.body, a.price_pence, DATE_FORMAT(a.created_at, '%d/%m %H:%i') AS date, (a.character_id = ?) AS mine FROM nexoro_phone_adverts a WHERE a.expires_at > NOW() ORDER BY a.id DESC LIMIT 50",
        { phone.characterId }) or {}
    for _, r in ipairs(rows) do
        r.price = (r.price_pence and r.price_pence > 0) and core().FormatGBP(r.price_pence) or nil
        r.price_pence, r.mine = nil, (r.mine == 1)
    end
    return true, rows
end

local function deleteAdvert(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    local id = type(p) == 'table' and math.tointeger(tonumber(p.id))
    if not id then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_phone_adverts WHERE id = ? AND character_id = ?', { id, phone.characterId })
    return true
end

local function feed(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local rows = NexoroDB.query(
        "SELECT p.id, p.handle, p.body, DATE_FORMAT(p.created_at, '%d/%m %H:%i') AS date, (p.character_id = ?) AS mine FROM nexoro_phone_posts p ORDER BY p.id DESC LIMIT 50",
        { phone.characterId }) or {}
    for _, r in ipairs(rows) do r.mine = (r.mine == 1) end
    return true, rows
end

local function post(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    local body = text(type(p) == 'table' and p.body, 1, 200)
    if not body then return false, 'invalid_message' end
    NexoroDB.insert('INSERT INTO nexoro_phone_posts (character_id, handle, body) VALUES (?,?,?)', { phone.characterId, phone.handle, body })
    return true
end

local function deletePost(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    local id = type(p) == 'table' and math.tointeger(tonumber(p.id))
    if not id then return false, 'invalid_request' end
    NexoroDB.update('DELETE FROM nexoro_phone_posts WHERE id = ? AND character_id = ?', { id, phone.characterId })
    return true
end

---------------------------------------------------------------------------
-- Settings, jobs, open
---------------------------------------------------------------------------

local function contains(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local function saveSettings(src, p)
    local phone, why = usable(src)
    if not phone then return false, why end
    p = type(p) == 'table' and p or {}
    local wallpaper = contains(cfg.Wallpapers, p.wallpaper) and p.wallpaper or phone.wallpaper
    local ringtone = contains(cfg.Ringtones, p.ringtone) and p.ringtone or phone.ringtone
    NexoroDB.update('UPDATE nexoro_phones SET wallpaper = ?, ringtone = ? WHERE character_id = ?', { wallpaper, ringtone, phone.characterId })
    return true, { wallpaper = wallpaper, ringtone = ringtone }
end

local function jobs(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local list = {}
    for _, j in ipairs(core().GetJobs()) do
        if not j.whitelisted and j.name ~= 'unemployed' then
            list[#list + 1] = { label = j.label, category = j.category, salary = j.grades[1] and core().FormatGBP(math.floor(j.grades[1].salary * 100 + 0.5)) or '' }
        end
    end
    return true, { current = core().GetJob(src), open = list }
end

local function open(src)
    local phone, why = usable(src)
    if not phone then return false, why end
    local unread = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_phone_messages WHERE recipient = ? AND read_at IS NULL', { phone.number }) or 0
    local mail = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_phone_emails WHERE to_address = ? AND deleted = 0 AND read_at IS NULL', { phone.email }) or 0
    return true, {
        number = phone.number, email = phone.email, handle = phone.handle, wallpaper = phone.wallpaper, ringtone = phone.ringtone,
        battery = battery(src), contacts = contactsOf(phone.characterId), unreadMessages = unread, unreadMail = mail,
        emergency = cfg.EmergencyNumbers,
    }
end

---------------------------------------------------------------------------
-- Registration and lifecycle
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback('nexoro_phone:' .. name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = windowMs or 10000 } })
    end
    cb('open', open)
    cb('contacts:save', saveContact); cb('contacts:delete', deleteContact)
    cb('messages:conversations', conversations); cb('messages:thread', thread); cb('messages:send', sendMessage, 8, 10000)
    cb('call', startCall, 6, 10000); cb('answer', answerCall); cb('hangup', function(src) return hangUp(src) end); cb('callLog', callLog)
    cb('mail:send', sendMail, 5, 10000); cb('mail:inbox', inbox)
    cb('mail:read', function(src, p) return mailAction(src, p, 'UPDATE nexoro_phone_emails SET read_at = NOW() WHERE id = ? AND to_address = ? AND read_at IS NULL') end)
    cb('mail:delete', function(src, p) return mailAction(src, p, 'UPDATE nexoro_phone_emails SET deleted = 1 WHERE id = ? AND to_address = ?') end)
    cb('ads:list', adverts); cb('ads:post', postAdvert, 3, 10000); cb('ads:delete', deleteAdvert)
    cb('social:feed', feed); cb('social:post', post, 3, 10000); cb('social:delete', deletePost)
    cb('settings:save', saveSettings); cb('jobs', jobs)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:characterLoaded', function(src) CreateThread(function() ensurePhone(src) end) end)
local function cleanup(src)
    if calls.byPlayer[src] then endCall(calls.byPlayer[src], 'cancelled') end
    if numbers[src] then bySrc[numbers[src]] = nil end
    numbers[src], adCooldown[src] = nil, nil
end
AddEventHandler('nexoro:server:characterUnloaded', function(src) cleanup(src) end)
AddEventHandler('nexoro:server:playerDropped', function(src) cleanup(src) end)

CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    -- charger item (needs nexoro_inventory)
    while not started('nexoro_inventory') do Wait(2000) end
    pcall(function()
        exports.nexoro_inventory:RegisterItem({ name = cfg.ChargeItem, label = 'Phone Charger', weight = 150, description = 'Charges your mobile phone.' })
        exports.nexoro_inventory:RegisterUsableItem(cfg.ChargeItem, function(src)
            NexoroPhone.Charge(src, cfg.ChargeAmount)
            core().Notify(src, 'Phone charged.', 'info')
        end)
    end)
    while true do
        Wait(cfg.BatteryDrainMinutes * 60 * 1000)
        for src in pairs(numbers) do
            local level = battery(src)
            if level > 0 then core().SetMetadata(src, 'phone_battery', level - 1) end
            Wait(50)
        end
    end
end)

exports('GetNumber', function(src) return numbers[src] end)
exports('GetSourceByNumber', function(number) return bySrc[number] end)
exports('ChargePhone', NexoroPhone.Charge)
exports('SendMessage', function(src, to, body) return sendMessage(src, { to = to, body = body }) end)
