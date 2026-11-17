package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = { nexoro_vehicles = 'started' }
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nexoro = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local invEnv = env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
local emEnv = env('nexoro_emergency', { 'config.lua', 'server/main.lua' })
local diEnv = env('nexoro_dispatch', { 'config.lua', 'server/main.lua' })
local chatEnv = env('nexoro_chat', { 'config.lua', 'server/main.lua' })
local veEnv = env('nexoro_vehicles', { 'config.lua', 'server/main.lua' })
local deEnv = env('nexoro_dealerships', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)

-- ---------------------------------------------------------------- owner recovery
H.section('Owner: first join, convar and claim code')
Nexoro.LoadJobs()
H.addPlayerStub(1, 'Sam', { 'license:sam' })
local p1 = Nexoro.RegisterExistingPlayer(1)
H.eq(p1.staffRank, 'owner', 'the first account to join is owner')
H.convars['nexoro_owner_license'] = 'license:conv'
H.addPlayerStub(6, 'Convar', { 'license:conv' })
local p6 = Nexoro.RegisterExistingPlayer(6)
H.eq(p6.staffRank, 'owner', 'the account named in nexoro_owner_license is owner even when another owner exists')
H.addPlayerStub(7, 'Stranger', { 'license:stranger' })
local p7 = Nexoro.RegisterExistingPlayer(7)
H.check(p7.staffRank == nil, 'other accounts are not owners')
H.convars['nexoro_owner_license'] = nil
Nexoro.InitClaimCode()
H.check(Nexoro.ClaimCode == nil, 'no claim code is shown while an owner exists')
H.DB.update('DELETE FROM nexoro_staff_assignments')
Nexoro.InitClaimCode()
H.check(type(Nexoro.ClaimCode) == 'string' and #Nexoro.ClaimCode == 6, 'with no owner, a six digit claim code is created')
local code = Nexoro.ClaimCode
H.eq(select(2, Nexoro.ClaimOwner(7, '000000')), 'wrong_code', 'a wrong code does not make you owner')
H.check(Nexoro.ClaimOwner(7, code) == true, 'the right code makes you owner')
H.eq(Nexoro.Players[7].staffRank, 'owner', 'the claimant is now owner')
H.eq(select(2, Nexoro.ClaimOwner(7, code)), 'no_claim_code', 'the code can only be used once')
H.check(Nexoro.Permissions.Has(7, 'nexoro.admin.economy'), 'the claimed owner has admin permissions')

-- ---------------------------------------------------------------- characters for the rest
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local Core = H.registry.nexoro_core.GetCore()
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Dispatch = H.registry.nexoro_dispatch
local Chat = H.registry.nexoro_chat
local Inv = H.registry.nexoro_inventory

join(1, 'license:sam', 'Sam', 'Walker')
join(2, 'license:sue', 'Sue', 'Hale')
join(3, 'license:pat', 'Pat', 'Moore')
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
Core.SetJob(1, 'caledonia_police', 0)
Core.SetJob(2, 'caledonia_police', 1)
Core.SetJob(3, 'metro_ambulance', 1)
for _, s in ipairs({ 1, 2, 3 }) do
    H.check(call(s, 'nexoro_emergency:toggleDuty') == true, 'on duty: ' .. s)
    H.fireHandlers(s, 'nexoro:server:dutyChanged', s, true)
end
call(1, 'nexoro_emergency:setCallsign', { callsign = 12 })

-- ---------------------------------------------------------------- radio chatter
H.section('Radio chatter')
H.check(Dispatch.RadioJoin(1, 101) == true, 'Sam tunes to the police channel')
H.check(Dispatch.RadioJoin(2, 900) == true, 'Sue tunes to dispatch (she can operate)')
H.check(Dispatch.RadioJoin(3, 102) == true, 'Pat tunes to the ambulance channel')
Inv.AddItem(4, 'radio', 1)
H.check(Dispatch.RadioJoin(4, 5) == true, 'Cara tunes to public channel 5 with a radio')
H.eq(select(2, Dispatch.RadioJoin(5, 101)), 'not_on_duty_service', 'Olly is not police, so cannot use the police channel')
H.eq(select(2, Dispatch.RadioJoin(5, 5)), 'no_radio', 'public channels need a radio')
H.sent = {}
H.advance(3000)
H.check(Chat.Send(1, 'radio', 'Attending the high street'), 'Sam sends a radio message')
local function heardBy(list) local out = {} for _, e in ipairs(H.sent) do if e.name == 'nexoro_chat:message' then out[e.target] = e.args[1] end end return out end
local heard = heardBy()
H.check(heard[1] and heard[1].channel == 'radio', 'Sam hears his own radio message')
H.check(heard[3] == nil and heard[4] == nil, 'Pat (ambulance) and Cara (public channel) do not hear police radio')
H.eq(select(2, Chat.Send(5, 'radio', 'Hello?')), 'not_on_radio', 'someone not tuned to any channel cannot transmit')
H.advance(3000)
H.sent = {}
Chat.Send(3, 'radio', 'Ambulance clear')
heard = heardBy()
H.check(heard[3] and heard[1] == nil, 'ambulance radio is heard only on the ambulance channel')
H.advance(3000); H.sent = {}
Chat.RadioBroadcast(101, 'Dispatch test: all units standby')
heard = heardBy()
H.check(heard[1] and heard[1].prefix.label == 'DISPATCH', 'dispatch messages are labelled DISPATCH on the channel')
H.check(heard[3] == nil and heard[4] == nil, 'dispatch on one channel does not reach other channels')
-- automatic chatter from an assignment
local rOpen, opened = call(2, 'nexoro_dispatch:open', { kind = 'police', priority = 2, description = 'Disturbance outside the bank' })
H.check(rOpen == true and opened.id, 'Sue raises an incident')
H.advance(3000); H.sent = {}
local rAs = call(2, 'nexoro_dispatch:assign', { id = opened.id, unit = 1 })
H.check(rAs == true, 'Sue assigns Sam')
heard = heardBy()
H.check(heard[1] and heard[1].prefix.label == 'DISPATCH' and heard[1].text:find('attend incident') ~= nil, 'assignment is called out over the police radio')
H.check(heard[3] == nil, 'the ambulance channel does not hear police assignments')

-- ---------------------------------------------------------------- car wash and vehicles
H.section('Car wash and dirt')
local plate = veEnv.NexoroVehicles.Register(cidCara, 'panto', { price = 6500, garage = 'legion_garage' })
H.check(plate ~= nil, 'a vehicle is registered for Cara')
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate })
local vpos = {}
veEnv.NexoroVehicles.getCoords = function(s) return vpos[s] end
local wash = veEnv.Config.Vehicles.CarWashes[1]
vpos[4] = { x = wash.x, y = wash.y, z = wash.z }
local bank0 = Core.GetPlayerMoney(4, 'bank')
local rw, cost = call(4, 'nexoro_vehicles:wash', { plate = plate })
H.check(rw == true and cost.cost == '£15.00', 'washing costs £15.00 at the car wash')
H.eq(bank0 - Core.GetPlayerMoney(4, 'bank'), 15.0, 'exactly £15.00 is taken from the bank')
vpos[4] = { x = 0, y = 0, z = 0 }
H.eq(select(2, call(4, 'nexoro_vehicles:wash', { plate = plate })), 'not_at_wash', 'a vehicle away from a wash cannot be washed')
vpos[4] = { x = wash.x, y = wash.y, z = wash.z }
H.DB.update("UPDATE nexoro_vehicles SET status = 'stored' WHERE plate = ?", { plate })
H.eq(select(2, call(4, 'nexoro_vehicles:wash', { plate = plate })), 'not_out', 'only a vehicle that is out can be washed')
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate })
vpos[5] = { x = wash.x, y = wash.y, z = wash.z }
H.eq(select(2, call(5, 'nexoro_vehicles:wash', { plate = plate })), 'no_access', 'someone without a key cannot wash it')
Core.RemoveMoney(4, Core.GetPlayerMoney(4, 'bank'), 'bank', 'drain')
H.eq(select(2, call(4, 'nexoro_vehicles:wash', { plate = plate })), 'insufficient_funds', 'no money, no wash')
H.check(veEnv.Config.Vehicles.DirtRate > 0 and veEnv.Config.Vehicles.PunctureChance > 0 and veEnv.Config.Vehicles.PunctureChance <= 1, 'dirt and puncture settings are sensible')

-- ---------------------------------------------------------------- dealership radius
H.section('Dealership radius')
H.eq(deEnv.Config.Dealerships.premium_deluxe.radius, 4.5, 'the showroom opens within 4.5 metres')
local dpos = {}
deEnv.NexoroDealerships.getCoords = function(s) return dpos[s] end
local dl = deEnv.Config.Dealerships.premium_deluxe
dpos[5] = { x = dl.x - 8.0, y = dl.y, z = dl.z }
H.eq(select(2, call(5, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' })), 'too_far', 'eight metres away is too far to shop')
dpos[5] = { x = dl.x - 5.0, y = dl.y, z = dl.z }
H.check(call(5, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' }), 'five metres away (edge of the forecourt) still works')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
