package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
local json = { encode = require('cjson').encode, decode = require('cjson').decode }

H.resetDatabase()
_G.NexoroDB = H.DB

---------------------------------------------------------------- Load resources into isolated environments
local dbEnv = H.newEnv('nexoro_database')
dbEnv.NexoroDB = H.DB
H.loadFiles(dbEnv, 'nexoro_database', { 'config.lua', 'server/migrations.lua' })

local coreEnv = H.newEnv('nexoro_core')
coreEnv.NexoroDB = H.DB
H.loadFiles(coreEnv, 'nexoro_core', {
    'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua',
    'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua',
})
local Nexoro, U = coreEnv.Nexoro, coreEnv.Nexoro.Utils

local idEnv = H.newEnv('nexoro_identity')
H.loadFiles(idEnv, 'nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })

local chEnv = H.newEnv('nexoro_character')
chEnv.NexoroDB = H.DB
H.loadFiles(chEnv, 'nexoro_character', { 'config.lua', 'server/appearance.lua' })
local Appearance = chEnv.NexoroAppearance

---------------------------------------------------------------- Utils
H.section('Utilities (UK formatting and money maths)')
H.eq(U.FormatGBP(125000), '£1,250.00', 'formats £1,250.00')
H.eq(U.FormatGBP(0), '£0.00', 'formats zero')
H.eq(U.FormatGBP(5), '£0.05', 'formats pence')
H.eq(U.FormatGBP(123456789), '£1,234,567.89', 'formats millions')
H.eq(U.ToPence(12.5), 1250, 'ToPence(12.5)')
H.eq(U.ToPence(0.1 + 0.2), 30, 'ToPence handles float error')
H.check(U.ToPence(-1) == nil, 'ToPence rejects negatives')
H.check(U.ToPence(0 / 0) == nil, 'ToPence rejects NaN')
H.check(U.ToPence(math.huge) == nil, 'ToPence rejects infinity')
H.check(U.ToPence(1.005) == nil, 'ToPence rejects sub-penny amounts')
H.check(U.ToPence('5') == nil, 'ToPence rejects strings')
H.check(U.PermissionMatches('nexoro.admin.*', 'nexoro.admin.money'), 'wildcard matches child')
H.check(not U.PermissionMatches('nexoro.admin.*', 'nexoro.mod.kick'), 'wildcard does not cross namespaces')
H.check(not U.PermissionMatches('nexoro.admin', 'nexoro.administrator'), 'no partial-name match')
H.check(U.PermissionMatches('*', 'anything.at.all'), 'star matches all')
H.eq(U.SanitizeText('  hi\1there  ', 20), 'hithere', 'SanitizeText strips control characters')
H.eq(U.SanitizeText(('x'):rep(50), 10), ('x'):rep(10), 'SanitizeText limits length')
H.check(U.SanitizeText('\xff\xfe', 10) == nil, 'SanitizeText rejects invalid UTF-8')

---------------------------------------------------------------- Identity
H.section('Identity validation')
local Id = idEnv.NexoroIdentity
local today = { year = 2026, month = 11, day = 9 }
local good = { firstName = 'john', lastName = "o'brien-smith", dob = '1995-03-14', gender = 'male', nationality = 'British', height = 180, biography = 'Born in Inverness.' }
local ok, c = Id.ValidateCharacter(good, today)
H.check(ok, 'accepts a valid character')
H.eq(c and c.firstName, 'John', 'capitalises first name')
H.eq(c and c.lastName, "O'Brien-Smith", 'capitalises apostrophes and hyphens')
local function bad(mut, field, label)
    local d = {}; for k, v in pairs(good) do d[k] = v end
    mut(d)
    local o, e = Id.ValidateCharacter(d, today)
    H.check(not o and e.field == field, label, o and 'accepted' or e.field)
end
bad(function(d) d.firstName = 'A' end, 'firstName', 'rejects one-letter name')
bad(function(d) d.firstName = 'J0hn' end, 'firstName', 'rejects digits in names')
bad(function(d) d.firstName = 'Police'; d.lastName = 'Officer' end, 'firstName', 'blocks staff/service impersonation names')
bad(function(d) d.lastName = '<script>' end, 'lastName', 'rejects markup in names')
bad(function(d) d.dob = '2010-01-01' end, 'dob', 'rejects under-18s')
bad(function(d) d.dob = '2026-11-10' end, 'dob', 'rejects future dates')
bad(function(d) d.dob = '1990-02-30' end, 'dob', 'rejects impossible dates')
bad(function(d) d.dob = '14/03/1995' end, 'dob', 'rejects non-ISO date format')
bad(function(d) d.gender = 'robot' end, 'gender', 'rejects unknown gender value')
bad(function(d) d.nationality = 'Martian' end, 'nationality', 'rejects unknown nationality')
bad(function(d) d.height = 400 end, 'height', 'rejects extreme height')
bad(function(d) d.height = 0 / 0 end, 'height', 'rejects NaN height')
bad(function(d) d.biography = 42 end, 'biography', 'rejects non-text biography')
local leap, _ = Id.ValidateCharacter((function() local d = {}; for k, v in pairs(good) do d[k] = v end; d.dob = '2000-02-29'; return d end)(), today)
H.check(leap, 'accepts 29 February in a leap year')
local seen, allValid = {}, true
for _ = 1, 200 do local cid = Id.GenerateCitizenId(); seen[cid] = true; allValid = allValid and Id.IsValidCitizenId(cid) end
H.check(allValid, 'generated citizen IDs are valid')
H.check(not Id.IsValidCitizenId('NX0O1I2'), 'rejects confusable characters')

---------------------------------------------------------------- Appearance
H.section('Appearance validation')
local okA, a = Appearance.Validate({ model = 'mp_m_freemode_01', headBlend = { shapeFirst = 999, shapeMix = 5 }, faceFeatures = { 99, -99, 0 / 0 }, hair = { style = -5 }, components = { { drawable = 1e9 } } })
H.check(okA, 'accepts partial data and fills defaults')
H.eq(a.headBlend.shapeFirst, 45, 'clamps head blend to 45')
H.eq(a.headBlend.shapeMix, 1, 'clamps mix to 1')
H.eq(a.faceFeatures[1], 1, 'clamps face feature high')
H.eq(a.faceFeatures[2], -1, 'clamps face feature low')
H.eq(a.faceFeatures[3], 0.0, 'NaN face feature becomes 0')
H.eq(#a.faceFeatures, 20, 'always 20 face features')
H.eq(a.hair.style, 0, 'clamps negative hair style')
H.eq(a.components[1].drawable, 600, 'clamps enormous drawable')
H.eq(#a.props, 5, 'always 5 props')
H.check(not Appearance.Validate({ model = 'a_c_cat_01' }), 'rejects non-freemode models')
H.check(not Appearance.Validate('nope'), 'rejects non-table')
H.check(a.evil == nil, 'drops unknown keys')

---------------------------------------------------------------- Migrations against real MariaDB
H.section('Database migrations (real MariaDB)')
H.resourceStates = { nexoro_database = 'started', nexoro_core = 'started', nexoro_identity = 'started', nexoro_character = 'started' }
local M = dbEnv.NexoroMigrations
local okM, applied, errM = M.Run()
H.check(okM, 'migrations run cleanly', errM)
H.eq(applied, 21, 'applies each resource migration once (database, banking, inventory, admin, phone, vehicles)')
local okM2, applied2 = M.Run()
H.check(okM2 and applied2 == 0, 're-running applies nothing (idempotent)')
local tables = H.DB.query('SHOW TABLES') or {}
local tableSet = {}
for _, row in ipairs(tables) do for _, v in pairs(row) do tableSet[v] = true end end
for _, name in ipairs({ 'nexoro_players', 'nexoro_player_identifiers', 'nexoro_characters', 'nexoro_character_appearance', 'nexoro_character_outfits', 'nexoro_player_metadata', 'nexoro_jobs', 'nexoro_job_grades', 'nexoro_staff_assignments', 'nexoro_logs', 'nexoro_schema_migrations' }) do
    H.check(tableSet[name], 'table exists: ' .. name)
end
H.eq(#M.Split('A;\n-- @@\n-- comment only\n-- @@\nB;\n'), 2, 'splitter drops comment-only chunks')

---------------------------------------------------------------- Core: players, permissions, jobs, money
H.section('Core: player registration')
Nexoro.Ready = true
Nexoro.LoadJobs()
H.eq(Nexoro.Jobs.unemployed and Nexoro.Jobs.unemployed.grades[0].label, 'Jobseeker', 'default job loaded from database')
H.addPlayerStub(1, 'Alice', { 'license:aaaa1111', 'steam:1100001', 'ip:203.0.113.9', 'discord:123' })
H.addPlayerStub(2, 'Bob', { 'license:bbbb2222' })
H.addPlayerStub(3, 'Mallory', { 'license:cccc3333' })
local p1 = Nexoro.RegisterExistingPlayer(1)
local p2 = Nexoro.RegisterExistingPlayer(2)
local p3 = Nexoro.RegisterExistingPlayer(3)
H.check(p1 and p2 and p3, 'players registered')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_player_identifiers WHERE id_type = 'ip'"), 0, 'IP addresses are never stored')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_player_identifiers WHERE player_id = ?", { p1.playerId }), 3, 'other identifiers stored')
local again = Nexoro.RegisterExistingPlayer(1)
H.eq(again.playerId, p1.playerId, 'same licence maps to the same player row')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_players'), 3, 'no duplicate player rows')
Nexoro.Players[1] = p1

H.section('Core: permissions')
local P = Nexoro.Permissions
H.eq(P.Has(1, 'nexoro.admin.money'), true, 'the first player to join is made owner')
H.check(not P.Has(2, 'nexoro.admin.money'), 'later players have no staff permissions')
H.check(P.Has(0, 'nexoro.admin.money'), 'console always allowed')
H.check(P.SetRank(1, 'owner', 'test'), 'console can assign owner')
H.check(P.Has(1, 'nexoro.admin.economy') and P.Has(1, 'anything'), 'owner has everything')
H.check(P.SetRank(2, 'moderator', 'test'), 'assign moderator')
H.check(P.Has(2, 'nexoro.mod.kick'), 'moderator can kick')
H.check(not P.Has(2, 'nexoro.admin.money'), 'moderator cannot give money')
H.check(not P.Has(2, 'nexoro.admin.inventory'), 'moderator cannot edit inventories')
H.check(not P.Has(2, 'nexoro.admin.jobs'), 'moderator cannot change jobs')
H.check(not P.Has(2, 'nexoro.admin.resources'), 'moderator cannot restart resources')
H.check(not P.Has(2, 'nexoro.admin.staff'), 'moderator cannot manage staff')
H.check(not P.Has(2, 'nexoro.mod.temporaryban'), 'plain moderator has no temp-ban by default')
H.check(P.CanActOn(1, 2) and not P.CanActOn(2, 1), 'staff hierarchy: owner > moderator, not reverse')
H.check(not P.CanActOn(2, 2), 'staff cannot act on equal rank')
H.check(P.CanActOn(2, 3), 'moderator can act on non-staff')
H.check(not P.SetRank(3, 'god_mode'), 'unknown rank rejected')
P.SetRank(2, nil, 'test')
H.check(not P.Has(2, 'nexoro.mod.kick'), 'removing rank removes permissions')
P.SetRank(2, 'moderator', 'test')

H.section('Core: jobs')
H.check(Nexoro.RegisterJob({ name = 'taxi', label = 'Taxi Driver', category = 'civilian', grades = { [0] = { label = 'Driver', salary = 12.50 }, [1] = { label = 'Manager', salary = 18.00 } } }), 'RegisterJob creates a job')
H.check(not Nexoro.RegisterJob({ name = 'DROP TABLE;', label = 'x', grades = { [0] = { label = 'a' } } }), 'RegisterJob rejects bad names')
H.check(not Nexoro.RegisterJob({ name = 'neg', label = 'x', grades = { [0] = { label = 'a', salary = -5 } } }), 'RegisterJob rejects negative salary')
H.eq(Nexoro.Jobs.taxi.grades[1].salaryPence, 1800, 'salary stored in pence')

H.section('Character flow through real callbacks')
H.events.net['nexoro:server:callback'] = H.events.net['nexoro:server:callback']
-- register the character resource callbacks against the real core
H.registry.nexoro_core = H.registry.nexoro_core or {}
H.registry.nexoro_identity = H.registry.nexoro_identity or {}
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end

local function identity(first) return { firstName = first, lastName = 'Smith', dob = '1990-05-20', gender = 'male', nationality = 'Scottish', height = 178, biography = '' } end
local appearance = Appearance.Default('mp_m_freemode_01')
local _, defApp = Appearance.Default('mp_m_freemode_01')

local r1, d1 = H.callServer(1, 'nexoro_character:list')
H.check(r1 == true and #d1.characters == 0 and d1.slots == 3, 'list: empty with 3 slots')
local rc, dc = H.callServer(1, 'nexoro_character:create', { identity = identity('Alice'), appearance = defApp })
H.check(rc == true and dc.id, 'create: first character', dc)
local rbad, ebad = H.callServer(1, 'nexoro_character:create', { identity = { firstName = 'X' }, appearance = defApp })
H.check(rbad == false and type(ebad) == 'table' and ebad.field, 'create: invalid form returns field error')
local rbadapp = H.callServer(1, 'nexoro_character:create', { identity = identity('Alice'), appearance = { model = 'a_c_cat_01' } })
H.check(rbadapp == false, 'create: invalid appearance rejected')
H.advance(61000) -- let the create rate limit window pass
H.check(H.callServer(1, 'nexoro_character:create', { identity = identity('Beth'), appearance = defApp }), 'create: second character')
H.check(H.callServer(1, 'nexoro_character:create', { identity = identity('Cara'), appearance = defApp }), 'create: third character')
local r4, e4 = H.callServer(1, 'nexoro_character:create', { identity = identity('Dana'), appearance = defApp })
H.check(r4 == false and e4 == 'no_free_slot', 'create: fourth character blocked by slot limit', e4)
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters WHERE player_id = ?', { p1.playerId }), 3, 'exactly 3 rows stored')
local cashStored = H.DB.scalar('SELECT cash_pence FROM nexoro_characters WHERE id = ?', { dc.id })
H.eq(cashStored, 25000, 'starting cash is £250.00 stored as pence')
local _, listing = H.callServer(1, 'nexoro_character:list')
H.eq(#listing.characters, 3, 'list: shows 3 characters')
H.eq(listing.characters[1].dob, '20/05/1990', 'list: DOB displayed as DD/MM/YYYY')
H.check(listing.characters[1].appearance and listing.characters[1].appearance.model == 'mp_m_freemode_01', 'list: appearance included')

-- ownership: Bob must not touch Alice's character
local rs, es = H.callServer(2, 'nexoro_character:select', { id = dc.id })
H.check(rs == false and es == 'not_found', 'select: cannot load another player\'s character', es)
local rd, ed = H.callServer(2, 'nexoro_character:delete', { id = dc.id, citizenId = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { dc.id }) })
H.check(rd == false and ed == 'not_found', 'delete: cannot delete another player\'s character', ed)
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters WHERE id = ?', { dc.id }), 1, 'victim character still exists')

local rsel, sel = H.callServer(1, 'nexoro_character:select', { id = dc.id })
H.check(rsel == true and sel.spawn and sel.appearance, 'select: own character loads')
H.eq(Nexoro.GetJob(1).name, 'unemployed', 'loaded character has default job')
H.eq(Nexoro.GetPlayerMoney(1, 'cash'), 250.0, 'cash is £250.00')
H.eq(Nexoro.GetPlayerMoney(1, 'bank'), 1500.0, 'bank is £1,500.00')
local rs2, es2 = H.callServer(1, 'nexoro_character:select', { id = dc.id })
H.check(rs2 == false, 'select: cannot load a second character while one is loaded', es2)
local rl, el = H.callServer(1, 'nexoro_character:list')
H.check(rl == false and el == 'already_loaded', 'list: blocked while in game', el)

H.section('Money safety (real database, atomic updates)')
local function bal() return H.DB.single('SELECT cash_pence, bank_pence FROM nexoro_characters WHERE id = ?', { dc.id }) end
H.check(Nexoro.AddMoney(1, 100, 'cash'), 'AddMoney £100')
H.eq(bal().cash_pence, 35000, 'database matches (£350.00)')
H.check(Nexoro.RemoveMoney(1, 50.25, 'cash'), 'RemoveMoney £50.25')
H.eq(bal().cash_pence, 29975, 'database matches (£299.75)')
local rm, why = Nexoro.RemoveMoney(1, 1000, 'cash')
H.check(rm == false and why == 'insufficient_funds', 'cannot spend more than you have', why)
H.eq(bal().cash_pence, 29975, 'balance unchanged after failed spend')
for _, amount in ipairs({ -5, 0, 0 / 0, math.huge, '10', 1.005, nil, {} }) do
    local o = Nexoro.AddMoney(1, amount, 'cash')
    H.check(o == false, 'AddMoney rejects ' .. tostring(amount))
end
H.check(not Nexoro.AddMoney(1, 10, 'cash_pence; DROP TABLE nexoro_characters'), 'account name cannot inject SQL')
H.check(not Nexoro.AddMoney(1, 10, 'savings'), 'unknown account rejected')
H.check(not Nexoro.AddMoney(1, 2000000, 'cash'), 'single transaction limit enforced')
H.check(not Nexoro.AddMoney(99, 10, 'cash'), 'no player, no money')
H.eq(bal().cash_pence, 29975, 'balance still correct after all abuse attempts')
local capOk = Nexoro.AddMoney(1, 1000000, 'bank')
for _ = 1, 999 do Nexoro.AddMoney(1, 1000000, 'bank') end
local overOk, overWhy = Nexoro.AddMoney(1, 1000000, 'bank')
H.check(overOk == false and overWhy == 'balance_limit', 'balance cap prevents overflow', overWhy)
H.check(bal().bank_pence <= 100000000000, 'bank never exceeds cap')
H.eq(Nexoro.GetPlayerMoney(1, 'bank'), bal().bank_pence / 100, 'cache equals database')
-- exploit-style: rapid concurrent-looking removes can never go negative
local spent = 0
for _ = 1, 50 do if Nexoro.RemoveMoney(1, 100, 'cash') then spent = spent + 1 end end
H.check(bal().cash_pence >= 0 and spent == 2, 'repeated spending stops at zero (spent ' .. spent .. ' x £100)', bal().cash_pence)

H.section('Jobs on a loaded character')
H.check(Nexoro.SetJob(1, 'taxi', 1), 'SetJob taxi grade 1')
H.eq(Nexoro.GetJob(1).gradeLabel, 'Manager', 'job grade label correct')
H.eq(Nexoro.GetJob(1).salary, 18.0, 'salary reported in pounds')
H.check(not Nexoro.SetJob(1, 'taxi', 9), 'unknown grade rejected')
H.check(not Nexoro.SetJob(1, 'made_up', 0), 'unknown job rejected')
H.eq(H.DB.scalar('SELECT job FROM nexoro_characters WHERE id = ?', { dc.id }), 'taxi', 'job persisted')
H.check(Nexoro.SetMetadata(1, 'hunger', 80), 'metadata saved')
H.eq(Nexoro.GetMetadata(1, 'hunger'), 80, 'metadata readable')
H.check(not Nexoro.SetMetadata(1, 'bad key!', 1), 'metadata key validated')

H.section('Appearance and outfits')
H.check(H.callServer(1, 'nexoro_character:saveAppearance', { appearance = defApp }), 'save appearance')
local ro = H.callServer(1, 'nexoro_character:saveOutfit', { name = 'Work clothes', appearance = defApp })
H.check(ro == true, 'save outfit')
local rdup, edup = H.callServer(1, 'nexoro_character:saveOutfit', { name = 'Work clothes', appearance = defApp })
H.check(rdup == false and edup == 'name_taken', 'duplicate outfit name rejected', edup)
local rinv = H.callServer(1, 'nexoro_character:saveOutfit', { name = '<b>x</b>', appearance = defApp })
H.check(rinv == false, 'outfit name with markup rejected')
for i = 1, 25 do
    if i % 6 == 0 then H.advance(61000) end
    H.callServer(1, 'nexoro_character:saveOutfit', { name = 'Outfit ' .. i, appearance = defApp })
end
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_character_outfits WHERE character_id = ?', { dc.id }), 20, 'outfit limit of 20 enforced')

H.section('Disconnect, save and recovery')
H.fireHandlers(1, 'playerDropped', 'Exited')
H.check(Nexoro.Players[1] == nil, 'player removed on disconnect')
H.check(H.DB.scalar('SELECT active_character_id FROM nexoro_players WHERE id = ?', { p1.playerId }) == nil, 'active character cleared on disconnect')
H.eq(H.DB.scalar('SELECT cash_pence FROM nexoro_characters WHERE id = ?', { dc.id }), 9975, 'money persisted after disconnect (£99.75)')
-- rejoin and load again
H.addPlayerStub(7, 'Alice', { 'license:aaaa1111' })
Nexoro.RegisterExistingPlayer(7)
local rr = H.callServer(7, 'nexoro_character:select', { id = dc.id })
H.check(rr == true, 'character loads again after rejoin')
H.eq(Nexoro.GetJob(7).name, 'taxi', 'job persisted across sessions')
H.eq(Nexoro.GetMetadata(7, 'hunger'), 80, 'metadata persisted across sessions')
-- core restart recovery: player 7 has an active character; wipe memory then recover
Nexoro.Players[7] = nil
Nexoro.RecoverPlayer(7)
H.check(Nexoro.Players[7] and Nexoro.Players[7].character and Nexoro.Players[7].character.id == dc.id, 'core restart: active character restored')

H.section('Deleting characters')
H.fireHandlers(7, 'playerDropped', 'Exited')
H.addPlayerStub(8, 'Alice', { 'license:aaaa1111' })
Nexoro.RegisterExistingPlayer(8)
local cid = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { dc.id })
local rw, ew = H.callServer(8, 'nexoro_character:delete', { id = dc.id, citizenId = 'NXWRONG1' })
H.check(rw == false and ew == 'confirmation_mismatch', 'delete needs the correct citizen ID', ew)
local rdel, ddel = H.callServer(8, 'nexoro_character:delete', { id = dc.id, citizenId = cid })
H.check(rdel == true and #ddel.characters == 2, 'delete with confirmation works')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_character_appearance WHERE character_id = ?', { dc.id }), 0, 'appearance deleted with character (cascade)')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_character_outfits WHERE character_id = ?', { dc.id }), 0, 'outfits deleted with character (cascade)')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_player_metadata WHERE character_id = ?', { dc.id }), 0, 'metadata deleted with character (cascade)')
local rslot = H.callServer(8, 'nexoro_character:create', { identity = identity('Erin'), appearance = defApp })
H.check(rslot == true, 'freed slot can be reused')

H.section('Rate limiting and abuse handling')
local limited = 0
for _ = 1, 60 do
    local r, e = H.callServer(3, 'nexoro_character:list')
    if e == 'rate_limited' then limited = limited + 1 end
end
H.check(limited > 0, 'callback spam is rate limited (' .. limited .. ' blocked)')
H.check(#H.dropped > 0 and H.dropped[#H.dropped][1] == 3, 'persistent spammer is kicked')
local ru = H.callServer(2, 'nexoro_character:nonexistent')
H.check(ru == false, 'unknown callback names are rejected')
H.fireNet(2, 'nexoro:server:callback', { 'not', 'a', 'string' }, 'bad')
H.check(true, 'malformed callback payload does not crash')
local rperm = H.callServer(2, 'nexoro_character:getAppearance')
H.check(rperm == false, 'character-only callbacks refuse players without a character')

H.section('Audit logging')
Nexoro.FlushLogs()
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE category = 'economy'") or 0) >= 4, 'economy actions logged to database')
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE category = 'character' AND action = 'created'") or 0) >= 3, 'character creation logged')
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE category = 'permissions'") or 0) >= 2, 'permission changes logged')
H.check((H.DB.scalar("SELECT COUNT(*) FROM nexoro_logs WHERE category = 'security'") or 0) >= 1, 'security violations logged')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
