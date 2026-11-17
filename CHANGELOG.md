# Changelog

## v1.0.0-beta build, progress (markets, civilian jobs, night traffic)
- `nexoro_markets`: illegal street contacts. A drugs contact buys narcotics packets at 60% of £250 each, with a £3,000 daily cap and a 25% chance each deal is reported. A weapons dealer sells unregistered pistols for £1,500 and buys them back at 60%, with a 40% alarm chance.
- `nexoro_civilian`: eight civilian jobs taken at the job centre (bus driver, mechanic, cleaner, builder, cashier, gardener, courier, lifeguard). Go on duty, do the tasks at each job's points for pay into the bank, with a cooldown per point. Taking a new job replaces the old one. Pay and points are placeholders to tune.
- Night traffic: from 22:00 to 06:00 in-game, traffic and pedestrian density drop. This is the substitute for traffic-light control, which GTA does not let scripts change.
- 20 suites, 1,680 checks, all passing. Static check passing.

## v1.0.0-beta build, progress (crime)
## v1.0.0-beta build, progress (crime)
- `nexoro_crime`: vehicle theft (street cars belonging to someone else; a lockpick is used either way; 60% success; 30 minute cooldown per car; each theft is recorded, and a constable on duty can recover the car). House robbery (only when the owner is away; takes up to three stacks from the property stash; 2 hour cooldown per house). Back-room fence (buys stolen goods at 40% of pawn price, £1,500 daily cap per character, 15% chance a sale is reported; sells lockpicks for £150).
- Every crime raises an alarm to dispatch, through the same path as robberies.
- The fence's daily cap is kept in memory and resets on restart. A restart mid-day gives a fresh cap. That's fine for v1 testing; it will move into the database before a release.
- 19 suites, 1,649 checks, all passing. Static check passing.

## v1.0.0-beta build, progress (MLO and licences)
## v1.0.0-beta build, progress (MLO and licences)
- Firearms licence (£500) at the council office. Refused to anyone with an arrest on record. Hunting and firearms licences are now on the office menu.
- Traveller site MLO: `nexoro_traveller_site` added as a scaffold. Its geometry (walls, gate) has to be exported from CodeWalker or Sollumz and placed in its stream folder. The resource starts empty and breaks nothing until then.
- Gate: the gate prop in the MLO is swung open or closed by the server's gate decision. Its model and headings are in the encampments config.
- 18 suites, 1,615 checks, all passing. Static check passing.

## v1.0.0-beta (the first full build, renamed Nexoro)
## v1.0.0-beta (the first full build, renamed Nexoro)
- Renamed to **Nexoro**, developed by **Nexoro Network Team**. All resources are now `nexoro_*`, the tables and events use `nexoro`, and the console prefix is `[Nexoro]`.
- Citizen IDs now start with `NX`. The format is unchanged: prefix plus six characters.
- Convars renamed: `nexoro_owner_license` and `nexoro_devmode`. Update existing server.cfg files. The recipe already writes the new names.
- Test servers: the database tables have new names, so start from an empty database. Tables from earlier test builds (old prefix) are not removed automatically.
- Build status: 52 resources, 17 test suites and the static check, 1,602 checks, all passing offline. Not yet tested on a live server with players.

## 1.17.0-beta (test server tools)
- `nexoro_devtools`: off unless `set nexoro_devmode "true"` is in server.cfg. For the owner only: `/devmoney`, `/devitem`, `/devtp`, `/devheal`, `/devjob`, `/devselfcheck`.
- `/devselfcheck` checks the database, the core tables, that an owner exists, and that every Nexoro resource started. Failures name the cause.
- `nexoro_dbreset <token>` (console only, dev mode only) drops every Nexoro table, so the next start rebuilds the database. The token is printed at each startup and works once.
- `docs/TEST_WORKFLOW.md`: the steps for re-uploading resources and refreshing the database between tests.
- 37 checks in run17. All seventeen suites and the integrity check pass: 1,602 checks.

## 1.16.1-beta (handling)
## 1.16.1-beta (handling)
- Stock vans corrected to the names in the realistic handling pack's list: Declasse Burrito (`burrito3`) and Bravado Rumpo (`rumpo`).
- Optional server resource line for Taira's Realistic Handling for Vanilla Vehicles (credit to Taira). Off by default. Not included in Nexoro.
- Client setup note recommends it over the game-file handling mod, since it is a server resource and nobody installs anything.


## 1.16.0-beta (vehicles for the trades; optional car pack)
- Dealership: three stock GTA commercial vehicles added (Bravado Burrito, Vapid Rumpo, Bravado Bison pickup). Spawn codes to be checked on your build.
- Optional cars: seven cars from SpiritsCreations' Lore-Friendly Car Pack are in the Premium Deluxe catalogue. They are listed and sellable only while the resource `Lore-Friendly-Car-Pack` is running. The pack is not included in Nexoro. Install it yourself into your server's resources. Prices are placeholders.
- Game build: the pack says some cars need `sv_enforceGameBuild 3258`. The template still pins 3095. Not changed.
- 179 checks in run4 (up from 177). All sixteen suites and the integrity check pass.

## 1.15.0-beta (encampments and scrap collecting)
## 1.15.0-beta (encampments and scrap collecting)
- Background: "Gypsy, Roma or Traveller" is a choice on the character creator. It has no effect on pitches, notices, warrants, gates or pay.
- Encampments: anyone can claim one empty pitch on open land (Sandy Shores and Grapeseed, placeholder coordinates) for £250. Pitches show on the map. The occupant can be served a notice to move on by any constable on duty, with 14 days to comply. A sergeant can issue a warrant only after that deadline, and it lasts 24 hours. The occupant can open and close their gate. Police on duty with a live warrant can too. Anyone can vacate a pitch.
- Scrap collector: a civilian job. Start a shift with `/scrap duty`, collect scrap at marked points on the map (2 to 4 pieces each), and each point rests for ten minutes. Sell scrap at the Builders Yard.
- Gate control and the gate's model are placeholders until the custom MLO is in.
- 36 checks in run16. All sixteen suites and the integrity check pass: 1,563 checks.

## 1.14.0-beta (crews and hunting)
## 1.14.0-beta (crews and hunting)
- Crews: player-made groups. Create one for £500 (name 3 to 24 characters, unique). The leader invites players (invites expire after 60 seconds), kicks members, or disbands. Members can leave. A player can be in one crew at a time, up to eight members. Other systems can ask `SameCrew` to check if two players are in the same crew.
- Hunting: a £40 hunting licence from the council office, then hunt at Paleto Woods (placeholder coordinates) for venison or pelts, with a 45 second cooldown. Nothing caught is a valid try.
- Recipe and server.cfg template now start 52 resources; the integrity check keeps them in step.
- 38 checks in run15. All fifteen suites and the integrity check pass: 1,527 checks.

## 1.13.0-beta (Legion Square supply drops)
## 1.13.0-beta (Legion Square supply drops)
- Supply drops at Legion Square at 18:00 and 21:00 on the in-game clock. Everyone is told five minutes ahead, with a waypoint and a notification. The crate appears on everyone's map.
- Only the team can open a crate: by default, on-duty members of the Caledonia Police job. Set `Team` to another job name, or to nil so anyone can open it.
- One player takes the loot. Loot is weighted: mostly cash (£500 to £1,500), with cash bags, repair kits, steel parts and lockpicks.
- An unclaimed crate is removed after 15 minutes.
- 26 checks in run14. All fourteen suites and the integrity check pass.

## 1.12.0-beta (Phase 8: entertainment and social, first part)
## 1.12.0-beta (Phase 8: entertainment and social, first part)
- Responsible gambling: one daily stake limit (£100, resets daily) shared by the lottery and scratchcards. Stakes are reserved before money is taken, and given back if the payment fails.
- National lottery: buy a ticket with six different numbers from 1 to 49 at the counter (£2 each, up to ten per person per draw). Weekly draw. Prizes: 60% of the pot for six numbers, 25% for five, 15% for four, split between winners. A tier with no winner rolls over to the next draw. Every pound in the pot is either paid or carried forward.
- Scratchcards: £5 a card, instant win, published prize table with about 97% return to player.
- Loading screen: `html/audio/music.mp3` added as an empty placeholder. Drop a real track in with the same name. An empty file may play silence or log an error on the loading screen, so check that when you test.
- 40 checks in run13. All thirteen suites and the integrity check pass.

Note: Phase 8's original plan was not in my notes, so this is my reading of "entertainment and social". Tell me if your Phase 8 list differs and I will rework it.

## 1.11.1-beta (integrity pass)
## 1.11.1-beta (integrity pass)
- Removed a stale duplicate resource (`nexoro_auction`) left over from an earlier draft. It created a `nexoro_auctions` table with a different schema, which could have won on a fresh install because the migration uses CREATE TABLE IF NOT EXISTS.
- Added `tests/integrity.py`, a static check across all 43 resources: missing files, missing dependencies, exports called but not defined, client callbacks with no server handler, and start order. It runs as part of `run_all.sh`. It is checked against planted faults so it is known to catch real mistakes.
- Static result: 0 problems across 43 resources and 97 callbacks.


## 1.11.0-beta (Phase 7: the rest of the civilian economy and crime)
- Public transport: bus route with stops. Tap on at a stop and off at another; the fare follows the road distance between the stops (minimum £1.50). You stay on the bus if you cannot pay.
- Pawn shop: sells radios, phones, repair kits, scrap and similar items for fixed pawn prices.
- Auction house: list an item (held in escrow until sold or claimed), bid with a minimum step, outbid bidders are refunded at once, and sales pay the seller less a 5% fee. Unsold items go back to the seller.
- Robberies: a corner store and an ATM. Each needs a lockpick (used up on success), has its own cooldown, and raises a police alarm that becomes an immediate incident in dispatch.
- Farming: plant wheat seed on two plots, come back after 10 minutes, harvest 2 to 4 wheat. Only the planter can harvest; a full inventory keeps the crop in the ground.
- 68 checks in run12. All twelve suites: 1,423 checks.

### Still not built
Hunting, house and vehicle theft, illegal markets, weapon licences, court hearings beyond paying fines, the bulk of the civilian jobs (taxi and postal exist; the rest are not built), and the premium features: custom minimap, night traffic lights, and realistic per-vehicle handling.

## 1.10.0-beta (Phase 7: civilian systems, continued)
## 1.10.0-beta (Phase 7: civilian systems, continued)
- Licences: driving licence with a five-question written test (answers stay on the server; pass mark 4; fee £60; licence card issued), and a fishing licence (£25). Bought at the council office.
- Businesses: register a business (£2,500, two per owner), a business bank account (deposit and withdraw), staff with hourly wages (up to £500/hour) paid automatically from the account. An empty account pays nobody. Owners can hire, dismiss, and staff can quit.
- Postal worker: a real civilian job. Go on duty, start a round of three GPS drops in a random order, and deliver by standing at the door and pressing E. Each drop pays £35; finishing the round pays a £60 bonus. Drops cannot be cleared within 15 seconds of the previous one.
- Fishing: needs a fishing licence and to be at a spot. Catches are rolled on the server from a weighted table, with a 20 second cooldown.
- Fixed while testing: the postal first drop was blocked by a pause that should only apply between drops.
- 70 checks in run11. All eleven suites: 1,355 checks.

### Still not built in Phase 7
Public transport (buses and trains), auctions, pawn shops, illegal markets, store, ATM and house robberies, vehicle theft, farming and hunting, weapon licences, and the government services that go with them.

## 1.9.0-beta (Phase 7: civilian systems)
## 1.9.0-beta (Phase 7: civilian systems)
- Prison: a police arrest with a sentence sends the player to a cell on the server clock (`nexoro:server:arrested`). Cuffs come off on the way in, sentences survive logging out, and release happens automatically when time is served. Sentences are capped at two weeks.
- Housing: estate agent with two sample properties. Buy from the bank, sell back at 60%, weekly bills taken from the bank with arrears, repossession after four missed weeks, shared keys (up to five), and property storage (deposit and withdraw).
- Taxi: a real civilian job (`taxi`). A driver on duty offers a fare to a nearby passenger, who must accept. The fare is measured on the server from the route, the passenger pays from their bank, and the driver keeps 80%. Trips finishing faster than 90 mph, trips with no movement, and passengers who are not in the car are refused.
- Shops, crafting and courts (from the previous update) now have tests. Fixed a bug: shop stock keys were missing their shop id, which would have failed every purchase.
- 116 checks in run10. All ten suites: 1,285 checks.

### Not built yet (still Phase 7)
Businesses, the remaining civilian jobs (only taxi exists so far), public transport, postal and delivery, licences (driving, weapon, fishing), pawn shops, auctions, fishing, farming and hunting, store robberies and illegal markets.

## 1.8.0-beta (admin recovery, radio, vehicles, civilian economy begins)
## 1.8.0-beta (admin recovery, radio, vehicles, civilian economy begins)
- Getting owner, in order of reliability: (1) the first account to join an empty server; (2) `set nexoro_owner_license "license:..."` in server.cfg; (3) if nobody is owner, a six-digit code is printed in the server console at start: type `/claimowner CODE` in game. Type `/mystaff` to see your rank. The staff menu now explains why it refused you.
- Dealerships: the showroom opens within 4.5 metres, on foot only (it no longer opens while driving past). Shops and the server-side checks are tightened to match.
- Loading screen: `loadscreen_cursor 'yes'` added so the mouse can move on the loading screen.
- Radio chatter: `/r` (or `/radio`) talks on the channel you are tuned to. Dispatch calls out assignments and status changes on the matching channel. Only that channel hears it.
- Car wash (£15), dirt builds up while driving and is cleaned at a wash, hard impacts can puncture a tyre, and a passed MOT repairs punctures.
- Civilian economy begins: `nexoro_shops` (buy and sell, stock that restocks over time), `nexoro_crafting` (workbench recipes, refunded if the result will not fit), `nexoro_courts` (see and pay outstanding fines, in person or by phone bank app).
- Phase 7 is NOT finished: prison, housing and the taxi job are not written yet. Shops, crafting and courts are written but not yet covered by tests.
- 42 new checks in run9; 1,169 across nine suites.

## 1.7.0-beta (vehicles and world)
## 1.7.0-beta (vehicles and world)
- Radar (minimap) is off by default, so the vanilla health and stamina bars are gone and the Nexoro HUD shows them instead. Switch it on in `/hud` if you want the minimap back.
- Route guide: while a waypoint is set, a small line shows the destination street and distance at the bottom of the screen.
- Notifications sit middle right, play a sound per type (configurable), and GTA's own top-corner feed is hidden.
- Seatbelt: fastening and removing it plays a click.
- nexoro_world: UK real-time clock (GMT in winter, BST in summer, changing on the correct Sundays), a realistic weather cycle that only moves between neighbouring weathers, smooth transitions on every client, wet-road flag, and traffic and pedestrian density. Admin weather and time controls now drive nexoro_world when it runs.
- nexoro_driving: indicators (Q left, R right, auto-cancel), seatbelt chime when moving without a belt, and reduced grip on wet roads.
- 39 new checks in run8; 1,127 across eight suites.

## 1.6.0-beta (fixes from playtest)
## 1.6.0-beta (fixes from playtest)
- Admin: the first account to join an empty server is made owner automatically (one atomic insert, so two simultaneous first joins cannot both win). Skipped when owners are set in `nexoro_core/config/staff.lua`.
- Death (new `nexoro_death`): going down plays a lying-down emote and shows a bleed-out timer (300 seconds). Emergency services revive you with the normal ambulance revive, which ends the timer. If nobody comes, you respawn at the nearest hospital. The same character and clothes are kept: the ped is revived, not replaced. The server checks you really are dead and measures the 300 seconds itself.
- GTA's own police are switched off on the client: no wanted stars, no NPC police, no dispatch (`Config.Framework.DisableGtaPolice`).
- Chat moved to the top left. The doctor fails if the default `chat` resource is running.
- HUD top-right panels lowered below the FiveM build number. Street and compass labels made smaller.
- Character creator: "Gypsy, Roma or Traveller" added to the nationality list (a UK census category). Move it to its own field if you prefer.
- 33 new checks in `run7` (first owner, bleed-out timing, revive link, configuration); 1,088 across seven suites.

## Fixed during Phase 6
## 1.5.0-beta (Phase 6: Dispatch and emergency technology)
- nexoro_dispatch: 999/101/111 calls from the phone create incidents at the caller's server-side position; alerts to on-duty services and dispatchers; incident priority, descriptions, manual incidents, assignment (service must match, unit must be free), unit status with checked transitions, release, close with outcome, history, GPS waypoints; radio channels (public 1-99 with a radio item, police, ambulance and fire channels for on-duty members, dispatch 900 for dispatchers); `/radio` and `/radiooff`
- nexoro_tablet: department tablet (item `tablet`, used or `/tablet`). Apps are shown only for permissions the player holds: Dispatch, My status, MDT, Patient records, Fire incidents, Hazards. Every request is checked against a per-app allowlist and then the callback's own permission checks (new core `InvokeCallback`)
- nexoro_lighting: lightbar presets (patrol, traffic, response, ambulance, fire) drawn as synced LED lights for nearby players; sirens synced to everyone nearby; driver keys G (cycle presets), H (siren), J (airhorn, local); only on-duty emergency members, only emergency models, only the setter can change their lights; cleared when a vehicle vanishes, when the setter goes off duty, or when they leave
- 132 more offline tests (real MariaDB); 1,043 across six suites

## 1.5.1-beta (Phase 6 follow-up: menus and map)
- Menus: every top-level menu gets a Close button; submenus keep Back; descriptions added to the player menu, service menu, vehicle menu and dealership buttons
- Admin menu: a hover hint on every action and a one-line explanation at the top of every tab
- Tablet: ‹ Back to options on every form, and a hint line on each form
- nexoro_map: static stations, hospitals, fire stations, job centre, banks and shops; live incident blips (priority colours, flashing when immediate) that clear when an incident closes; hazard zones as radius circles; unit dots for on-duty emergency services only
- Dispatch: closed incidents are broadcast so the map can clear them; new `UnitList` export
- 143 offline tests in the Phase 6 suite, 1,054 across six suites

## Fixed during Phase 6
- `Dispatch.Open` returned a bare id where the callback convention needs (ok, data)

## 1.4.0-beta (Phase 5: Emergency services)
- nexoro_emergency: 12 departments (police, highways, ambulance, fire) as jobs with ranks, cumulative permissions per rank, duty (with uniform on/off), callsigns (CP-12 style, unique per department), rosters, hire/promote/demote/dismiss, F6 service menu, `/service`
- nexoro_police: cuffs and arrests (with sentence hold), penalty notices (paid or outstanding), cautions, warrants, MDT person and wanted lookups, plate lookup (when vehicles run), search, seizure into numbered evidence bags, breath tests
- nexoro_ambulance: revive with cooldown, bandages from the responder's own supplies, assessments, hospital admission and discharge (billing off by default), medical records
- nexoro_fire: incidents (raise, attend, close), extinguish, extrication, hazard zones that expire and are sent to every client
- core: `GetGradePermissions` API; character appearance can be re-applied by other resources (for uniforms)
- 216 more offline tests (real MariaDB)

## 1.3.0-beta (Phase 4: Vehicles)
- nexoro_vehicles: UK plates (AB12 CDE), ownership, shared keys, lock key (L), server-validated fuel/mileage/health reports, fuel pumps (£1.45/litre), insurance plans and wreck claims, MOT (£54.85), player-to-player sales, finance with repossession, impound, abandoned-vehicle sweep, restart recovery, vehicle history, `/vehicles` menu
- nexoro_garages: public garages and impound lots (store, retrieve, pay release), server-validated distance and spawn points
- nexoro_dealerships: two dealerships, cash/bank/finance purchases with server-side prices, dealer buyback
- nexoro_admin: Registry tab (search, impound, release, repair, transfer, scrap) with audit trail
- 177 more offline tests (real MariaDB)

## 1.2.0-beta (Phase 3: Interface)
- nexoro_ui: progress bar (with cancel, controls lock, animation), context menus with submenus, input dialogs, confirm/alert dialogs, text UI; awaitable helpers via `@nexoro_ui/lib/client.lua`
- nexoro_hud: health, armour, hunger, thirst, stress, stamina, cash/bank, ID/name/job, voice, radio, vehicle (MPH, fuel, engine, seatbelt), street, compass; position/size/element settings (/hud); server-side hunger/thirst/stress with starvation
- nexoro_loading: custom loading screen with real progress, 10 rotating panels, rules, announcements, music player (volume, mute)
- nexoro_phone: UK numbers (07xxx xxxxxx), contacts, SMS, calls (999/101/111 raise `nexoro:server:emergencyCall`), bank app, jobs, GPS, email, adverts, Chirp social, settings, battery and charger item
- nexoro_menu: player menu (F5) and in-game help centre (/help)
- core: `nexoro:server:metadataChanged` event, `GetJobs` API
- 119 more offline tests (real MariaDB); phone and HUD server logic fully covered

## 1.1.0-beta (Phase 2: Basic gameplay + staff menu)
- nexoro_banking: atomic deposit/withdraw/transfer (offline recipients supported), immutable ledger, statements, job salaries
- nexoro_inventory: 40 slots, 30 kg weight, stacking, metadata, split/merge/swap, usable items, stashes, drag-and-drop UI, quick slots 1-5
- nexoro_notifications: nine notification types
- nexoro_chat: server-verified job prefixes, channels (local, OOC, /me, /do, department, 999, staff, PM), spam/mute, profanity filter, history, `chat:addMessage` compatibility
- nexoro_admin: in-game staff menu (F9, /admin, /mod) with 40+ actions, bans/warnings, audit log with previous/new values, maintenance mode, weather/time, economy and log views
- core: ReloadBalances, player summaries, rank list, connect hooks accept table results
- 229 more offline tests (real MariaDB)

## 1.0.0-beta (Phase 1: Foundation)
- nexoro_database: oxmysql wrapper, migration runner (checksummed, idempotent), readiness gate
- nexoro_core: player lifecycle, character load/save, server-authoritative money (integer pence), jobs, permissions, callbacks, rate limiting, audit logging, developer API, `nexoro_doctor`
- nexoro_identity: UK-style character validation, citizen IDs, impersonation-safe names
- nexoro_character: character selection and creation NUI, appearance, saved outfits, `/wardrobe`, `/logout`
- 170 offline tests (real MariaDB 10.11) covering the above

## 1.17.0-beta (test server tools)
- `nexoro_devtools`: off unless `set nexoro_devmode "true"` is in server.cfg. For the owner only: `/devmoney`, `/devitem`, `/devtp`, `/devheal`, `/devjob`, `/devselfcheck`.
- `/devselfcheck` checks the database, the core tables, that an owner exists, and that every Nexoro resource started. Failures name the cause.
- `nexoro_dbreset <token>` (console only, dev mode only) drops every Nexoro table, so the next start rebuilds the database. The token is printed at each startup and works once.
- `docs/TEST_WORKFLOW.md`: the steps for re-uploading resources and refreshing the database between tests.
- 37 checks in run17. All seventeen suites and the integrity check pass: 1,602 checks.

## 1.16.1-beta (handling)
## 1.16.1-beta (handling)
- Stock vans corrected to the names in the realistic handling pack's list: Declasse Burrito (`burrito3`) and Bravado Rumpo (`rumpo`).
- Optional server resource line for Taira's Realistic Handling for Vanilla Vehicles (credit to Taira). Off by default. Not included in Nexoro.
- Client setup note recommends it over the game-file handling mod, since it is a server resource and nobody installs anything.


## 1.16.0-beta (vehicles for the trades; optional car pack)
- Dealership: three stock GTA commercial vehicles added (Bravado Burrito, Vapid Rumpo, Bravado Bison pickup). Spawn codes to be checked on your build.
- Optional cars: seven cars from SpiritsCreations' Lore-Friendly Car Pack are in the Premium Deluxe catalogue. They are listed and sellable only while the resource `Lore-Friendly-Car-Pack` is running. The pack is not included in Nexoro. Install it yourself into your server's resources. Prices are placeholders.
- Game build: the pack says some cars need `sv_enforceGameBuild 3258`. The template still pins 3095. Not changed.
- 179 checks in run4 (up from 177). All sixteen suites and the integrity check pass.

## 1.15.0-beta (encampments and scrap collecting)
## 1.15.0-beta (encampments and scrap collecting)
- Background: "Gypsy, Roma or Traveller" is a choice on the character creator. It has no effect on pitches, notices, warrants, gates or pay.
- Encampments: anyone can claim one empty pitch on open land (Sandy Shores and Grapeseed, placeholder coordinates) for £250. Pitches show on the map. The occupant can be served a notice to move on by any constable on duty, with 14 days to comply. A sergeant can issue a warrant only after that deadline, and it lasts 24 hours. The occupant can open and close their gate. Police on duty with a live warrant can too. Anyone can vacate a pitch.
- Scrap collector: a civilian job. Start a shift with `/scrap duty`, collect scrap at marked points on the map (2 to 4 pieces each), and each point rests for ten minutes. Sell scrap at the Builders Yard.
- Gate control and the gate's model are placeholders until the custom MLO is in.
- 36 checks in run16. All sixteen suites and the integrity check pass: 1,563 checks.

## 1.14.0-beta (crews and hunting)
## 1.14.0-beta (crews and hunting)
- Crews: player-made groups. Create one for £500 (name 3 to 24 characters, unique). The leader invites players (invites expire after 60 seconds), kicks members, or disbands. Members can leave. A player can be in one crew at a time, up to eight members. Other systems can ask `SameCrew` to check if two players are in the same crew.
- Hunting: a £40 hunting licence from the council office, then hunt at Paleto Woods (placeholder coordinates) for venison or pelts, with a 45 second cooldown. Nothing caught is a valid try.
- Recipe and server.cfg template now start 52 resources; the integrity check keeps them in step.
- 38 checks in run15. All fifteen suites and the integrity check pass: 1,527 checks.

## 1.13.0-beta (Legion Square supply drops)
## 1.13.0-beta (Legion Square supply drops)
- Supply drops at Legion Square at 18:00 and 21:00 on the in-game clock. Everyone is told five minutes ahead, with a waypoint and a notification. The crate appears on everyone's map.
- Only the team can open a crate: by default, on-duty members of the Caledonia Police job. Set `Team` to another job name, or to nil so anyone can open it.
- One player takes the loot. Loot is weighted: mostly cash (£500 to £1,500), with cash bags, repair kits, steel parts and lockpicks.
- An unclaimed crate is removed after 15 minutes.
- 26 checks in run14. All fourteen suites and the integrity check pass.

## 1.12.0-beta (Phase 8: entertainment and social, first part)
## 1.12.0-beta (Phase 8: entertainment and social, first part)
- Responsible gambling: one daily stake limit (£100, resets daily) shared by the lottery and scratchcards. Stakes are reserved before money is taken, and given back if the payment fails.
- National lottery: buy a ticket with six different numbers from 1 to 49 at the counter (£2 each, up to ten per person per draw). Weekly draw. Prizes: 60% of the pot for six numbers, 25% for five, 15% for four, split between winners. A tier with no winner rolls over to the next draw. Every pound in the pot is either paid or carried forward.
- Scratchcards: £5 a card, instant win, published prize table with about 97% return to player.
- Loading screen: `html/audio/music.mp3` added as an empty placeholder. Drop a real track in with the same name. An empty file may play silence or log an error on the loading screen, so check that when you test.
- 40 checks in run13. All thirteen suites and the integrity check pass.

Note: Phase 8's original plan was not in my notes, so this is my reading of "entertainment and social". Tell me if your Phase 8 list differs and I will rework it.

## 1.11.1-beta (integrity pass)
## 1.11.1-beta (integrity pass)
- Removed a stale duplicate resource (`nexoro_auction`) left over from an earlier draft. It created a `nexoro_auctions` table with a different schema, which could have won on a fresh install because the migration uses CREATE TABLE IF NOT EXISTS.
- Added `tests/integrity.py`, a static check across all 43 resources: missing files, missing dependencies, exports called but not defined, client callbacks with no server handler, and start order. It runs as part of `run_all.sh`. It is checked against planted faults so it is known to catch real mistakes.
- Static result: 0 problems across 43 resources and 97 callbacks.


## 1.11.0-beta (Phase 7: the rest of the civilian economy and crime)
- Public transport: bus route with stops. Tap on at a stop and off at another; the fare follows the road distance between the stops (minimum £1.50). You stay on the bus if you cannot pay.
- Pawn shop: sells radios, phones, repair kits, scrap and similar items for fixed pawn prices.
- Auction house: list an item (held in escrow until sold or claimed), bid with a minimum step, outbid bidders are refunded at once, and sales pay the seller less a 5% fee. Unsold items go back to the seller.
- Robberies: a corner store and an ATM. Each needs a lockpick (used up on success), has its own cooldown, and raises a police alarm that becomes an immediate incident in dispatch.
- Farming: plant wheat seed on two plots, come back after 10 minutes, harvest 2 to 4 wheat. Only the planter can harvest; a full inventory keeps the crop in the ground.
- 68 checks in run12. All twelve suites: 1,423 checks.

### Still not built
Hunting, house and vehicle theft, illegal markets, weapon licences, court hearings beyond paying fines, the bulk of the civilian jobs (taxi and postal exist; the rest are not built), and the premium features: custom minimap, night traffic lights, and realistic per-vehicle handling.

## 1.10.0-beta (Phase 7: civilian systems, continued)
## 1.10.0-beta (Phase 7: civilian systems, continued)
- Licences: driving licence with a five-question written test (answers stay on the server; pass mark 4; fee £60; licence card issued), and a fishing licence (£25). Bought at the council office.
- Businesses: register a business (£2,500, two per owner), a business bank account (deposit and withdraw), staff with hourly wages (up to £500/hour) paid automatically from the account. An empty account pays nobody. Owners can hire, dismiss, and staff can quit.
- Postal worker: a real civilian job. Go on duty, start a round of three GPS drops in a random order, and deliver by standing at the door and pressing E. Each drop pays £35; finishing the round pays a £60 bonus. Drops cannot be cleared within 15 seconds of the previous one.
- Fishing: needs a fishing licence and to be at a spot. Catches are rolled on the server from a weighted table, with a 20 second cooldown.
- Fixed while testing: the postal first drop was blocked by a pause that should only apply between drops.
- 70 checks in run11. All eleven suites: 1,355 checks.

### Still not built in Phase 7
Public transport (buses and trains), auctions, pawn shops, illegal markets, store, ATM and house robberies, vehicle theft, farming and hunting, weapon licences, and the government services that go with them.

## 1.9.0-beta (Phase 7: civilian systems)
## 1.9.0-beta (Phase 7: civilian systems)
- Prison: a police arrest with a sentence sends the player to a cell on the server clock (`nexoro:server:arrested`). Cuffs come off on the way in, sentences survive logging out, and release happens automatically when time is served. Sentences are capped at two weeks.
- Housing: estate agent with two sample properties. Buy from the bank, sell back at 60%, weekly bills taken from the bank with arrears, repossession after four missed weeks, shared keys (up to five), and property storage (deposit and withdraw).
- Taxi: a real civilian job (`taxi`). A driver on duty offers a fare to a nearby passenger, who must accept. The fare is measured on the server from the route, the passenger pays from their bank, and the driver keeps 80%. Trips finishing faster than 90 mph, trips with no movement, and passengers who are not in the car are refused.
- Shops, crafting and courts (from the previous update) now have tests. Fixed a bug: shop stock keys were missing their shop id, which would have failed every purchase.
- 116 checks in run10. All ten suites: 1,285 checks.

### Not built yet (still Phase 7)
Businesses, the remaining civilian jobs (only taxi exists so far), public transport, postal and delivery, licences (driving, weapon, fishing), pawn shops, auctions, fishing, farming and hunting, store robberies and illegal markets.

## 1.8.0-beta (admin recovery, radio, vehicles, civilian economy begins)
## 1.8.0-beta (admin recovery, radio, vehicles, civilian economy begins)
- Getting owner, in order of reliability: (1) the first account to join an empty server; (2) `set nexoro_owner_license "license:..."` in server.cfg; (3) if nobody is owner, a six-digit code is printed in the server console at start: type `/claimowner CODE` in game. Type `/mystaff` to see your rank. The staff menu now explains why it refused you.
- Dealerships: the showroom opens within 4.5 metres, on foot only (it no longer opens while driving past). Shops and the server-side checks are tightened to match.
- Loading screen: `loadscreen_cursor 'yes'` added so the mouse can move on the loading screen.
- Radio chatter: `/r` (or `/radio`) talks on the channel you are tuned to. Dispatch calls out assignments and status changes on the matching channel. Only that channel hears it.
- Car wash (£15), dirt builds up while driving and is cleaned at a wash, hard impacts can puncture a tyre, and a passed MOT repairs punctures.
- Civilian economy begins: `nexoro_shops` (buy and sell, stock that restocks over time), `nexoro_crafting` (workbench recipes, refunded if the result will not fit), `nexoro_courts` (see and pay outstanding fines, in person or by phone bank app).
- Phase 7 is NOT finished: prison, housing and the taxi job are not written yet. Shops, crafting and courts are written but not yet covered by tests.
- 42 new checks in run9; 1,169 across nine suites.

## 1.7.0-beta (vehicles and world)
## 1.7.0-beta (vehicles and world)
- Radar (minimap) is off by default, so the vanilla health and stamina bars are gone and the Nexoro HUD shows them instead. Switch it on in `/hud` if you want the minimap back.
- Route guide: while a waypoint is set, a small line shows the destination street and distance at the bottom of the screen.
- Notifications sit middle right, play a sound per type (configurable), and GTA's own top-corner feed is hidden.
- Seatbelt: fastening and removing it plays a click.
- nexoro_world: UK real-time clock (GMT in winter, BST in summer, changing on the correct Sundays), a realistic weather cycle that only moves between neighbouring weathers, smooth transitions on every client, wet-road flag, and traffic and pedestrian density. Admin weather and time controls now drive nexoro_world when it runs.
- nexoro_driving: indicators (Q left, R right, auto-cancel), seatbelt chime when moving without a belt, and reduced grip on wet roads.
- 39 new checks in run8; 1,127 across eight suites.

## 1.6.0-beta (fixes from playtest)
## 1.6.0-beta (fixes from playtest)
- Admin: the first account to join an empty server is made owner automatically (one atomic insert, so two simultaneous first joins cannot both win). Skipped when owners are set in `nexoro_core/config/staff.lua`.
- Death (new `nexoro_death`): going down plays a lying-down emote and shows a bleed-out timer (300 seconds). Emergency services revive you with the normal ambulance revive, which ends the timer. If nobody comes, you respawn at the nearest hospital. The same character and clothes are kept: the ped is revived, not replaced. The server checks you really are dead and measures the 300 seconds itself.
- GTA's own police are switched off on the client: no wanted stars, no NPC police, no dispatch (`Config.Framework.DisableGtaPolice`).
- Chat moved to the top left. The doctor fails if the default `chat` resource is running.
- HUD top-right panels lowered below the FiveM build number. Street and compass labels made smaller.
- Character creator: "Gypsy, Roma or Traveller" added to the nationality list (a UK census category). Move it to its own field if you prefer.
- 33 new checks in `run7` (first owner, bleed-out timing, revive link, configuration); 1,088 across seven suites.

## Fixed during Phase 6
## 1.5.0-beta (Phase 6: Dispatch and emergency technology)
- nexoro_dispatch: 999/101/111 calls from the phone create incidents at the caller's server-side position; alerts to on-duty services and dispatchers; incident priority, descriptions, manual incidents, assignment (service must match, unit must be free), unit status with checked transitions, release, close with outcome, history, GPS waypoints; radio channels (public 1-99 with a radio item, police, ambulance and fire channels for on-duty members, dispatch 900 for dispatchers); `/radio` and `/radiooff`
- nexoro_tablet: department tablet (item `tablet`, used or `/tablet`). Apps are shown only for permissions the player holds: Dispatch, My status, MDT, Patient records, Fire incidents, Hazards. Every request is checked against a per-app allowlist and then the callback's own permission checks (new core `InvokeCallback`)
- nexoro_lighting: lightbar presets (patrol, traffic, response, ambulance, fire) drawn as synced LED lights for nearby players; sirens synced to everyone nearby; driver keys G (cycle presets), H (siren), J (airhorn, local); only on-duty emergency members, only emergency models, only the setter can change their lights; cleared when a vehicle vanishes, when the setter goes off duty, or when they leave
- 132 more offline tests (real MariaDB); 1,043 across six suites

## 1.5.1-beta (Phase 6 follow-up: menus and map)
- Menus: every top-level menu gets a Close button; submenus keep Back; descriptions added to the player menu, service menu, vehicle menu and dealership buttons
- Admin menu: a hover hint on every action and a one-line explanation at the top of every tab
- Tablet: ‹ Back to options on every form, and a hint line on each form
- nexoro_map: static stations, hospitals, fire stations, job centre, banks and shops; live incident blips (priority colours, flashing when immediate) that clear when an incident closes; hazard zones as radius circles; unit dots for on-duty emergency services only
- Dispatch: closed incidents are broadcast so the map can clear them; new `UnitList` export
- 143 offline tests in the Phase 6 suite, 1,054 across six suites

## Fixed during Phase 6
- `Dispatch.Open` returned a bare id where the callback convention needs (ok, data)

## 1.4.0-beta (Phase 5: Emergency services)
- nexoro_emergency: 12 departments (police, highways, ambulance, fire) as jobs with ranks, cumulative permissions per rank, duty (with uniform on/off), callsigns (CP-12 style, unique per department), rosters, hire/promote/demote/dismiss, F6 service menu, `/service`
- nexoro_police: cuffs and arrests (with sentence hold), penalty notices (paid or outstanding), cautions, warrants, MDT person and wanted lookups, plate lookup (when vehicles run), search, seizure into numbered evidence bags, breath tests
- nexoro_ambulance: revive with cooldown, bandages from the responder's own supplies, assessments, hospital admission and discharge (billing off by default), medical records
- nexoro_fire: incidents (raise, attend, close), extinguish, extrication, hazard zones that expire and are sent to every client
- core: `GetGradePermissions` API; character appearance can be re-applied by other resources (for uniforms)
- 216 more offline tests (real MariaDB)

## 1.3.0-beta (Phase 4: Vehicles)
- nexoro_vehicles: UK plates (AB12 CDE), ownership, shared keys, lock key (L), server-validated fuel/mileage/health reports, fuel pumps (£1.45/litre), insurance plans and wreck claims, MOT (£54.85), player-to-player sales, finance with repossession, impound, abandoned-vehicle sweep, restart recovery, vehicle history, `/vehicles` menu
- nexoro_garages: public garages and impound lots (store, retrieve, pay release), server-validated distance and spawn points
- nexoro_dealerships: two dealerships, cash/bank/finance purchases with server-side prices, dealer buyback
- nexoro_admin: Registry tab (search, impound, release, repair, transfer, scrap) with audit trail
- 177 more offline tests (real MariaDB)

## 1.2.0-beta (Phase 3: Interface)
- nexoro_ui: progress bar (with cancel, controls lock, animation), context menus with submenus, input dialogs, confirm/alert dialogs, text UI; awaitable helpers via `@nexoro_ui/lib/client.lua`
- nexoro_hud: health, armour, hunger, thirst, stress, stamina, cash/bank, ID/name/job, voice, radio, vehicle (MPH, fuel, engine, seatbelt), street, compass; position/size/element settings (/hud); server-side hunger/thirst/stress with starvation
- nexoro_loading: custom loading screen with real progress, 10 rotating panels, rules, announcements, music player (volume, mute)
- nexoro_phone: UK numbers (07xxx xxxxxx), contacts, SMS, calls (999/101/111 raise `nexoro:server:emergencyCall`), bank app, jobs, GPS, email, adverts, Chirp social, settings, battery and charger item
- nexoro_menu: player menu (F5) and in-game help centre (/help)
- core: `nexoro:server:metadataChanged` event, `GetJobs` API
- 119 more offline tests (real MariaDB); phone and HUD server logic fully covered

## 1.1.0-beta (Phase 2: Basic gameplay + staff menu)
- nexoro_banking: atomic deposit/withdraw/transfer (offline recipients supported), immutable ledger, statements, job salaries
- nexoro_inventory: 40 slots, 30 kg weight, stacking, metadata, split/merge/swap, usable items, stashes, drag-and-drop UI, quick slots 1-5
- nexoro_notifications: nine notification types
- nexoro_chat: server-verified job prefixes, channels (local, OOC, /me, /do, department, 999, staff, PM), spam/mute, profanity filter, history, `chat:addMessage` compatibility
- nexoro_admin: in-game staff menu (F9, /admin, /mod) with 40+ actions, bans/warnings, audit log with previous/new values, maintenance mode, weather/time, economy and log views
- core: ReloadBalances, player summaries, rank list, connect hooks accept table results
- 229 more offline tests (real MariaDB)

## 1.0.0-beta (Phase 1: Foundation)
- nexoro_database: oxmysql wrapper, migration runner (checksummed, idempotent), readiness gate
- nexoro_core: player lifecycle, character load/save, server-authoritative money (integer pence), jobs, permissions, callbacks, rate limiting, audit logging, developer API, `nexoro_doctor`
- nexoro_identity: UK-style character validation, citizen IDs, impersonation-safe names
- nexoro_character: character selection and creation NUI, appearance, saved outfits, `/wardrobe`, `/logout`
- 170 offline tests (real MariaDB 10.11) covering the above
