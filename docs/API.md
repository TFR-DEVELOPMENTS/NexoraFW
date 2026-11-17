# Nexoro Core API (Phase 1)

Server-side. Money amounts are pounds with at most 2 decimals; stored as integer pence.

```lua
local Core = exports.nexoro_core:GetCore()
-- or call any function directly: exports.nexoro_core:AddMoney(src, 50, 'cash', 'reason')
```

| Function | Returns |
|---|---|
| GetPlayer(source) | snapshot table (copy) or nil |
| GetPlayerByIdentifier('license:...') | snapshot or nil |
| GetCharacter(source) | copy of the loaded character or nil |
| GetPlayerMoney(source, 'cash'\|'bank') | pounds or nil |
| AddMoney(source, amount, account, reason) | true, newBalance / false, errorCode |
| RemoveMoney(source, amount, account, reason) | true, newBalance / false, 'insufficient_funds' |
| GetJob(source) | {name,label,category,grade,gradeLabel,salary,onDuty} |
| SetJob(source, job, grade) | true / false, 'unknown_job' \| 'unknown_grade' |
| SetDuty(source, bool) | true/false |
| SetMetadata / GetMetadata(source, key[, value]) | persisted per character |
| SavePlayer(source) | true |
| Notify(source, message, type, durationMs) | types: success error warning info emergency job banking inventory staff |
| GetInventory / AddItem / RemoveItem | forwarded to nexoro_inventory (Phase 2), else nil, 'inventory_unavailable' |
| RegisterJob(def) | create or update a job and grades in the database |
| HasPermission(source, 'nexoro.admin.money') | bool (console = true) |
| CanActOn(actor, target) | bool: only strictly higher staff level |
| SetStaffRank(source, rank\|nil, by) | server-side only |
| RegisterCallback(name, handler, opts) | handler(source, ...) returns ok, dataOrError |
| RegisterConnectHook(fn) | fn(source, identifiers, name) returns allowed, reason |
| Log(category, action, source, data) | batched to nexoro_logs |
| RateLimit(source, key, max, windowMs) | bool |

Error codes: no_character, invalid_account, invalid_amount, amount_too_large, insufficient_funds, balance_limit, database_error.

## Server events (local, trusted)
nexoro:core:ready, nexoro:server:playerReady(src), nexoro:server:characterLoaded(src, character), nexoro:server:characterSpawned(src), nexoro:server:characterUnloaded(src, characterId, reason), nexoro:server:characterDeleted(src, characterId, citizenId), nexoro:server:jobChanged(src, job, previousJobName), nexoro:server:dutyChanged(src, onDuty), nexoro:server:playerDropped(src, reason), nexoro:database:ready.

## Client
`exports.nexoro_core:GetCharacterData()`, `IsCharacterLoaded()`, `RegisterKeybind(name, description, key, onPress, onRelease)`.
Callbacks from NUI/client: include `'@nexoro_core/lib/client.lua'`, then `local ok, data = NexoroCore.Callback('name', ...)`.
Local client events: nexoro:client:characterLoadedLocal, characterUnloadedLocal, jobUpdatedLocal, moneyUpdatedLocal.

## Rules for third-party scripts
Never trust values sent by clients. Use `RegisterCallback` with `requireCharacter` / `permission` opts, or `Nexoro.RegisterSecureEvent`. State bags (`nexoro:name`, `nexoro:job`) are display-only.

## Permissions
Ranks live in `nexoro_core/config/staff.lua`; patterns support exact, `prefix.*`, `*`. ACE fallback: `add_ace group.x nexoro.admin.money allow`.

## Database
Tables: nexoro_players, nexoro_player_identifiers, nexoro_characters, nexoro_character_appearance, nexoro_character_outfits, nexoro_player_metadata, nexoro_jobs, nexoro_job_grades, nexoro_staff_assignments, nexoro_logs, nexoro_schema_migrations. Each resource may add `sql/migrations.json` (ordered file list) and `sql/migrations/*.sql` (statements separated by a `-- @@` line).


# Phase 2 additions

## nexoro_banking (server exports)
`Deposit(src, amount)`, `Withdraw(src, amount)`, `Transfer(src, citizenId, amount, note)`, `PaySalary(src)`, `GetAccount(src)`. Each returns `true, account` or `false, errorCode` (insufficient_funds, invalid_amount, cannot_pay_yourself, recipient_not_found, balance_limit...). All moves are single atomic SQL statements. Callbacks: nexoro_banking:account / deposit / withdraw / transfer / statement.

## nexoro_inventory (server exports)
`GetInventory(src)`, `AddItem(src, item, amount, metadata)`, `RemoveItem(src, item, amount)`, `HasItem`, `GetItemCount`, `MoveItem(src, from, to, amount)`, `UseItem(src, slot)`, `ClearInventory(src)`, `RegisterItem(def)`, `RegisterUsableItem(name, fn)`, `AddItemToStash(type, id, item, amount, metadata, {slots, maxWeight})`, `RemoveItemFromStash`, `GetStash`.
Items: `nexoro_inventory/items.lua` (weight in grams; `onUse(src, Core, entry)`; return false to cancel). Errors: unknown_item, invalid_amount, too_heavy, no_space, not_enough, not_usable, database_error. Every change is planned on a copy, saved in one transaction, then applied to memory.

## nexoro_chat (server exports)
`Send(src, channel, text, target)`, `Announce(text)`, `System(src, text)`, `Mute(src, seconds)`, `Unmute(src)`, `IsMuted(src)`, `GetPrefix(src)`. Prefixes are chosen by the server from the job record (config: `Config.Chat.Prefixes`). Client event `chat:addMessage` is supported for old scripts. Remove the default `chat` resource.

## nexoro_admin
`exports.nexoro_admin:Execute(src, action, payload)` runs any menu action through the same pipeline the menu and chat commands use: permission, hierarchy (`CanActOn`), confirmation for sensitive actions, required reasons, audit log row with previous/new values. Add your own actions by extending `NexoroAdmin.actions` (see `server/main.lua`).
Permissions used: nexoro.admin.{dashboard,players,teleport,money,inventory,jobs,vehicles,resources,staff,economy,bans,world,self}, nexoro.mod.{kick,warnings,freeze,spectate,temporaryban}, nexoro.staff.{chat,duty,logs}.
Tables: nexoro_bans, nexoro_ban_identifiers, nexoro_warnings, nexoro_admin_logs, nexoro_transactions, nexoro_inventories, nexoro_inventory_items.
Chat commands (same pipeline): /goto /bring /freeze /unfreeze /spectate /kick /warn /ban /unban /staffduty /staffchat.


# Phase 3 additions

## nexoro_ui (client)
Include `'@nexoro_ui/lib/client.lua'` in your manifest, then (inside a thread or event handler):
```lua
local done   = NexoroUI.Progress({ label = 'Repairing', duration = 5000, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' } })
local values = NexoroUI.Input({ title = 'Pay fine', fields = { { type = 'number', name = 'amount', label = 'Amount', required = true } } })   -- nil if cancelled
local yes    = NexoroUI.Confirm({ title = 'Sure?', text = 'This cannot be undone.', danger = true })
NexoroUI.Alert({ title = 'Info', text = '...' })
NexoroUI.RegisterContext({ id = 'my_menu', title = 'My menu', menu = 'parent_id', options = { { title = 'Do it', icon = '!', onSelect = function() end } } })
NexoroUI.ShowContext('my_menu'); NexoroUI.ShowTextUI('Open shop', 'E'); NexoroUI.HideTextUI()
```
Field types: input, number, select, checkbox, textarea. Context options accept `onSelect`, `event` (client event), `serverEvent`, `menu` (submenu), `description`, `icon`, `disabled`, `metadata`, `progress`.

## nexoro_phone (server exports)
`GetNumber(src)`, `GetSourceByNumber(number)`, `ChargePhone(src, amount)`, `SendMessage(src, to, body)`. Emergency calls (999/101/111) trigger the server event `nexoro:server:emergencyCall(src, number, kind)`; the dispatch resource listens to it. Config: `nexoro_phone/config.lua`.

## nexoro_hud (server exports)
`GetNeeds(src)`, `AddStress(src, amount)`, `SetNeed(src, 'hunger'|'thirst'|'stress', value)`. Needs are character metadata, so items that call `SetMetadata` update the HUD automatically (event `nexoro:server:metadataChanged`).

## Core additions
`GetJobs()` returns jobs with grades. `SetMetadata` fires `nexoro:server:metadataChanged(src, key, value)`.


# Phase 4 additions

## nexoro_vehicles (server exports)
`Register(characterId, model, {price, garage, finance})` returns plate, id. `Get(plate)`, `LookupPlate(plate)` (keeper, insurance, MOT, status), `Search(term)`, `HasAccess(src, plate)`, `Spawn` / `Store` (used by garages), `Impound(src, plate, reason, feePounds)` (police on duty or staff), `ReleaseImpound`, `SellToDealer`, `FinanceTerms(price, deposit)`, `BuybackPrice(plate)`, `AdminTransfer / AdminRepair / AdminDelete / AdminRelease`, `ListFor(src)`.
Client: `exports.nexoro_vehicles:SpawnOwnedVehicle(data, pos, cb)`, `GetVehicleState(veh)`, `ForgetVehicle(plate)`, `OpenMyVehicles()`.
Statuses: stored, out, impounded, wrecked, repossessed, scrapped, sold. Config: `nexoro_vehicles/config.lua` (plans, fees, finance terms, pumps, MOT stations). Garages: `nexoro_garages/config.lua`. Dealerships and prices: `nexoro_dealerships/config.lua` (clients never send prices).
Data model: nexoro_vehicles, nexoro_vehicle_keys, nexoro_vehicle_history.


# Phase 5 additions

## nexoro_emergency (server exports)
`HasPerm(src, perm, allowOffDuty)`: the one permission check every emergency module uses. Departments are jobs; permissions come from the job grade (`nexoro_emergency/config.lua`). `Department(job)`, `Status(src)`, `ToggleDuty(src)`, `SetCallsign(src, n)`.
Core addition: `GetGradePermissions(job, grade)`.

## nexoro_police (server exports)
`Cuff`, `Uncuff`, `Fine(src, target, pounds, reason)` (returns status paid or outstanding), `Warrant(src, citizenId, reason)`, `Mdt(src, citizenId)`.
Cuffed and arrested state lives in character metadata (`cuffed`, `arrested`). The client receives `nexoro_police:cuffs`.

## nexoro_ambulance (server exports)
`Revive`, `Admit`, `Discharge`. Revive sends `nexoro_ambulance:revive` to the patient. Medical records: nexoro_medical_records.

## nexoro_fire (server exports)
`Create(src, kind, notes)`, `CreateHazard(src, radius, minutes)`, `ListHazards()`. Hazard lists are sent to clients as `nexoro_fire:hazards`.

Data model: nexoro_police_records, nexoro_police_evidence, nexoro_medical_records, nexoro_fire_incidents.


# Phase 6 additions

## nexoro_dispatch (server exports)
`Open(src, kind, priority, description)`, `Assign(src, incidentId, unitSrc)`, `SetStatus(src, status)`, `RadioJoin(src, channel)`, `GetRadioChannel(src)`, `OnCall(src, number)`, `IsUnit(src)`.
Event in: `nexoro:server:emergencyCall(src, number, kind)` from the phone. Events out to clients: `nexoro_dispatch:alert`, `nexoro_dispatch:waypoint`.
Statuses: available, en_route, on_scene, transporting, unavailable. Services: police, ambulance, fire. Incident kinds: emergency, police, medical, fire.

## nexoro_tablet (server exports)
`Apps(src)` lists the apps a player may open. `Relay(src, app, call, payload)` runs a callback on the tablet's behalf after the app allowlist and the callback's own checks. Core: `exports.nexoro_core:InvokeCallback` (used by the relay; keeps requireCharacter and permission checks; rate limiting is the caller's job).
The screen forms, app allowlists and item name are in `nexoro_tablet/config.lua`.

## nexoro_lighting (server exports)
`Set(src, vehicleNetId, preset)` (preset `off` clears), `Siren(src, vehicleNetId, on)`, `States()`.
Presets and light positions: `nexoro_lighting/config.lua`. Client event: `nexoro_lighting:states` (array of { net, preset, siren }).

Data model: nexoro_dispatch_incidents, nexoro_dispatch_assignments.
