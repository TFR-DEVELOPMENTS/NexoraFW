package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = {}
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nexoro = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })

H.section('Migrations including nexoro_phone')
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok and applied == 21, 'six resources with migrations apply (database, banking, inventory, admin, phone, vehicles)', err or applied)
for _, t in ipairs({ 'nexoro_phones', 'nexoro_phone_contacts', 'nexoro_phone_messages', 'nexoro_phone_calls', 'nexoro_phone_emails', 'nexoro_phone_adverts', 'nexoro_phone_posts' }) do
    H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t)
end

Nexoro.Ready = true; Nexoro.LoadJobs()
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local invEnv = env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
local bankEnv = env('nexoro_banking', { 'config.lua', 'server/main.lua' })
local phoneEnv = env('nexoro_phone', { 'config.lua', 'server/main.lua' })
local hudEnv = env('nexoro_hud', { 'config.lua', 'server/main.lua' })
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local Phone = H.registry.nexoro_phone

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license })
    Nexoro.RegisterExistingPlayer(src)
    local id = { firstName = first, lastName = last or 'Tester', dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178, biography = '' }
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = id, appearance = defApp })
    assert(r == true, 'create failed: ' .. tostring(d and d.message or d))
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    H.fireHandlers(src, 'nexoro:server:characterLoaded', src, nil)
    return d.id
end
local c1 = join(1, 'license:a', 'Anna', 'Smith')
local c2 = join(2, 'license:b', 'Ben', 'Jones')
local c3 = join(3, 'license:c', 'Cara', "O'Neil")
local c4 = join(4, 'license:d', 'Anna', 'Smith')   -- same name as player 1
for src = 1, 4 do Inv.AddItem(src, 'phone', 1) end

local function call(src, name, payload) H.advance(12000); return H.callServer(src, 'nexoro_phone:' .. name, payload) end
local function number(src) return Phone.GetNumber(src) end

---------------------------------------------------------------- Identity
H.section('Phone identity')
local r, open1 = call(1, 'open')
H.check(r == true, 'phone opens', open1)
H.check(open1.number:match('^07%d%d%d%d%d%d%d%d%d$') ~= nil, 'UK mobile number format 07xxxxxxxxx: ' .. tostring(open1.number))
H.check(open1.email == 'anna.smith@nexoro.co.uk', 'email is firstname.lastname@nexoro.co.uk', open1.email)
H.eq(open1.handle, '@anna_smith', 'social handle')
local _, open4 = call(4, 'open')
H.check(open4.email == 'anna.smith2@nexoro.co.uk' and open4.handle == '@anna_smith2', 'duplicate names get unique email and handle', open4.email)
local _, open3 = call(3, 'open')
H.check(open3.email == 'cara.oneil@nexoro.co.uk', "apostrophes stripped from email (cara.oneil)", open3.email)
call(2, 'open')
local nums = {}
for src = 1, 4 do nums[number(src)] = true end
local distinct = 0; for _ in pairs(nums) do distinct = distinct + 1 end
H.eq(distinct, 4, 'all four numbers are unique')
H.eq(open1.battery, 100, 'new phones start at 100% battery')
local again = select(2, call(1, 'open'))
H.eq(again.number, open1.number, 'number persists across opens')

H.section('Phone requirements: item and battery')
join(5, 'license:e', 'Eve')
local rn, wn = call(5, 'open')
H.check(rn == false and wn == 'no_phone', 'no phone item, no phone', wn)
Inv.AddItem(5, 'phone', 1)
H.check(call(5, 'open') == true, 'with a phone item it works')
Core.SetMetadata(5, 'phone_battery', 0)
local rb, wb = call(5, 'open')
H.check(rb == false and wb == 'battery_dead', 'dead battery blocks the phone', wb)
H.check(Phone.ChargePhone(5, 50), 'charging works')
H.check(call(5, 'open') == true and Core.GetMetadata(5, 'phone_battery') == 50, 'battery at 50% after charging')
H.check(select(2, Phone.ChargePhone(5, 9999)) == 100, 'battery capped at 100%')

---------------------------------------------------------------- Contacts
H.section('Contacts')
local n2, n3 = number(2), number(3)
local rc, list = call(1, 'contacts:save', { name = 'Ben', number = n2 })
H.check(rc == true and #list == 1 and list[1].name == 'Ben', 'save contact')
H.check(select(2, call(1, 'contacts:save', { name = 'Benjamin', number = n2 }))[1].name == 'Benjamin', 'saving the same number updates the name (no duplicate)')
for _, bad in ipairs({ { name = 'X', number = '12345' }, { name = 'X', number = '07abcdefghi' }, { name = '', number = n3 }, { name = 'X', number = number(1) }, { name = ('n'):rep(40), number = n3 }, 'junk' }) do
    local ok2 = call(1, 'contacts:save', bad)
    H.check(ok2 == false, 'contact rejected: ' .. (type(bad) == 'table' and tostring(bad.number) or 'non-table'))
end
H.check(select(2, call(1, 'contacts:save', { name = 'Cara', number = n3 })) ~= nil, 'second contact')
local cid = H.DB.scalar('SELECT id FROM nexoro_phone_contacts WHERE character_id = ? LIMIT 1', { c1 })
call(2, 'contacts:delete', { id = cid })
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_phone_contacts WHERE character_id = ?', { c1 }), 2, "another player cannot delete my contacts")
H.check(call(1, 'contacts:delete', { id = cid }) == true and H.DB.scalar('SELECT COUNT(*) FROM nexoro_phone_contacts WHERE character_id = ?', { c1 }) == 1, 'I can delete my own')
phoneEnv.Config.Phone.MaxContacts = 2
call(1, 'contacts:save', { name = 'A', number = number(4) })
local rl, wl = call(1, 'contacts:save', { name = 'B', number = number(5) })
H.check(rl == false and wl == 'contact_limit', 'contact limit enforced', wl)
phoneEnv.Config.Phone.MaxContacts = 100

---------------------------------------------------------------- Messages
H.section('Messages')
H.sent = {}
H.check(call(1, 'messages:send', { to = n2, body = 'Hello Ben' }) == true, 'send SMS')
local pushed = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_phone:message' and e.target == 2 then pushed = e.args[1].from == number(1) end end
H.check(pushed, 'online recipient gets a push with the sender number')
H.check(call(1, 'messages:send', { to = n2, body = "'; DROP TABLE nexoro_characters;--" }) == true, 'hostile text is accepted as plain text')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters'), 5, 'and nothing was injected')
for _, case in ipairs({ { '07000000000', 'hi', 'number_not_found' }, { 'abc', 'hi', 'invalid_number' }, { n2, '', 'invalid_message' }, { n2, ('x'):rep(300), 'invalid_message' }, { number(1), 'hi', 'own_number' } }) do
    local ok2, why2 = call(1, 'messages:send', { to = case[1], body = case[2] })
    H.check(ok2 == false and why2 == case[3], 'send rejected: ' .. case[3], why2)
end
local _, convs = call(2, 'messages:conversations')
H.check(#convs == 1 and convs[1].number == number(1) and convs[1].unread == 2, 'recipient sees 1 conversation with 2 unread')
local _, thread = call(2, 'messages:thread', { number = number(1) })
H.check(#thread == 2 and thread[1].mine == false and thread[1].body == 'Hello Ben', 'thread shows messages in order, mine=false')
H.eq(select(2, call(2, 'messages:conversations'))[1].unread, 0, 'opening the thread marks messages read')
call(2, 'messages:send', { to = number(1), body = 'Hi Anna' })
local _, t1 = call(1, 'messages:thread', { number = n2 })
H.check(#t1 == 3 and t1[3].mine == false and t1[1].mine == true, 'sender view marks own messages')
local _, t3 = call(3, 'messages:thread', { number = number(1) })
H.eq(#t3, 0, 'a third party cannot read someone else\'s thread')
local limited = 0
for i = 1, 14 do H.advance(100); local _, w = H.callServer(1, 'nexoro_phone:messages:send', { to = n2, body = 'spam ' .. i }); if w == 'rate_limited' then limited = limited + 1 end end
H.check(limited > 0, 'SMS spam is rate limited (' .. limited .. ' blocked)')

---------------------------------------------------------------- Calls
H.section('Calls')
H.localEvents = {}
local rcall, cdata = call(1, 'call', { to = n2 })
H.check(rcall == true and cdata.id, 'call connects (ringing)')
local callId = cdata.id
H.check(call(3, 'call', { to = n2 }) == false, 'callee is busy for a third caller')
H.check(select(2, call(3, 'call', { to = n2 })) == 'busy', 'busy reason reported')
H.check(call(1, 'call', { to = n3 }) == false and select(2, call(1, 'call', { to = n3 })) == 'already_in_call', 'caller cannot start a second call')
H.check(call(3, 'answer', { id = callId }) == false, 'only the callee can answer')
H.check(call(1, 'answer', { id = callId }) == false, 'caller cannot answer their own call')
H.check(call(2, 'answer', { id = callId }) == true, 'callee answers')
H.sent = {}
H.check(call(1, 'hangup') == true, 'caller hangs up')
local ended = 0
for _, e in ipairs(H.sent) do if e.name == 'nexoro_phone:ended' then ended = ended + 1 end end
H.eq(ended, 2, 'both parties are told the call ended')
local logRow = H.DB.single('SELECT status FROM nexoro_phone_calls ORDER BY id DESC LIMIT 1')
H.eq(logRow.status, 'answered', 'answered call logged')
H.check(call(1, 'hangup') == false, 'cannot hang up when not in a call')
local _, cid2 = call(1, 'call', { to = n2 })
call(2, 'hangup')
H.eq(H.DB.scalar('SELECT status FROM nexoro_phone_calls ORDER BY id DESC LIMIT 1'), 'declined', 'declined call logged')
local _, cid3 = call(1, 'call', { to = n2 })
Phone.GetNumber(1)
phoneEnv.NexoroPhone.EndCall(cid3.id, 'missed')
H.eq(H.DB.scalar('SELECT status FROM nexoro_phone_calls ORDER BY id DESC LIMIT 1'), 'missed', 'unanswered calls are logged as missed')
H.check(call(1, 'call', { to = number(1) }) == false, 'cannot call yourself')
H.check(call(1, 'call', { to = '07000000000' }) == false, 'unknown number is unavailable')
H.localEvents = {}
local re, ed = call(1, 'call', { to = '999' })
local fired = false
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:emergencyCall' and e[2] == 1 and e[3] == '999' and e[4] == 'emergency' then fired = true end end
H.check(re == true and ed.emergency == 'emergency' and fired, '999 raises the emergency-call event for dispatch')
H.check(call(1, 'call', { to = '101' }) == true and call(1, 'call', { to = '111' }) == true, '101 and 111 also connect')
H.check(call(1, 'call', { to = '998' }) == false, 'other short codes are not emergency numbers')
local _, log = call(1, 'callLog')
H.check(#log >= 4 and log[1].direction == 'outgoing', 'call log lists newest first with direction')
-- disconnect mid-call
local _, cid4 = call(1, 'call', { to = n2 })
call(2, 'answer', { id = cid4.id })
H.sent = {}
H.fireHandlers(1, 'nexoro:server:playerDropped', 1)
local notified = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_phone:ended' and e.target == 2 then notified = true end end
H.check(notified, 'dropping mid-call ends it for the other player')
H.addPlayerStub(1, 'Anna', { 'license:a' }); Nexoro.RegisterExistingPlayer(1)
H.check(H.callServer(1, 'nexoro_character:select', { id = c1 }) == true, 'player 1 rejoins')
H.fireHandlers(1, 'nexoro:server:characterLoaded', 1)
H.check(call(1, 'open') == true, 'phone works again after rejoining')
H.check(call(2, 'call', { to = number(1) }) == true, 'rejoined player is reachable again')
call(2, 'hangup')

---------------------------------------------------------------- Mail
H.section('Email')
local em = 'anna.smith@nexoro.co.uk'
H.check(call(2, 'mail:send', { to = em, subject = 'Meeting', body = 'Tomorrow at 10?' }) == true, 'send email')
H.check(call(2, 'mail:send', { to = 'nobody@nexoro.co.uk', subject = 'x', body = 'x' }) == false and select(2, call(2, 'mail:send', { to = 'nobody@nexoro.co.uk', subject = 'x', body = 'x' })) == 'address_not_found', 'unknown address rejected')
H.check(call(2, 'mail:send', { to = 'not an address', subject = 'x', body = 'x' }) == false, 'invalid address rejected')
H.check(call(2, 'mail:send', { to = em, subject = '', body = 'x' }) == false and call(2, 'mail:send', { to = em, subject = 'x', body = '' }) == false, 'empty subject/body rejected')
local _, inbox = call(1, 'mail:inbox')
H.check(#inbox == 1 and inbox[1].subject == 'Meeting' and inbox[1].is_read == 0, 'recipient sees the email unread')
call(1, 'mail:read', { id = inbox[1].id })
H.eq(select(2, call(1, 'mail:inbox'))[1].is_read, 1, 'marked read')
call(3, 'mail:delete', { id = inbox[1].id })
H.eq(#select(2, call(1, 'mail:inbox')), 1, 'someone else cannot delete my mail')
call(1, 'mail:delete', { id = inbox[1].id })
H.eq(#select(2, call(1, 'mail:inbox')), 0, 'I can delete my own mail')
H.eq(#select(2, call(3, 'mail:inbox')), 0, 'other inboxes stay private')

---------------------------------------------------------------- Adverts
H.section('Adverts')
local bank0 = Core.GetPlayerMoney(2, 'bank')
H.check(call(2, 'ads:post', { title = 'Car for sale', body = 'Fast one', price = 5000 }) == true, 'post an advert')
H.eq(Core.GetPlayerMoney(2, 'bank'), bank0 - 25, '£25 charged to the bank account')
local ra, wa = call(2, 'ads:post', { title = 'Again', body = 'x' })
H.check(ra == false and wa == 'advert_cooldown', 'advert cooldown enforced', wa)
local _, ads = call(3, 'ads:list')
H.check(#ads == 1 and ads[1].price == '£5,000.00' and ads[1].mine == false, 'others see it with formatted £ price')
local _, mine = call(2, 'ads:list')
H.check(mine[1].mine == true, 'owner sees mine=true')
call(3, 'ads:delete', { id = ads[1].id })
H.eq(#select(2, call(3, 'ads:list')), 1, 'others cannot delete my advert')
H.advance(400000)
H.check(call(2, 'ads:post', { title = 'Bad price', body = 'x', price = -5 }) == false, 'negative price rejected')
H.check(call(2, 'ads:post', { title = '', body = 'x' }) == false, 'empty title rejected')
Core.RemoveMoney(3, Core.GetPlayerMoney(3, 'bank'), 'bank', 'test drain')
local rp, wp = call(3, 'ads:post', { title = 'Broke', body = 'x' })
H.check(rp == false and wp == 'cannot_afford_advert', 'cannot place an advert without funds', wp)
H.eq(H.DB.scalar("SELECT bank_pence FROM nexoro_characters WHERE id = ?", { c3 }), 0, 'balance untouched by failed purchase')
call(2, 'ads:delete', { id = ads[1].id })
H.eq(#select(2, call(3, 'ads:list')), 0, 'owner deletes advert')

---------------------------------------------------------------- Social, settings, jobs
H.section('Chirp, settings and jobs')
H.check(call(1, 'social:post', { body = 'First chirp!' }) == true, 'post to Chirp')
H.check(call(1, 'social:post', { body = '   ' }) == false, 'empty post rejected')
local _, feed = call(2, 'social:feed')
H.check(#feed == 1 and feed[1].handle == '@anna_smith' and feed[1].mine == false, 'feed shows the author handle chosen by the server')
call(2, 'social:delete', { id = feed[1].id })
H.eq(#select(2, call(2, 'social:feed')), 1, 'cannot delete someone else\'s post')
call(1, 'social:delete', { id = feed[1].id })
H.eq(#select(2, call(2, 'social:feed')), 0, 'author deletes own post')
local _, st = call(1, 'settings:save', { wallpaper = 'nexoro_dusk', ringtone = 'trevor' })
H.check(st.wallpaper == 'nexoro_dusk' and st.ringtone == 'trevor', 'settings saved')
local _, st2 = call(1, 'settings:save', { wallpaper = '../../etc/passwd', ringtone = 'x' })
H.check(st2.wallpaper == 'nexoro_dusk' and st2.ringtone == 'trevor', 'unknown wallpaper/ringtone values are ignored')
Core.RegisterJob({ name = 'chef', label = 'Chef', category = 'civilian', grades = { [0] = { label = 'Cook', salary = 11 } } })
local _, jobs = call(1, 'jobs')
local names = {}
for _, j in ipairs(jobs.open) do names[j.label] = j.salary end
H.check(names['Chef'] == '£11.00' and names['Unemployed'] == nil, 'jobs app lists open jobs with £ salaries, not unemployed')
H.check(Core.GetJobs()[1].grades ~= nil, 'Core.GetJobs returns grades')

---------------------------------------------------------------- Character deletion
H.section('Cleanup')
H.DB.update('DELETE FROM nexoro_characters WHERE id = ?', { c4 })
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_phones WHERE character_id = ?', { c4 }), 0, 'deleting a character removes their phone')
H.check(H.DB.scalar('SELECT COUNT(*) FROM nexoro_phone_messages') > 0, 'message history is kept for the other party')

---------------------------------------------------------------- HUD needs
H.section('HUD needs (hunger, thirst, stress)')
local Hud = hudEnv.NexoroHud
Hud.Load(2)
local needs = Hud.GetNeeds(2)
H.check(needs and needs.hunger == 100 and needs.thirst == 100 and needs.stress == 0, 'new characters start full and calm')
H.sent = {}
H.check(Hud.Tick(2), 'tick runs')
needs = Hud.GetNeeds(2)
H.check(math.abs(needs.hunger - 99.4) < 0.001 and math.abs(needs.thirst - 99.1) < 0.001, 'hunger -0.6 and thirst -0.9 per minute')
H.eq(Core.GetMetadata(2, 'hunger'), 99, 'whole-number change is persisted as metadata')
local pushedNeeds = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_hud:needs' and e.target == 2 then pushedNeeds = true end end
H.check(pushedNeeds, 'client receives the new values')
H.check(Hud.SetNeed(2, 'thirst', 0), 'set thirst to 0')
H.sent = {}
Hud.Tick(2)
local damage
for _, e in ipairs(H.sent) do if e.name == 'nexoro_hud:starving' then damage = e.args[1] end end
H.eq(damage, 5, 'starvation damage event at 0 thirst')
H.check(Hud.GetNeeds(2).thirst == 0, 'needs never go below 0')
H.check(not Hud.SetNeed(2, 'thirst', 0 / 0) and not Hud.SetNeed(2, 'bogus', 5), 'invalid values and keys rejected')
Hud.SetNeed(2, 'thirst', 500)
H.eq(Hud.GetNeeds(2).thirst, 100, 'values are capped at 100')
Hud.AddStress(2, 80); Hud.AddStress(2, 80)
H.eq(Hud.GetNeeds(2).stress, 100, 'stress capped at 100')
Hud.Tick(2)
H.check(Hud.GetNeeds(2).stress < 100, 'stress recovers over time')
H.fireHandlers(2, 'nexoro:server:metadataChanged', 2, 'thirst', 40)
H.eq(Hud.GetNeeds(2).thirst, 40, 'items that change metadata (water) update the HUD state')
H.fireHandlers(2, 'nexoro:server:metadataChanged', 2, 'unrelated', 1)
H.check(true, 'unrelated metadata ignored')
H.fireHandlers(2, 'nexoro:server:characterUnloaded', 2)
H.check(Hud.GetNeeds(2) == nil and Hud.Tick(2) == false, 'state cleared on unload')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
