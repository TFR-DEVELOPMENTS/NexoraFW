package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB

local function env(name, files, extra)
    local e = H.newEnv(name)
    e.NexoroDB = H.DB
    H.loadFiles(e, name, files)
    return e
end

H.resourceStates = { nexoro_world = "missing" }
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nexoro = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })

H.section('Migrations for all resources (real MariaDB)')
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'all migrations apply', err)
H.eq(applied, 21, 'six resources with migrations (database, banking, inventory, admin, phone, vehicles)')
for _, t in ipairs({ 'nexoro_transactions', 'nexoro_inventories', 'nexoro_inventory_items', 'nexoro_bans', 'nexoro_ban_identifiers', 'nexoro_warnings', 'nexoro_admin_logs' }) do
    H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t)
end
H.check(dbEnv.NexoroMigrations.Run() and select(2, dbEnv.NexoroMigrations.Run()) == 0, 'migrations are idempotent')

Nexoro.Ready = true
Nexoro.LoadJobs()
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local bankEnv = env('nexoro_banking', { 'config.lua', 'server/main.lua' })
local invEnv = env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
local chatEnv = env('nexoro_chat', { 'config.lua', 'server/main.lua' })
local adminEnv = env('nexoro_admin', { 'config.lua', 'server/main.lua' })
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local Chat = H.registry.nexoro_chat

---------------------------------------------------------------- Test players
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local citizen = {}
local function join(src, license, first, rank)
    H.addPlayerStub(src, first .. 'Account', { license })
    Nexoro.RegisterExistingPlayer(src)
    local id = { firstName = first, lastName = 'Tester', dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178, biography = '' }
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = id, appearance = defApp })
    assert(r == true, 'create failed for ' .. first .. ': ' .. tostring(d and d.message or d))
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    citizen[src] = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { d.id })
    if rank then Nexoro.Permissions.SetRank(src, rank, 'test') end
    H.coords[src] = { x = 0.0, y = 0.0, z = 30.0 }
end
join(1, 'license:own', 'Olivia', 'owner')
join(2, 'license:mod', 'Mo', 'moderator')
join(3, 'license:plain', 'Pat', nil)
join(4, 'license:sadmin', 'Sam', 'senior_admin')
join(5, 'license:smod', 'Sasha', 'senior_mod')
join(6, 'license:headadmin', 'Harry', 'head_admin')
H.coords[3] = { x = 500.0, y = 500.0, z = 30.0 }   -- Pat is far away from everyone else

---------------------------------------------------------------- Banking
H.section('Banking')
local function chars(src) local c = Core.GetCharacter(src); return c.cash, c.bank end
local function money(src) local c = H.DB.single('SELECT cash_pence, bank_pence FROM nexoro_characters WHERE id = ?', { Core.GetCharacter(src).id }); return c.cash_pence, c.bank_pence end
local function totalMoney() return H.DB.scalar('SELECT SUM(cash_pence + bank_pence) FROM nexoro_characters') end

local r, acct = H.callServer(1, 'nexoro_banking:account')
H.check(r == true and acct.cashText == '£250.00' and acct.bankText == '£1,500.00', 'account shows £250.00 cash and £1,500.00 bank')
local r1 = H.callServer(1, 'nexoro_banking:deposit', { amount = 100 })
local cash, bank = money(1)
H.check(r1 == true and cash == 15000 and bank == 160000, 'deposit £100 moves cash to bank atomically (database)')
H.eq(Core.GetPlayerMoney(1, 'bank'), 1600.0, 'cache matches after deposit')
local r2, e2 = H.callServer(1, 'nexoro_banking:deposit', { amount = 500 })
H.check(r2 == false and e2 == 'insufficient_funds', 'cannot deposit more cash than carried', e2)
H.check(H.callServer(1, 'nexoro_banking:withdraw', { amount = 50.50 }) == true, 'withdraw £50.50')
cash, bank = money(1)
H.check(cash == 20050 and bank == 154950, 'withdraw balances correct')
for _, bad in ipairs({ -5, 0, 0 / 0, math.huge, '10', 2.005 }) do
    local o = H.callServer(1, 'nexoro_banking:withdraw', { amount = bad })
    H.check(o == false, 'withdraw rejects ' .. tostring(bad))
    H.advance(3000)
end
local before = totalMoney()
local rt, et = H.callServer(1, 'nexoro_banking:transfer', { citizenId = citizen[3], amount = 200, note = 'Rent' })
H.check(rt == true, 'transfer £200 to online player', et)
local _, pb = money(3)
H.eq(pb, 170000, 'recipient bank is £1,700.00 (database)')
H.eq(Core.GetPlayerMoney(3, 'bank'), 1700.0, 'recipient cache refreshed')
H.eq(totalMoney(), before, 'money is conserved: no creation, no loss')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_transactions WHERE type IN (?, ?)', { 'transfer_out', 'transfer_in' }), 2, 'ledger has both sides of the transfer')
local _, st = H.callServer(1, 'nexoro_banking:statement', { page = 0 })
H.check(#st >= 3 and st[1].type == 'transfer_out' and st[1].amount == '-£200.00', 'statement lists newest first with £ formatting')
for _, case in ipairs({
    { citizen[1], 10, 'cannot_pay_yourself' }, { 'NXAAAAAA', 10, 'recipient_not_found' }, { 'nonsense', 10, 'invalid_recipient' },
    { citizen[3], 99999, 'insufficient_funds' }, { citizen[3], -50, 'invalid_amount' },
}) do
    H.advance(3000)
    local o, why = H.callServer(1, 'nexoro_banking:transfer', { citizenId = case[1], amount = case[2] })
    H.check(o == false and why == case[3], 'transfer rejected: ' .. case[3], why)
end
H.eq(totalMoney(), before, 'money still conserved after rejected transfers')
-- offline recipient
H.addPlayerStub(9, 'Offline', { 'license:off' }); Nexoro.RegisterExistingPlayer(9)
local ro, do_ = H.callServer(9, 'nexoro_character:create', { identity = { firstName = 'Ollie', lastName = 'Away', dob = '1988-01-01', gender = 'male', nationality = 'British', height = 170 }, appearance = defApp })
local offCitizen = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { do_.id })
H.advance(3000)
H.check(H.callServer(1, 'nexoro_banking:transfer', { citizenId = offCitizen, amount = 50 }) == true, 'transfer to an offline character works')
H.eq(H.DB.scalar('SELECT bank_pence FROM nexoro_characters WHERE id = ?', { do_.id }), 155000, 'offline recipient credited £50')
-- salary
Core.RegisterJob({ name = 'taxi', label = 'Taxi Driver', category = 'civilian', grades = { [0] = { label = 'Driver', salary = 12.50 } } })
Core.RegisterJob({ name = 'police', label = 'Police Constable', category = 'police', grades = { [0] = { label = 'PC', salary = 20 } } })
Core.SetJob(3, 'taxi', 0)
local bankBefore = select(2, money(3))
H.check(H.registry.nexoro_banking.PaySalary(3), 'civilian salary paid')
H.eq(select(2, money(3)) - bankBefore, 1250, 'salary of £12.50 credited to bank')
Core.SetJob(3, 'police', 0)
local paid, why = H.registry.nexoro_banking.PaySalary(3)
H.check(paid == false and why == 'off_duty', 'police salary not paid while off duty', why)
Core.SetDuty(3, true)
H.check(H.registry.nexoro_banking.PaySalary(3), 'police salary paid on duty')
Core.SetJob(3, 'unemployed', 0)

---------------------------------------------------------------- Inventory
H.section('Inventory')
local function inv(src) return Inv.GetInventory(src) end
local function count(src, item) return Inv.GetItemCount(src, item) end
H.check(Inv.AddItem(2, 'water', 3), 'add 3 water')
H.eq(inv(2).items[1].amount, 3, 'stored in slot 1')
H.check(Inv.AddItem(2, 'sandwich', 100), 'add 100 sandwiches (stack cap)')
local okw, whyw = Inv.AddItem(2, 'sandwich', 30)
H.check(okw == false and whyw == 'too_heavy', 'weight limit stops adding more (32.5 kg > 30 kg)', whyw)
H.eq(count(2, 'sandwich'), 100, 'inventory unchanged after rejected add')
H.check(Inv.AddItem(2, 'phone', 1) and Inv.AddItem(2, 'phone', 1, { serial = 'A1' }), 'non-stackable items get their own slots')
local phones = 0
for _, it in ipairs(inv(2).items) do if it.item == 'phone' then phones = phones + 1 end end
H.eq(phones, 2, 'two phone slots')
for _, bad in ipairs({ 0, -1, 0 / 0, 'x', 1e9 }) do
    local o = Inv.AddItem(3, 'water', bad)
    H.check(o == false, 'AddItem rejects amount ' .. tostring(bad))
end
H.check(Inv.AddItem(3, 'not_real', 1) == false, 'unknown item rejected')
H.check(Inv.AddItem(3, 'water', 5) and Inv.AddItem(3, 'water', 5), 'repeat adds stack together')
H.eq(#inv(3).items, 1, 'stacked into a single slot')
local rrem, wrem = Inv.RemoveItem(3, 'water', 99)
H.check(rrem == false and wrem == 'not_enough', 'cannot remove more than owned', wrem)
H.check(Inv.RemoveItem(3, 'water', 4), 'remove 4 water')
H.eq(count(3, 'water'), 6, '6 water left')
-- moves
Inv.AddItem(3, 'bandage', 2)
local bandageSlot, waterSlot
for _, it in ipairs(inv(3).items) do if it.item == 'bandage' then bandageSlot = it.slot end; if it.item == 'water' then waterSlot = it.slot end end
H.check(Inv.MoveItem(3, bandageSlot, 20), 'move to empty slot')
H.check(inv(3).items[#inv(3).items].slot == 20, 'item now in slot 20')
H.check(Inv.MoveItem(3, 20, waterSlot), 'swap different items')
H.check(Inv.MoveItem(3, waterSlot, 20, 1) == false, 'cannot split-swap onto a different item')
Inv.AddItem(3, 'water', 3)
local slots = {}
for _, it in ipairs(inv(3).items) do if it.item == 'water' then slots[#slots + 1] = it.slot end end
H.check(#slots >= 1, 'water present')
H.check(select(1, Inv.MoveItem(3, 1, 99)) == false, 'invalid destination slot rejected')
H.check(select(1, Inv.MoveItem(3, 35, 36)) == false, 'moving an empty slot rejected')
local split = Inv.MoveItem(3, slots[1], 30, 2)
H.check(split == true, 'split 2 into new slot')
H.eq(count(3, 'water'), 9, 'splitting never changes the total')
H.check(Inv.MoveItem(3, 30, slots[1]), 'merge the split back')
-- persistence
local weightBefore = inv(3).weight
H.fireHandlers(3, 'nexoro:server:characterUnloaded', 3, Core.GetCharacter(3).id)
H.eq(inv(3).weight, weightBefore, 'inventory reloads identically from the database')
-- use
H.sent = {}
local ru = Inv.UseItem(3, 20) -- bandage after swap may be elsewhere; find it
local bslot
for _, it in ipairs(inv(3).items) do if it.item == 'bandage' then bslot = it.slot end end
H.check(Inv.UseItem(3, bslot), 'using a bandage works')
local healed = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro:client:heal' then healed = true end end
H.check(healed, 'bandage triggered the heal effect')
H.eq(count(3, 'bandage'), 1, 'bandage consumed')
local phoneSlot
for _, it in ipairs(inv(2).items) do if it.item == 'phone' then phoneSlot = it.slot end end
local rp, wp = Inv.UseItem(2, phoneSlot)
H.check(rp == false and wp == 'not_usable', 'items without a use handler cannot be used', wp)
Inv.RegisterItem({ name = 'cursed', label = 'Cursed Idol', weight = 10, onUse = function() return false end })
Inv.AddItem(2, 'cursed', 1)
local cslot
for _, it in ipairs(inv(2).items) do if it.item == 'cursed' then cslot = it.slot end end
local rc, wc = Inv.UseItem(2, cslot)
H.check(rc == false and wc == 'cancelled' and count(2, 'cursed') == 1, 'a handler returning false cancels and keeps the item')
-- atomicity: database failure leaves memory untouched
local realTx = H.DB.transaction
H.DB.transaction = function() return false end
local rf, wf = Inv.AddItem(2, 'lockpick', 1)
H.DB.transaction = realTx
H.check(rf == false and wf == 'database_error' and count(2, 'lockpick') == 0, 'failed database write changes nothing in memory')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_inventory_items WHERE item = 'lockpick'"), 0, 'and nothing in the database')
-- callbacks and limits
local rg, gv = H.callServer(2, 'nexoro_inventory:get')
H.check(rg == true and gv.slots == 40 and gv.maxWeight == 30000, 'callback returns 40 slots and 30 kg limit')
H.check(H.callServer(2, 'nexoro_inventory:move', { from = 'x', to = 2 }) == false, 'callback rejects malformed slots')
-- core forwarding
H.check(Core.AddItem(3, 'lockpick', 1), 'Core.AddItem forwards to nexoro_inventory')
H.resourceStates.nexoro_inventory = 'stopped'
local rn, wn = Core.AddItem(3, 'lockpick', 1)
H.check(rn == nil and wn == 'inventory_unavailable', 'Core.AddItem reports inventory_unavailable when stopped')
H.resourceStates.nexoro_inventory = nil
-- stash and cleanup
H.check(Inv.AddItemToStash('police_locker', 'mrpd', 'radio', 2, nil, { slots = 10, maxWeight = 5000 }), 'stash accepts items')
H.check(Inv.AddItemToStash('police_locker', 'mrpd', 'repair_kit', 5, nil) == false, 'stash weight limit (5 kg) enforced')
H.check(Inv.AddItemToStash('character', '1', 'radio', 1) == false, 'stash API cannot touch character inventories')
local cid3 = Core.GetCharacter(3).id
H.fireHandlers(3, 'nexoro:server:characterDeleted', 3, cid3)
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_inventories WHERE owner_type = 'character' AND owner_id = ?", { tostring(cid3) }), 0, 'deleting a character deletes their inventory (cascade)')

---------------------------------------------------------------- Chat
H.section('Chat')
chatEnv.NexoroChat.getCoords = function(src) local c = H.coords[src]; if not c then return nil end return c.x, c.y, c.z end
local function messagesTo(dest, filter)
    local out = {}
    for _, e in ipairs(H.sent) do if e.name == 'nexoro_chat:message' and e.target == dest then out[#out + 1] = e.args[1] end end
    return out
end
local function say(src, channel, text, target) H.sent = {}; H.advance(10000); return Chat.Send(src, channel, text, target) end
local ok1 = say(2, 'local', 'Hello everyone')
local mDest = messagesTo(1)
H.check(ok1 and #mDest == 1 and mDest[1].prefix.label == 'CITIZEN', 'local message shows [CITIZEN] prefix')
H.check(#messagesTo(3) == 0, 'local chat is not delivered to players 500 m away')
H.check(#messagesTo(2) == 1, 'sender sees their own message')
say(2, 'local', '[POLICE] Officer Fake: stop right there')
local fake = messagesTo(1)[1]
H.check(fake.prefix.label == 'CITIZEN' and fake.name == 'Mo Tester', 'typed [POLICE] cannot change the server-assigned prefix')
Core.SetJob(2, 'police', 0)
say(2, 'local', 'Attending a collision')
H.eq(messagesTo(1)[1].prefix.label, 'CITIZEN', 'police off duty still shows CITIZEN')
Core.SetDuty(2, true)
say(2, 'local', 'Now attending a collision on the high street')
H.eq(messagesTo(1)[1].prefix.label, 'POLICE', 'police on duty shows [POLICE]')
Core.RegisterJob({ name = 'mechanic', label = 'Mechanic', grades = { [0] = { label = 'Mechanic', salary = 10 } } })
Core.SetJob(3, 'mechanic', 0)
say(3, 'global', 'Open for repairs')
H.eq(messagesTo(1)[1].prefix.label, 'MECHANIC', 'job name rule: [MECHANIC]')
H.check(#messagesTo(2) == 1 and #messagesTo(4) == 1, 'global reaches everyone')
local okS, whyS = say(3, 'staff', 'hi staff')
H.check(okS == false and whyS == 'forbidden', 'non-staff cannot use staff chat', whyS)
say(5, 'staff', 'staff only')
H.check(#messagesTo(1) == 1 and #messagesTo(3) == 0, 'staff chat only reaches staff')
local okE, whyE = say(3, 'emergency', 'help')
H.check(okE == false and whyE == 'not_emergency_service', 'civilians cannot use the emergency channel', whyE)
say(2, 'emergency', 'Units to the high street')
H.check(#messagesTo(2) == 1 and #messagesTo(1) == 0, 'emergency channel only reaches on-duty emergency services')
local okD = say(3, 'department', 'x')
H.check(okD == true, 'department chat works for players with a job')
H.check(say(1, 'department', 'x') == false, 'no department chat when unemployed')
say(1, 'pm', 'Secret', 2)
H.check(#messagesTo(2) == 1 and #messagesTo(4) == 0 and messagesTo(2)[1].pmTo == 'Mo Tester', 'private messages reach only sender and recipient')
H.check(say(1, 'pm', 'hi', 999) == false, 'pm to missing player fails')
H.check(say(1, 'nonsense', 'x') == false, 'unknown channel rejected')
H.check(say(1, 'local', '   ') == false, 'empty message rejected')
H.check(say(1, 'local', ('a'):rep(500)) and #messagesTo(1)[1].text == 240, 'long messages truncated to 240')
say(1, 'global', 'what the Fuck is this')
H.check(not messagesTo(1)[1].text:lower():find('fuck'), 'profanity filtered')
say(1, 'local', 'tab\1char\0ok')
H.eq(messagesTo(1)[1].text, 'tabcharok', 'control characters stripped')
Chat.Send(1, 'local', 'same text'); H.sent = {}
local d1, dwhy = Chat.Send(1, 'local', 'same text')
H.check(d1 == false and (dwhy == 'duplicate' or dwhy == 'cooldown'), 'rapid or duplicate messages blocked', dwhy)
H.advance(10000)
local muteHit
for i = 1, 20 do
    H.advance(800)
    local o, w = Chat.Send(1, 'local', 'spam message number ' .. i)
    if w == 'spam_muted' then muteHit = true break end
end
H.check(muteHit, 'spamming gets the player auto-muted')
H.check(Chat.IsMuted(1), 'muted state reported')
Chat.Unmute(1); H.advance(10000)
H.check(Chat.Send(1, 'local', 'back again'), 'unmute restores chat')
H.fireNet(2, 'nexoro_chat:send', 'global', 'via the secure event')
H.check(true, 'secure net event path does not error')
H.sent = {}
H.fireHandlers(4, 'nexoro:server:characterLoaded', 4)
local replay = messagesTo(4)
H.check(#replay > 0, 'chat history replayed to joining players (' .. #replay .. ' messages)')

---------------------------------------------------------------- Admin
H.section('Admin menu: access and hierarchy')
local function exec(src, name, payload) return adminEnv.NexoroAdmin.Execute(src, name, payload) end
local ropen, menu = H.callServer(1, 'nexoro_admin:open')
H.check(ropen == true and #menu.allowed > 30, 'owner menu exposes every action (' .. (menu and #menu.allowed or 0) .. ')')
local _, modMenu = H.callServer(2, 'nexoro_admin:open')
local hasMoney = false
for _, a in ipairs(modMenu.allowed) do if a == 'addmoney' then hasMoney = true end end
H.check(not hasMoney and #modMenu.allowed > 0, 'moderator menu hides economy actions')
H.check(H.callServer(3, 'nexoro_admin:open') == false, 'normal players cannot open the menu')
local denied, dwhy2 = exec(2, 'addmoney', { target = 3, account = 'bank', amount = 100, reason = 'because', confirm = true })
H.check(denied == false and dwhy2 == 'forbidden', 'moderator cannot add money', dwhy2)
H.check(exec(2, 'setjob', { target = 3, job = 'taxi' }) == false, 'moderator cannot change jobs')
H.check(exec(2, 'giveitem', { target = 3, item = 'water' }) == false, 'moderator cannot give items')
H.check(exec(2, 'restartresource', { name = 'nexoro_chat', reason = 'testing', confirm = true }) == false, 'moderator cannot restart resources')
H.check(exec(2, 'setstaffrank', { target = 3, rank = 'moderator', reason = 'testing', confirm = true }) == false, 'moderator cannot manage staff')
H.check(exec(2, 'ban', { target = 3, minutes = 0, reason = 'testing', confirm = true }) == false, 'plain moderator cannot ban')
H.check(exec(2, 'tempban', { target = 3, minutes = 60, reason = 'testing', confirm = true }) == false, 'plain moderator cannot temp-ban')
H.check(exec(99, 'kick', { target = 3, reason = 'x' }) == false, 'unknown sources have no access')
H.check(exec(3, 'kick', { target = 2, reason = 'x' }) == false, 'normal player cannot kick')
local k0, kwhy = exec(2, 'kick', { target = 3 })
H.check(k0 == false and kwhy == 'reason_required', 'kick requires a reason', kwhy)
local k1, kwhy1 = exec(2, 'kick', { target = 1, reason = 'testing' })
H.check(k1 == false and kwhy1 == 'target_outranks_you', 'moderator cannot kick the owner', kwhy1)
local k2, kwhy2 = exec(2, 'kick', { target = 2, reason = 'testing' })
H.check(k2 == false and kwhy2 == 'cannot_target_self', 'cannot kick yourself', kwhy2)
local k3, kwhy3 = exec(2, 'freeze', { target = 4 })
H.check(k3 == false and kwhy3 == 'target_outranks_you', 'moderator cannot freeze a senior administrator', kwhy3)
H.dropped = {}
H.check(exec(2, 'kick', { target = 3, reason = 'breaking rules' }), 'moderator can kick a normal player')
H.check(#H.dropped == 1 and H.dropped[1][1] == 3, 'kick drops the right player')
H.check(exec(2, 'kick', { target = 'abc', reason = 'testing' }) == false, 'garbage target rejected')
H.check(exec(2, 'kick', { target = -5, reason = 'testing' }) == false, 'negative target rejected')
H.check(exec(2, 'not_an_action', {}) == false, 'unknown action rejected')
H.check(exec(1, 'kick', 'not a table') == false, 'non-table payload rejected safely')

H.section('Admin menu: warnings, bans and the connect hook')
local w = exec(2, 'warn', { target = 3, reason = 'Failing RP' })
H.check(w, 'moderator can warn')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_warnings WHERE license = 'license:plain'"), 1, 'warning stored')
H.check(exec(5, 'tempban', { target = 3, minutes = 60, reason = 'Exploiting' }) == false, 'tempban needs confirmation')
local tb, tbData = exec(5, 'tempban', { target = 3, minutes = 60, reason = 'Exploiting', confirm = true })
H.check(tb and tbData.banId, 'senior moderator can temp-ban')
H.check(exec(5, 'tempban', { target = 6, minutes = 60, reason = 'Exploiting', confirm = true }) == false, 'senior moderator cannot ban head admin')
H.check(exec(5, 'tempban', { target = 3, minutes = 99999, reason = 'Too long', confirm = true }) == false, 'moderator ban duration capped at 7 days')
local hook = Nexoro.ConnectHooks[#Nexoro.ConnectHooks]
local blocked = hook(50, { license = 'license:plain', steam = 'steam:xyz' }, 'Pat')
H.check(type(blocked) == 'table' and blocked.allowed == false and blocked.reason:find('Exploiting'), 'banned licence is refused at connect with the reason')
local viaOther = hook(51, { license = 'license:newaccount', steam = 'steam:1100001' }, 'Alt')
local altPlayer = Core.GetPlayer(3)
local sameSteam = hook(52, { license = 'license:brandnew', discord = (altPlayer.identifiers.discord or 'none') }, 'Alt')
H.check(hook(53, { license = 'license:fine' }, 'Fine').allowed == true, 'unrelated players can still join')
H.DB.update("UPDATE nexoro_bans SET expires_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE)")
H.check(hook(54, { license = 'license:plain' }, 'Pat').allowed == true, 'expired temporary bans no longer block')
H.DB.update("UPDATE nexoro_bans SET expires_at = NULL")
H.check(hook(55, { license = 'license:plain' }, 'Pat').allowed == false, 'permanent ban blocks')
local banId = H.DB.scalar('SELECT MAX(id) FROM nexoro_bans')
H.check(exec(4, 'unban', { banId = banId, reason = 'Appeal accepted' }) == false, 'unban needs confirmation')
H.check(exec(4, 'unban', { banId = banId, reason = 'Appeal accepted', confirm = true }), 'senior admin can lift a ban')
H.check(hook(56, { license = 'license:plain' }, 'Pat').allowed == true, 'lifted ban allows joining again')
local rb, rbwhy = exec(4, 'unban', { banId = banId, reason = 'again', confirm = true })
H.check(rb == false and rbwhy == 'ban_not_found', 'cannot lift the same ban twice', rbwhy)
H.check(exec(4, 'ban', { target = 3, minutes = 0, reason = 'Permanent test', confirm = true }), 'admin can permanently ban')

H.section('Admin menu: economy, jobs, items, with audit trail')
local beforeBank = Core.GetPlayerMoney(4, 'bank')
local am, amData = exec(1, 'addmoney', { target = 4, account = 'bank', amount = 250.5, reason = 'Compensation ticket 41', confirm = true })
H.check(am, 'owner can add money')
H.eq(Core.GetPlayerMoney(4, 'bank'), beforeBank + 250.5, 'balance increased by £250.50')
local log = H.DB.single("SELECT * FROM nexoro_admin_logs WHERE action = 'addmoney' ORDER BY id DESC LIMIT 1")
H.check(log and log.reason == 'Compensation ticket 41' and log.previous_value:find('bank') and log.new_value:find('bank'), 'audit log keeps previous value, new value and reason')
H.check(log.staff_license == 'license:own' and log.target_license == 'license:sadmin' and log.staff_rank == 'owner', 'audit log records staff and target identifiers')
H.check(exec(1, 'addmoney', { target = 4, account = 'bank', amount = 10, reason = 'no confirm' }) == false, 'money actions need confirmation')
H.check(exec(1, 'addmoney', { target = 4, account = 'bank', amount = 10, confirm = true }) == false, 'money actions need a reason')
H.check(exec(1, 'addmoney', { target = 4, account = 'bank', amount = -10, reason = 'negative', confirm = true }) == false, 'negative amounts rejected')
H.check(exec(1, 'addmoney', { target = 4, account = 'crypto', amount = 10, reason = 'bad account', confirm = true }) == false, 'unknown account rejected')
H.check(exec(1, 'removemoney', { target = 4, account = 'bank', amount = 999999, reason = 'too much', confirm = true }) == false, 'cannot remove more than they have')
H.check(exec(1, 'addmoney', { target = 1, account = 'bank', amount = 10, reason = 'self', confirm = true }) == false, 'staff cannot give themselves money')
H.check(exec(1, 'setjob', { target = 4, job = 'taxi', grade = 0 }), 'owner can set a job')
H.check(exec(1, 'setjob', { target = 4, job = 'nonexistent', grade = 0 }) == false, 'unknown job rejected')
H.check(exec(1, 'setjob', { target = 4, job = 'taxi', grade = 77 }) == false, 'unknown grade rejected')
H.check(exec(1, 'giveitem', { target = 4, item = 'water', amount = 4 }), 'owner can give items')
H.eq(count(4, 'water'), 4, 'items arrived')
H.check(exec(1, 'removeitem', { target = 4, item = 'water', amount = 1 }), 'owner can remove items')
H.check(exec(1, 'clearinventory', { target = 4, reason = 'wipe' }) == false, 'clear inventory needs confirmation')
H.check(exec(1, 'clearinventory', { target = 4, reason = 'wipe', confirm = true }), 'owner can clear an inventory')
H.eq(#inv(4).items, 0, 'inventory is empty')

H.section('Admin menu: teleport, vehicles, world, server')
H.coords[1] = { x = 10.0, y = 20.0, z = 30.0 }; H.coords[4] = { x = 100.0, y = 200.0, z = 50.0 }
H.check(exec(1, 'goto', { target = 4 }), 'goto works')
H.eq(H.coords[1].x, 100.0, 'staff moved to the target')
H.check(exec(1, 'return', { target = 1 }), 'return works')
H.eq(H.coords[1].x, 10.0, 'staff returned to previous position')
H.check(exec(1, 'bring', { target = 4 }), 'bring works')
H.eq(H.coords[4].x, 10.0, 'target brought to staff')
H.check(exec(1, 'return', { target = 4 }) and H.coords[4].x == 100.0, 'brought player can be returned')
H.check(exec(1, 'tpcoords', { x = 1.5, y = 2.5, z = 40 }), 'teleport to coordinates')
H.check(exec(1, 'tpcoords', { x = 1e9, y = 0, z = 0 }) == false and exec(1, 'tpcoords', { x = 'a', y = 0, z = 0 }) == false, 'bad coordinates rejected')
H.sent = {}
H.check(exec(2, 'freeze', { target = 5 }) == false, 'moderator cannot freeze a senior moderator')
H.check(exec(5, 'freeze', { target = 3 }), 'senior moderator can freeze a normal player')
local froze = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro:admin:client' and e.target == 3 and e.args[1] == 'freeze' then froze = true end end
H.check(froze, 'freeze effect sent to the target client')
H.sent = {}
H.check(exec(1, 'spawnvehicle', { model = 'adder' }), 'spawn vehicle for self')
H.check(exec(1, 'spawnvehicle', { model = 'adder; DROP TABLE' }) == false and exec(1, 'spawnvehicle', { model = '' }) == false, 'invalid vehicle models rejected')
H.check(exec(1, 'repairvehicle', {}) and exec(1, 'cleanvehicle', {}) and exec(1, 'flipvehicle', {}), 'repair, clean and flip default to self')
H.check(exec(2, 'spawnvehicle', { model = 'adder' }) == false, 'moderators cannot spawn vehicles')
H.check(exec(1, 'noclip', {}) and exec(1, 'god', {}) and exec(1, 'invisible', {}), 'self toggles work')
H.check(select(2, exec(1, 'noclip', {})).enabled == false, 'noclip toggles off on second use')
H.check(exec(2, 'noclip', {}) == false, 'moderators cannot noclip')
H.check(exec(1, 'weather', { type = 'rain' }), 'weather change')
H.check(exec(1, 'weather', { type = 'SHARKNADO' }) == false, 'invalid weather rejected')
H.check(exec(1, 'time', { hour = 23, minute = 30 }), 'time change')
H.check(exec(1, 'time', { hour = 25 }) == false, 'invalid time rejected')
H.check(exec(1, 'announce', { text = 'Server restart in 10 minutes' }), 'announcement works')
H.check(exec(1, 'announce', { text = 'x' }) == false, 'too-short announcement rejected')
H.resourceCalls = {}
H.check(exec(1, 'restartresource', { name = 'nexoro_chat', reason = 'config change', confirm = true }), 'owner can restart a nexoro resource')
H.check(H.resourceCalls[1] == 'stop:nexoro_chat' and H.resourceCalls[2] == 'start:nexoro_chat', 'stop then start')
for _, name in ipairs({ 'nexoro_database', 'qb-core', 'nexoro_x;rm', '../nexoro_core', '' }) do
    H.check(exec(1, 'restartresource', { name = name, reason = 'abuse', confirm = true }) == false, 'restart blocked: "' .. name .. '"')
end
H.check(exec(1, 'maintenance', {}) == false, 'maintenance needs confirmation')
H.check(exec(1, 'maintenance', { confirm = true }), 'maintenance on')
local mhook = Nexoro.ConnectHooks[#Nexoro.ConnectHooks]
H.check(mhook(60, { license = 'license:randomguy' }, 'Guy').allowed == false, 'maintenance blocks normal players')
H.check(mhook(61, { license = 'license:own' }, 'Olivia').allowed == true, 'maintenance lets staff in')
exec(1, 'maintenance', { confirm = true })

H.section('Admin menu: staff ranks')
H.check(exec(6, 'setstaffrank', { target = 3, rank = 'owner', reason = 'escalation', confirm = true }) == false, 'head admin cannot assign owner')
H.check(exec(6, 'setstaffrank', { target = 3, rank = 'head_admin', reason = 'escalation', confirm = true }) == false, 'cannot assign a rank equal to your own')
H.check(exec(6, 'setstaffrank', { target = 3, rank = 'moderator', reason = 'promotion', confirm = true }) == false, 'head admin lacks staff-management permission by default')
H.check(exec(1, 'setstaffrank', { target = 3, rank = 'supreme_leader', reason = 'x', confirm = true }) == false, 'unknown rank rejected')
H.check(exec(1, 'setstaffrank', { target = 3, rank = 'trial_mod', reason = 'new hire', confirm = true }), 'owner can promote')
H.eq(Core.GetPlayer(3).staffRank, 'trial_mod', 'rank applied')
H.check(exec(1, 'setstaffrank', { target = 3, rank = 'none', reason = 'left staff', confirm = true }), 'owner can remove staff')

H.section('Admin menu: staff duty')
adminEnv.Config.Admin.RequireStaffDuty = true
H.check(select(2, exec(1, 'kick', { target = 3, reason = 'testing' })) == 'not_on_duty', 'actions need staff duty when configured')
H.check(exec(1, 'staffduty', {}), 'clock on')
H.check(exec(1, 'warn', { target = 3, reason = 'on duty now' }), 'actions allowed on duty')
adminEnv.Config.Admin.RequireStaffDuty = false

H.section('Admin menu: data views')
local rd, dash = H.callServer(1, 'nexoro_admin:dashboard')
H.check(rd == true and dash.online >= 6 and dash.staffOnline >= 5 and #dash.resources > 5, 'dashboard returns counts and resource states')
H.check(H.callServer(2, 'nexoro_admin:dashboard') == false, 'moderator has no dashboard')
local rpl, plist = H.callServer(2, 'nexoro_admin:players')
H.check(rpl == true and #plist >= 6 and plist[1].ping == 42, 'moderators can list players')
local rpd, pdet = H.callServer(2, 'nexoro_admin:player', { id = 4 })
H.check(rpd == true and pdet.character and pdet.character.cash:find('£') and #pdet.identifiers >= 1, 'player details include character and money in £')
local ipLeak = false
for _, i in ipairs(pdet.identifiers) do if i.kind == 'ip' then ipLeak = true end end
H.check(not ipLeak, 'player details never include IP addresses')
H.check(H.callServer(3, 'nexoro_admin:players') == false, 'normal players cannot list players')
local rlg, logs = H.callServer(1, 'nexoro_admin:logs', { kind = 'admin' })
H.check(rlg == true and #logs > 10 and logs[1].action, 'admin logs viewable')
H.check(H.callServer(2, 'nexoro_admin:logs', { kind = 'admin' }) == false, 'moderators cannot read logs without permission')
local rlc = H.callServer(1, 'nexoro_admin:logs', { category = "x' OR '1'='1" })
H.check(rlc == true, 'log category filter is parameterised (injection attempt returns safely)')
local re, eco = H.callServer(1, 'nexoro_admin:economy')
H.check(re == true and eco.total:find('£') and #eco.richest > 0, 'economy overview with £ totals')
H.check(H.callServer(2, 'nexoro_admin:economy') == false, 'moderators cannot see the economy tab')
local rbn, bans = H.callServer(4, 'nexoro_admin:bans')
H.check(rbn == true and #bans >= 1, 'active bans list')

H.section('Cross-cutting checks')
Nexoro.FlushLogs()
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE category = 'admin'") or 0) > 10, 'admin actions mirrored into the core audit log')
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE action LIKE 'denied:%'") or 0) >= 5, 'denied attempts are logged')
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE action LIKE 'blocked_hierarchy:%'") or 0) >= 2, 'hierarchy violations are logged')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters WHERE cash_pence < 0 OR bank_pence < 0'), 0, 'no negative balances anywhere')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
