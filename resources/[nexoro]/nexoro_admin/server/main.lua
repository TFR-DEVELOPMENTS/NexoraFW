local cfg = Config.Admin
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroAdmin = { actions = {} }
local A = NexoroAdmin.actions
local startedAt = os.time()
local returnPos, selfState, staffDuty = {}, {}, {}
local maintenance = false
local world = { weather = 'CLEAR', hour = 12, minute = 0, frozen = false }

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function toInt(v) local n = tonumber(v); if not n or n ~= n then return nil end; return math.tointeger(n) end
local function cleanText(s, min, max)
    if type(s) ~= 'string' then return nil end
    s = trim(s:gsub('[\0-\8\11\12\14-\31\127]', ''))
    local len = utf8.len(s)
    if not len or len < min or len > max then return nil end
    return s
end
local function contains(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end
local function started(res) return GetResourceState(res) == 'started' end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function teleport(src, pos)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    SetEntityCoords(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
    return true
end

local function clientEffect(target, kind, data) TriggerClientEvent('nexoro:admin:client', target, kind, data) end

local function describe(src)
    local p = core().GetPlayer(src)
    if not p then return { license = '', name = 'unknown' } end
    local c = core().GetCharacter(src)
    return { license = p.license, name = c and (c.firstName .. ' ' .. c.lastName) or p.name, rank = p.staffRank or '' }
end

local function audit(src, action, targetSrc, previous, new, reason)
    local staff = describe(src)
    local target = targetSrc and describe(targetSrc) or { license = '', name = '' }
    local function enc(v) if v == nil then return nil end local ok, j = pcall(json.encode, v); return ok and j or tostring(v) end
    NexoroDB.insert(
        'INSERT INTO nexoro_admin_logs (staff_license, staff_name, staff_rank, action, target_license, target_name, previous_value, new_value, reason) VALUES (?,?,?,?,?,?,?,?,?)',
        { staff.license, staff.name, staff.rank, action, target.license, target.name, enc(previous) or '', enc(new) or '', (reason or ''):sub(1, 200) })
    core().Log('admin', action, src, { target = targetSrc, reason = reason })
end

local function ids(src)
    local p = core().GetPlayer(src)
    return p and p.identifiers or {}
end

local function formatTime(ts) return os.date('%d/%m/%Y %H:%M', ts) end

---------------------------------------------------------------------------
-- Bans
---------------------------------------------------------------------------

local function activeBanFor(identifiers)
    local list = {}
    for _, v in pairs(identifiers) do list[#list + 1] = v end
    if #list == 0 then return nil end
    local placeholders = {}
    for i = 1, #list do placeholders[i] = '?' end
    return NexoroDB.single(
        'SELECT b.id, b.reason, UNIX_TIMESTAMP(b.expires_at) AS expires FROM nexoro_ban_identifiers i JOIN nexoro_bans b ON b.id = i.ban_id ' ..
        'WHERE i.identifier IN (' .. table.concat(placeholders, ',') .. ') AND b.revoked_at IS NULL AND (b.expires_at IS NULL OR b.expires_at > NOW()) ORDER BY b.id DESC LIMIT 1',
        list)
end

local function banMessage(ban)
    return ('You are banned from this server.\nReason: %s\nBan ID: %d\nExpires: %s'):format(
        ban.reason, ban.id, ban.expires and formatTime(ban.expires) or 'never')
end

local function connectHook(_, identifiers)
    local ban = activeBanFor(identifiers)
    if ban then return { allowed = false, reason = banMessage(ban) } end
    if maintenance then
        local row = NexoroDB.single(
            'SELECT 1 AS ok FROM nexoro_staff_assignments s JOIN nexoro_players p ON p.id = s.player_id WHERE p.license = ?', { identifiers.license })
        if not row then return { allowed = false, reason = 'The server is in maintenance mode. Please try again later.' } end
    end
    return { allowed = true }
end

local function createBan(src, target, reason, minutes)
    local p = core().GetPlayer(target)
    local expiresSql = minutes > 0 and 'DATE_ADD(NOW(), INTERVAL ? MINUTE)' or 'NULL'
    local params = { p.license, p.name, reason, describe(src).name, describe(src).license }
    if minutes > 0 then params[#params + 1] = minutes end
    local banId = NexoroDB.insert(
        'INSERT INTO nexoro_bans (license, player_name, reason, banned_by, banned_by_license, expires_at) VALUES (?,?,?,?,?,' .. expiresSql .. ')', params)
    if not banId or banId == 0 then return nil end
    local placeholders, values = {}, {}
    for _, identifier in pairs(p.identifiers) do
        placeholders[#placeholders + 1] = '(?,?)'
        values[#values + 1] = banId
        values[#values + 1] = identifier
    end
    NexoroDB.query('INSERT IGNORE INTO nexoro_ban_identifiers (ban_id, identifier) VALUES ' .. table.concat(placeholders, ','), values)
    return banId
end

---------------------------------------------------------------------------
-- Actions. run(src, payload, target) -> ok, result, { previous = ..., new = ... }
---------------------------------------------------------------------------

-- Teleport ---------------------------------------------------------------
A['goto'] = { perm = 'nexoro.admin.teleport', target = true, run = function(src, _, target)
    local pos = coordsOf(target); local mine = coordsOf(src)
    if not pos then return false, 'no_position' end
    returnPos[src] = mine
    teleport(src, pos)
    return true, nil, { previous = mine, new = pos }
end }
A['bring'] = { perm = 'nexoro.admin.teleport', target = true, run = function(src, _, target)
    local pos = coordsOf(src); local theirs = coordsOf(target)
    if not pos then return false, 'no_position' end
    returnPos[target] = theirs
    teleport(target, pos)
    return true, nil, { previous = theirs, new = pos }
end }
A['return'] = { perm = 'nexoro.admin.teleport', target = true, allowSelf = true, run = function(src, _, target)
    local pos = returnPos[target]
    if not pos then return false, 'no_return_position' end
    teleport(target, pos)
    returnPos[target] = nil
    return true, nil, { new = pos }
end }
A['tpcoords'] = { perm = 'nexoro.admin.teleport', run = function(src, p)
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z or math.abs(x) > 10000 or math.abs(y) > 10000 or z < -300 or z > 3000 then return false, 'invalid_coordinates' end
    local before = coordsOf(src)
    teleport(src, { x = x, y = y, z = z })
    return true, nil, { previous = before, new = { x = x, y = y, z = z } }
end }
A['tpwaypoint'] = { perm = 'nexoro.admin.teleport', run = function(src) clientEffect(src, 'tpwaypoint'); return true end }

-- Player state -----------------------------------------------------------
A['freeze'] = { perm = 'nexoro.mod.freeze', target = true, run = function(_, _, t) clientEffect(t, 'freeze', true); return true, nil, { new = 'frozen' } end }
A['unfreeze'] = { perm = 'nexoro.mod.freeze', target = true, run = function(_, _, t) clientEffect(t, 'freeze', false); return true, nil, { new = 'unfrozen' } end }
A['spectate'] = { perm = 'nexoro.mod.spectate', target = true, run = function(src, _, t)
    local pos = coordsOf(t)
    if not pos then return false, 'no_position' end
    returnPos[src] = coordsOf(src)
    teleport(src, { x = pos.x, y = pos.y, z = pos.z + 12.0 }) -- near enough for the target to stream in
    clientEffect(src, 'spectate', t)
    return true
end }
A['stopspectate'] = { perm = 'nexoro.mod.spectate', run = function(src)
    clientEffect(src, 'spectate', nil)
    if returnPos[src] then teleport(src, returnPos[src]); returnPos[src] = nil end
    return true
end }
A['heal'] = { perm = 'nexoro.admin.players', target = true, allowSelf = true, run = function(_, _, t) clientEffect(t, 'heal'); return true end }
A['revive'] = { perm = 'nexoro.admin.players', target = true, allowSelf = true, run = function(_, _, t) clientEffect(t, 'revive'); return true end }
A['armour'] = { perm = 'nexoro.admin.players', target = true, allowSelf = true, run = function(_, _, t) clientEffect(t, 'armour'); return true end }

-- Moderation -------------------------------------------------------------
A['kick'] = { perm = 'nexoro.mod.kick', target = true, reason = true, run = function(src, p, t)
    DropPlayer(t, 'Kicked by staff: ' .. p.reason)
    return true, nil, { new = 'kicked' }
end }
A['warn'] = { perm = 'nexoro.mod.warnings', target = true, reason = true, run = function(src, p, t)
    local target, staff = describe(t), describe(src)
    local c = core().GetCharacter(t)
    NexoroDB.insert('INSERT INTO nexoro_warnings (license, character_id, reason, issued_by, issued_by_license) VALUES (?,?,?,?,?)',
        { target.license, c and c.id or 0, p.reason, staff.name, staff.license })
    core().Notify(t, 'You have received a warning: ' .. p.reason, 'staff', 12000)
    local count = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_warnings WHERE license = ?', { target.license }) or 0
    return true, { warnings = count }, { new = { warning = p.reason, total = count } }
end }
A['message'] = { perm = 'nexoro.mod.warnings', target = true, run = function(_, p, t)
    local text = cleanText(p.text, 1, 250)
    if not text then return false, 'invalid_text' end
    core().Notify(t, text, 'staff', 10000)
    return true
end }
A['mute'] = { perm = 'nexoro.mod.warnings', target = true, run = function(_, p, t)
    if not started('nexoro_chat') then return false, 'chat_unavailable' end
    local minutes = math.max(1, math.min(toInt(p.minutes) or 10, 1440))
    exports.nexoro_chat:Mute(t, minutes * 60)
    return true, nil, { new = ('muted %d minutes'):format(minutes) }
end }
A['unmute'] = { perm = 'nexoro.mod.warnings', target = true, run = function(_, _, t)
    if not started('nexoro_chat') then return false, 'chat_unavailable' end
    exports.nexoro_chat:Unmute(t)
    return true
end }
A['tempban'] = { perm = 'nexoro.mod.temporaryban', target = true, reason = true, sensitive = true, run = function(src, p, t)
    local minutes = toInt(p.minutes)
    if not minutes or minutes < 1 or minutes > cfg.ModMaxBanMinutes then return false, 'invalid_duration' end
    local id = createBan(src, t, p.reason, minutes)
    if not id then return false, 'database_error' end
    DropPlayer(t, banMessage({ id = id, reason = p.reason, expires = os.time() + minutes * 60 }))
    return true, { banId = id }, { new = { banId = id, minutes = minutes } }
end }
A['ban'] = { perm = 'nexoro.admin.bans', target = true, reason = true, sensitive = true, run = function(src, p, t)
    local minutes = toInt(p.minutes) or 0
    if minutes < 0 or minutes > cfg.MaxBanMinutes then return false, 'invalid_duration' end
    local id = createBan(src, t, p.reason, minutes)
    if not id then return false, 'database_error' end
    DropPlayer(t, banMessage({ id = id, reason = p.reason, expires = minutes > 0 and os.time() + minutes * 60 or nil }))
    return true, { banId = id }, { new = { banId = id, minutes = minutes } }
end }
A['unban'] = { perm = 'nexoro.admin.bans', sensitive = true, reason = true, run = function(src, p)
    local banId = toInt(p.banId)
    if not banId then return false, 'invalid_ban' end
    local ban = NexoroDB.single('SELECT id, license, reason FROM nexoro_bans WHERE id = ? AND revoked_at IS NULL', { banId })
    if not ban then return false, 'ban_not_found' end
    NexoroDB.update('UPDATE nexoro_bans SET revoked_at = NOW(), revoked_by = ? WHERE id = ?', { describe(src).name, banId })
    return true, nil, { previous = { banId = banId, reason = ban.reason }, new = 'revoked' }
end }

-- Economy / jobs / items -------------------------------------------------
local function moneyAction(add)
    return { perm = 'nexoro.admin.money', target = true, reason = true, sensitive = true, allowSelf = false, run = function(src, p, t)
        local account = p.account == 'bank' and 'bank' or (p.account == 'cash' and 'cash' or nil)
        if not account then return false, 'invalid_account' end
        local before = core().GetPlayerMoney(t, account)
        local fn = add and core().AddMoney or core().RemoveMoney
        local ok, result = fn(t, tonumber(p.amount), account, 'admin:' .. p.reason)
        if not ok then return false, result end
        return true, { balance = result }, { previous = { [account] = before }, new = { [account] = result } }
    end }
end
A['addmoney'] = moneyAction(true)
A['removemoney'] = moneyAction(false)
A['setjob'] = { perm = 'nexoro.admin.jobs', target = true, allowSelf = false, run = function(_, p, t)
    local before = core().GetJob(t)
    local ok, err = core().SetJob(t, p.job, p.grade or 0)
    if not ok then return false, err end
    return true, nil, { previous = before and { job = before.name, grade = before.grade }, new = { job = p.job, grade = toInt(p.grade) or 0 } }
end }
A['giveitem'] = { perm = 'nexoro.admin.inventory', target = true, run = function(_, p, t)
    if not started('nexoro_inventory') then return false, 'inventory_unavailable' end
    local ok, err = exports.nexoro_inventory:AddItem(t, p.item, p.amount or 1)
    if not ok then return false, err end
    return true, nil, { new = { item = p.item, amount = toInt(p.amount) or 1 } }
end }
A['removeitem'] = { perm = 'nexoro.admin.inventory', target = true, run = function(_, p, t)
    if not started('nexoro_inventory') then return false, 'inventory_unavailable' end
    local ok, err = exports.nexoro_inventory:RemoveItem(t, p.item, p.amount or 1)
    if not ok then return false, err end
    return true, nil, { previous = { item = p.item, amount = toInt(p.amount) or 1 } }
end }
A['clearinventory'] = { perm = 'nexoro.admin.inventory', target = true, sensitive = true, reason = true, run = function(_, _, t)
    if not started('nexoro_inventory') then return false, 'inventory_unavailable' end
    local before = exports.nexoro_inventory:GetInventory(t)
    local ok, err = exports.nexoro_inventory:ClearInventory(t)
    if not ok then return false, err end
    return true, nil, { previous = before and before.items or nil, new = 'empty' }
end }
A['setstaffrank'] = { perm = 'nexoro.admin.staff', target = true, sensitive = true, reason = true, run = function(src, p, t)
    local rank = p.rank ~= 'none' and p.rank or nil
    local mine = core().GetStaffLevel(src)
    if rank then
        local def
        for _, r in ipairs(core().GetStaffRanks()) do if r.name == rank then def = r end end
        if not def then return false, 'unknown_rank' end
        if def.level >= mine and mine < 100 then return false, 'rank_too_high' end
    end
    local before = core().GetPlayer(t).staffRank
    local ok, err = core().SetStaffRank(t, rank, describe(src).name)
    if not ok then return false, err end
    return true, nil, { previous = before, new = rank }
end }

-- Self -------------------------------------------------------------------
local function toggle(name)
    return { perm = 'nexoro.admin.self', run = function(src)
        selfState[src] = selfState[src] or {}
        selfState[src][name] = not selfState[src][name]
        clientEffect(src, name, selfState[src][name])
        return true, { enabled = selfState[src][name] }, { new = selfState[src][name] }
    end }
end
A['noclip'], A['god'], A['invisible'], A['nametags'] = toggle('noclip'), toggle('god'), toggle('invisible'), toggle('nametags')
A['staffduty'] = { perm = 'nexoro.staff.duty', run = function(src)
    if staffDuty[src] then
        local minutes = math.floor((os.time() - staffDuty[src]) / 60)
        staffDuty[src] = nil
        return true, { onDuty = false }, { new = ('off duty after %d minutes'):format(minutes) }
    end
    staffDuty[src] = os.time()
    return true, { onDuty = true }, { new = 'on duty' }
end }

-- Vehicles ---------------------------------------------------------------
A['spawnvehicle'] = { perm = 'nexoro.admin.vehicles', target = true, allowSelf = true, defaultSelf = true, run = function(_, p, t)
    local model = type(p.model) == 'string' and p.model:lower() or ''
    if not model:match('^[%w_]+$') or #model < 3 or #model > 32 then return false, 'invalid_model' end
    local plate = type(p.plate) == 'string' and p.plate:upper():gsub('[^%w ]', ''):sub(1, 8) or nil
    clientEffect(t, 'spawnvehicle', { model = model, plate = plate ~= '' and plate or nil })
    return true, nil, { new = { model = model } }
end }
for _, name in ipairs({ 'deletevehicle', 'repairvehicle', 'cleanvehicle', 'flipvehicle' }) do
    A[name] = { perm = 'nexoro.admin.vehicles', target = true, allowSelf = true, defaultSelf = true, run = function(_, _, t) clientEffect(t, name); return true end }
end

-- Vehicle registry ---------------------------------------------------------
local function vehiclesUp() return started('nexoro_vehicles') end
local function plateOf(p) return type(p) == 'table' and type(p.plate) == 'string' and p.plate or '' end
A['vimpound'] = { perm = 'nexoro.admin.vehicles', reason = true, run = function(src, p)
    if not vehiclesUp() then return false, 'vehicles_unavailable' end
    local ok, err = exports.nexoro_vehicles:Impound(src, plateOf(p), p.reason, p.fee)
    if not ok then return false, err end
    return true, nil, { new = { plate = plateOf(p), impounded = true, fee = tonumber(p.fee) or 0 } }
end }
A['vrelease'] = { perm = 'nexoro.admin.vehicles', run = function(src, p)
    if not vehiclesUp() then return false, 'vehicles_unavailable' end
    local ok, err = exports.nexoro_vehicles:AdminRelease(plateOf(p), nil, describe(src).name)
    if not ok then return false, err end
    return true, nil, { new = { plate = plateOf(p), released = true } }
end }
A['vrepair'] = { perm = 'nexoro.admin.vehicles', run = function(src, p)
    if not vehiclesUp() then return false, 'vehicles_unavailable' end
    local ok, err = exports.nexoro_vehicles:AdminRepair(plateOf(p), describe(src).name)
    if not ok then return false, err end
    return true, nil, { new = { plate = plateOf(p), repaired = true } }
end }
A['vtransfer'] = { perm = 'nexoro.admin.vehicles', reason = true, sensitive = true, run = function(src, p)
    if not vehiclesUp() then return false, 'vehicles_unavailable' end
    local before = exports.nexoro_vehicles:LookupPlate(plateOf(p))
    local ok, err = exports.nexoro_vehicles:AdminTransfer(plateOf(p), p.citizenId, describe(src).name)
    if not ok then return false, err end
    return true, nil, { previous = before and { plate = before.plate, owner = before.owner, citizenId = before.ownerCitizenId } or nil, new = { plate = plateOf(p), citizenId = p.citizenId } }
end }
A['vdelete'] = { perm = 'nexoro.admin.vehicles', reason = true, sensitive = true, run = function(src, p)
    if not vehiclesUp() then return false, 'vehicles_unavailable' end
    local before = exports.nexoro_vehicles:LookupPlate(plateOf(p))
    local ok, err = exports.nexoro_vehicles:AdminDelete(plateOf(p), describe(src).name)
    if not ok then return false, err end
    return true, nil, { previous = before and { plate = before.plate, owner = before.owner, model = before.model } or nil, new = 'scrapped' }
end }

-- World / server -----------------------------------------------------------
local function broadcastWorld() TriggerClientEvent('nexoro:world:sync', -1, world) end
A['announce'] = { perm = 'nexoro.admin.world', run = function(_, p)
    local text = cleanText(p.text, 3, 300)
    if not text then return false, 'invalid_text' end
    if started('nexoro_chat') then exports.nexoro_chat:Announce(text) end
    for _, pl in ipairs(core().GetPlayers()) do core().Notify(pl.source, text, 'info', 12000) end
    return true, nil, { new = text }
end }
A['weather'] = { perm = 'nexoro.admin.world', run = function(_, p)
    local w = type(p.type) == 'string' and p.type:upper() or ''
    if not contains(cfg.Weathers, w) then return false, 'invalid_weather' end
    if started('nexoro_world') then
        local okW, why = exports.nexoro_world:SetWeather(w)
        if not okW then return false, why end
        return true, nil, { new = w }
    end
    local before = world.weather
    world.weather = w
    broadcastWorld()
    return true, nil, { previous = before, new = w }
end }
A['time'] = { perm = 'nexoro.admin.world', run = function(_, p)
    local h, m = toInt(p.hour), toInt(p.minute) or 0
    if not h or h < 0 or h > 23 or m < 0 or m > 59 then return false, 'invalid_time' end
    if started('nexoro_world') then
        exports.nexoro_world:SetTime(h, m)
        return true, nil, { new = ('%02d:%02d'):format(h, m) }
    end
    local before = ('%02d:%02d'):format(world.hour, world.minute)
    world.hour, world.minute = h, m
    broadcastWorld()
    return true, nil, { previous = before, new = ('%02d:%02d'):format(h, m) }
end }
A['freezetime'] = { perm = 'nexoro.admin.world', run = function()
    if started('nexoro_world') then
        local frozen = exports.nexoro_world:ToggleFrozen()
        return true, { frozen = frozen }, { new = frozen }
    end
    world.frozen = not world.frozen
    broadcastWorld()
    return true, { frozen = world.frozen }, { new = world.frozen }
end }
A['maintenance'] = { perm = 'nexoro.admin.resources', sensitive = true, run = function()
    maintenance = not maintenance
    return true, { enabled = maintenance }, { new = maintenance }
end }
A['restartresource'] = { perm = 'nexoro.admin.resources', sensitive = true, reason = true, run = function(_, p)
    local name = type(p.name) == 'string' and p.name or ''
    if not name:match('^nexoro_[%w_]+$') or cfg.RestartBlocked[name] then return false, 'resource_not_allowed' end
    if GetResourceState(name) == 'missing' then return false, 'resource_not_found' end
    StopResource(name)
    StartResource(name)
    return true, nil, { new = 'restarted ' .. name }
end }

---------------------------------------------------------------------------
-- Execution pipeline: ONE place enforces permission, hierarchy, confirmation, reasons and audit.
---------------------------------------------------------------------------

local NO_CHARACTER_OK = { kick = true, ban = true, tempban = true, warn = true, message = true }

function NexoroAdmin.Execute(src, name, payload)
    local def = type(name) == 'string' and A[name]
    if not def then return false, 'unknown_action' end
    if not core().HasPermission(src, def.perm) then
        core().Log('admin', 'denied:' .. name, src, {})
        return false, 'forbidden'
    end
    if cfg.RequireStaffDuty and name ~= 'staffduty' and not staffDuty[src] then return false, 'not_on_duty' end
    payload = type(payload) == 'table' and payload or {}

    local target
    if def.target then
        target = toInt(payload.target)
        if not target and def.defaultSelf then target = src end
        if not target or not core().GetPlayer(target) then return false, 'target_not_found' end
        if target == src then
            if not def.allowSelf then return false, 'cannot_target_self' end
        elseif not core().CanActOn(src, target) then
            core().Log('admin', 'blocked_hierarchy:' .. name, src, { target = target })
            return false, 'target_outranks_you'
        end
        if not core().GetCharacter(target) and not NO_CHARACTER_OK[name] then return false, 'target_has_no_character' end
    end
    if def.sensitive and payload.confirm ~= true then return false, 'confirmation_required' end
    if def.reason then
        payload.reason = cleanText(payload.reason, 3, 200)
        if not payload.reason then return false, 'reason_required' end
    end

    local okCall, ok, result, info = pcall(def.run, src, payload, target)
    if not okCall then
        print(('^1[Nexoro] admin action %s failed: %s^7'):format(name, tostring(ok)))
        return false, 'server_error'
    end
    if not ok then return false, result end
    info = info or {}
    audit(src, name, target, info.previous, info.new, payload.reason)
    return true, result
end

---------------------------------------------------------------------------
-- Read-only data for the menu
---------------------------------------------------------------------------

local function anyPerm(src, list)
    for _, perm in ipairs(list) do if core().HasPermission(src, perm) then return true end end
    return false
end

local function openMenu(src)
    local allowed = {}
    for name, def in pairs(A) do
        if core().HasPermission(src, def.perm) then allowed[#allowed + 1] = name end
    end
    if #allowed == 0 then return false, 'forbidden' end
    table.sort(allowed)
    local mine = core().GetStaffLevel(src)
    local ranks = {}
    for _, r in ipairs(core().GetStaffRanks()) do if r.level < mine or mine >= 100 then ranks[#ranks + 1] = r end end
    local p = core().GetPlayer(src)
    return true, {
        allowed = allowed, rank = p.staffRank, ranks = ranks, quickVehicles = cfg.QuickVehicles, weathers = cfg.Weathers,
        onDuty = staffDuty[src] ~= nil, maintenance = maintenance, world = world,
        canSeeDashboard = core().HasPermission(src, 'nexoro.admin.dashboard'),
        canSeePlayers = anyPerm(src, { 'nexoro.admin.players', 'nexoro.mod.reports' }),
        canSeeLogs = core().HasPermission(src, 'nexoro.staff.logs'),
        canSeeEconomy = core().HasPermission(src, 'nexoro.admin.economy'),
        canSeeBans = anyPerm(src, { 'nexoro.admin.bans', 'nexoro.mod.temporaryban' }),
        canSeeRegistry = core().HasPermission(src, 'nexoro.admin.vehicles'),
    }
end

local WATCH = { 'nexoro_database', 'nexoro_core', 'nexoro_identity', 'nexoro_character', 'nexoro_banking', 'nexoro_inventory', 'nexoro_chat', 'nexoro_notifications', 'nexoro_ui', 'nexoro_phone', 'nexoro_hud', 'nexoro_menu', 'nexoro_vehicles', 'nexoro_garages', 'nexoro_dealerships', 'nexoro_admin' }

local function dashboard(src)
    if not core().HasPermission(src, 'nexoro.admin.dashboard') then return false, 'forbidden' end
    local players = core().GetPlayers()
    local staff, onDuty, emergency = 0, 0, 0
    for _, p in ipairs(players) do
        if p.staffRank then staff = staff + 1 end
        if staffDuty[p.source] then onDuty = onDuty + 1 end
        local job = p.hasCharacter and core().GetJob(p.source)
        if job and job.onDuty and (job.category == 'police' or job.category == 'ambulance' or job.category == 'fire') then emergency = emergency + 1 end
    end
    local resources = {}
    for _, name in ipairs(WATCH) do resources[#resources + 1] = { name = name, state = GetResourceState(name) } end
    return true, {
        online = #players, maxClients = GetConvarInt('sv_maxclients', 48), staffOnline = staff, staffOnDuty = onDuty,
        emergencyOnDuty = emergency, uptimeSeconds = os.time() - startedAt, resources = resources,
        memoryMb = math.floor(collectgarbage('count') / 1024 * 10) / 10, maintenance = maintenance, world = world,
    }
end

local function playersList(src)
    if not anyPerm(src, { 'nexoro.admin.players', 'nexoro.mod.reports' }) then return false, 'forbidden' end
    local out = {}
    for _, p in ipairs(core().GetPlayers()) do
        out[#out + 1] = {
            id = p.source, name = p.name, characterName = p.characterName, citizenId = p.citizenId, job = p.job, jobGrade = p.jobGrade,
            onDuty = p.onDuty, ping = GetPlayerPing(p.source), staffRank = p.staffLabel, cash = p.cash, bank = p.bank,
        }
    end
    return true, out
end

local function playerDetails(src, payload)
    if not anyPerm(src, { 'nexoro.admin.players', 'nexoro.mod.reports' }) then return false, 'forbidden' end
    local target = type(payload) == 'table' and toInt(payload.id)
    local p = target and core().GetPlayer(target)
    if not p then return false, 'target_not_found' end
    local out = { id = target, name = p.name, license = p.license, staffRank = p.staffRank }
    local identifiers = {}
    for kind, value in pairs(p.identifiers) do identifiers[#identifiers + 1] = { kind = kind, value = value } end
    table.sort(identifiers, function(a, b) return a.kind < b.kind end)
    out.identifiers = identifiers
    local c = core().GetCharacter(target)
    if c then
        local job = core().GetJob(target)
        out.character = {
            id = c.id, citizenId = c.citizenId, name = c.firstName .. ' ' .. c.lastName, dob = c.dob, nationality = c.nationality,
            job = job and (job.label .. ' - ' .. job.gradeLabel) or c.job, onDuty = job and job.onDuty,
            cash = core().FormatGBP(c.cash), bank = core().FormatGBP(c.bank),
        }
        if started('nexoro_inventory') then
            local inv = exports.nexoro_inventory:GetInventory(target)
            if inv then
                out.inventory = { weight = inv.weight, maxWeight = inv.maxWeight, items = {} }
                for _, it in ipairs(inv.items) do out.inventory.items[#out.inventory.items + 1] = { label = it.label, amount = it.amount } end
            end
        end
        out.transactions = NexoroDB.query(
            "SELECT type, delta_pence, counterparty, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date FROM nexoro_transactions WHERE character_id = ? ORDER BY id DESC LIMIT 8", { c.id }) or {}
        for _, t in ipairs(out.transactions) do t.amount = core().FormatGBP(t.delta_pence); t.delta_pence = nil end
    end
    out.warnings = NexoroDB.query("SELECT reason, issued_by, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM nexoro_warnings WHERE license = ? ORDER BY id DESC LIMIT 10", { p.license }) or {}
    out.bans = NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_bans WHERE license = ?', { p.license }) or 0
    out.notes = NexoroDB.query("SELECT action, reason, staff_name, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date FROM nexoro_admin_logs WHERE target_license = ? ORDER BY id DESC LIMIT 8", { p.license }) or {}
    return true, out
end

local function logsList(src, payload)
    if not core().HasPermission(src, 'nexoro.staff.logs') then return false, 'forbidden' end
    payload = type(payload) == 'table' and payload or {}
    if payload.kind == 'admin' then
        return true, NexoroDB.query(
            "SELECT staff_name, staff_rank, action, target_name, previous_value, new_value, reason, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i:%s') AS date FROM nexoro_admin_logs ORDER BY id DESC LIMIT 100") or {}
    end
    local category = type(payload.category) == 'string' and payload.category:match('^[%w_]+$') and payload.category or nil
    local sql = "SELECT category, action, license, data, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i:%s') AS date FROM nexoro_logs"
    local params = {}
    if category then sql = sql .. ' WHERE category = ?'; params[1] = category end
    return true, NexoroDB.query(sql .. ' ORDER BY id DESC LIMIT 100', params) or {}
end

local function economy(src)
    if not core().HasPermission(src, 'nexoro.admin.economy') then return false, 'forbidden' end
    local totals = NexoroDB.single('SELECT COUNT(*) AS characters, COALESCE(SUM(cash_pence),0) AS cash, COALESCE(SUM(bank_pence),0) AS bank FROM nexoro_characters') or {}
    local threshold = math.floor(cfg.SuspiciousTransactionPounds * 100)
    local suspicious = NexoroDB.query(
        "SELECT citizen_id, type, delta_pence, counterparty, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date FROM nexoro_transactions WHERE ABS(delta_pence) >= ? ORDER BY id DESC LIMIT 30", { threshold }) or {}
    for _, t in ipairs(suspicious) do t.amount = core().FormatGBP(t.delta_pence); t.delta_pence = nil end
    local richest = NexoroDB.query('SELECT citizen_id, first_name, last_name, cash_pence, bank_pence FROM nexoro_characters ORDER BY (cash_pence + bank_pence) DESC LIMIT 10') or {}
    for _, r in ipairs(richest) do r.cash = core().FormatGBP(r.cash_pence); r.bank = core().FormatGBP(r.bank_pence); r.cash_pence, r.bank_pence = nil, nil end
    return true, {
        characters = totals.characters, cash = core().FormatGBP(totals.cash), bank = core().FormatGBP(totals.bank),
        total = core().FormatGBP((totals.cash or 0) + (totals.bank or 0)), suspicious = suspicious, richest = richest,
        thresholdText = core().FormatGBP(threshold),
    }
end

local function vehicleSearch(src, payload)
    if not core().HasPermission(src, 'nexoro.admin.vehicles') then return false, 'forbidden' end
    if not started('nexoro_vehicles') then return false, 'vehicles_unavailable' end
    return true, exports.nexoro_vehicles:Search(type(payload) == 'table' and payload.search or '')
end

local function bansList(src)
    if not anyPerm(src, { 'nexoro.admin.bans', 'nexoro.mod.temporaryban' }) then return false, 'forbidden' end
    return true, NexoroDB.query(
        "SELECT id, player_name, reason, banned_by, DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') AS date, DATE_FORMAT(expires_at, '%d/%m/%Y %H:%i') AS expires " ..
        'FROM nexoro_bans WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 100') or {}
end

---------------------------------------------------------------------------
-- Registration, commands, lifecycle
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    local rl = { rateLimit = { max = 30, windowMs = 10000 }, requireCharacter = false }
    C.RegisterCallback('nexoro_admin:open', openMenu, rl)
    C.RegisterCallback('nexoro_admin:action', function(src, name, payload) return NexoroAdmin.Execute(src, name, payload) end, rl)
    C.RegisterCallback('nexoro_admin:dashboard', dashboard, rl)
    C.RegisterCallback('nexoro_admin:players', playersList, rl)
    C.RegisterCallback('nexoro_admin:player', playerDetails, rl)
    C.RegisterCallback('nexoro_admin:logs', logsList, rl)
    C.RegisterCallback('nexoro_admin:economy', economy, rl)
    C.RegisterCallback('nexoro_admin:bans', bansList, rl)
    C.RegisterCallback('nexoro_admin:vehicles', vehicleSearch, rl)
    C.RegisterConnectHook(connectHook)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerReady', function(src)
    if not started('nexoro_world') then TriggerClientEvent('nexoro:world:sync', src, world) end
end)
AddEventHandler('nexoro:server:playerDropped', function(src)
    returnPos[src], selfState[src], staffDuty[src] = nil, nil, nil
end)

-- Chat commands mirror the menu and use the same pipeline (so the same permission checks and logs).
local COMMANDS = {
    ['goto'] = { 'goto', 'target' }, bring = { 'bring', 'target' }, freeze = { 'freeze', 'target' }, unfreeze = { 'unfreeze', 'target' },
    spectate = { 'spectate', 'target' }, kick = { 'kick', 'target', '*reason' }, warn = { 'warn', 'target', '*reason' },
    ban = { 'ban', 'target', 'minutes', '*reason' }, unban = { 'unban', 'banId', '*reason' }, staffduty = { 'staffduty' },
}
for command, spec in pairs(COMMANDS) do
    RegisterCommand(command, function(source, args)
        if source == 0 then return print('Use this command in game.') end
        local payload = { confirm = true }
        for i = 2, #spec do
            local field = spec[i]
            if field:sub(1, 1) == '*' then payload[field:sub(2)] = table.concat(args, ' ', i - 1)
            else payload[field] = args[i - 1] end
        end
        local ok, result = NexoroAdmin.Execute(source, spec[1], payload)
        core().Notify(source, ok and 'Done.' or ('Not done: ' .. tostring(result)), ok and 'staff' or 'error', 4000)
    end, false)
end
RegisterCommand('staffchat', function(source, args)
    if source == 0 or not started('nexoro_chat') then return end
    exports.nexoro_chat:Send(source, 'staff', table.concat(args, ' '))
end, false)

CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    local tick = 0
    while true do
        Wait(2000)
        if not world.frozen and not started('nexoro_world') then
            world.minute = world.minute + 1
            if world.minute >= 60 then world.minute = 0; world.hour = (world.hour + 1) % 24 end
        end
        tick = tick + 1
        if tick % 15 == 0 then broadcastWorld() end
    end
end)

exports('Execute', function(src, name, payload) return NexoroAdmin.Execute(src, name, payload) end)
exports('IsBanned', function(identifiers) return activeBanFor(identifiers) ~= nil end)
exports('GetWorld', function() return world end)
