# Phase 1 Testing

## Automated (offline) results
Run: `NEXORO_ROOT=. lua5.4 tests/run.lua` (needs lua5.4, lua-cjson, MariaDB socket at /tmp/mdb.sock or NEXORO_TEST_SOCKET).
The suite loads the real Lua files, stubs FiveM natives, and runs against a real MariaDB. Last run: **170 passed, 0 failed** for Phase 1 (`docs/TEST_RESULTS.txt`) and **229 passed, 0 failed** for Phase 2 (`docs/TEST_RESULTS_PHASE2.txt`). Phase 3 adds **119 passed, 0 failed** (`docs/TEST_RESULTS_PHASE3.txt`). Phase 4 adds **177 passed, 0 failed** (`docs/TEST_RESULTS_PHASE4.txt`). Run all with `NEXORO_ROOT=. sh tests/run_all.sh`.

Covered: UK money formatting, pence maths, validation (names, DOB, leap years, impersonation names), appearance clamping, migrations (apply, idempotent re-run), player rows, IP never stored, permissions and staff hierarchy, moderator restrictions, jobs, character create/list/select/delete through the real callback path, ownership checks, slot limits, cascade deletes, atomic money (no negatives, no overflow, no SQL injection via account name), outfits and limits, disconnect save, rejoin, core-restart recovery, rate limiting and kick, audit logging.

## Manual checklist (needs a live FiveM server) -- not yet run
- [ ] Clean install on a fresh server; `nexoro_doctor` reports no problems
- [ ] Join: loading screen closes, selection scene shows, panel readable
- [ ] Create a character; ped model, face, hair and clothing preview update live
- [ ] Character persists after reconnect (position, appearance, job, money)
- [ ] `/wardrobe` opens, saves outfits, Wear/Delete work, Close discards unsaved changes
- [ ] `/logout` returns to selection
- [ ] Deleting needs the typed citizen ID
- [ ] Two players selecting at once cannot see each other's preview peds
- [ ] Restart nexoro_core while joined: character restored, no errors
- [ ] Restart nexoro_character while on selection screen and in game
- [ ] Moderator cannot run admin-only actions (once Phase 8 menus exist)
- [ ] NUI focus releases after spawning (mouse and keyboard work in game)

## Manual checklist, Phase 2 (live server) -- not yet run
- [ ] Inventory opens with I, drag/stack/swap/split (Shift) work, weight bar updates, quick slots 1-5 work, Esc closes and releases focus
- [ ] Notifications appear for banking, inventory and staff events
- [ ] Chat opens with T, channels work, prefixes show for on-duty police, `chat:addMessage` from another script displays
- [ ] F9 opens the staff menu; a moderator sees only moderation actions; a normal player sees nothing
- [ ] Noclip, god mode, invisibility, nametags, spectate, teleport to waypoint behave and release cleanly
- [ ] Vehicle spawn/repair/clean/flip/delete work for self and for a selected player
- [ ] Weather and time changes reach all clients; frozen time holds
- [ ] A banned player is refused at connect with the reason and expiry (DD/MM/YYYY HH:MM)
- [ ] Maintenance mode lets staff in and blocks everyone else

## Manual checklist, Phase 3 (live server) -- not yet run
- [ ] Loading screen shows, progress moves, panels rotate, music controls work (after adding a track), it closes when the character scene appears
- [ ] HUD shows only after a character is loaded; MPH, fuel, engine, seatbelt (B), street and compass are correct in a vehicle
- [ ] `/hud` changes position, size and visibility and remembers them after relogging
- [ ] Eating/drinking items move the hunger/thirst rings; 0 hunger or thirst slowly damages health
- [ ] F1 opens the phone with animation and prop; every app opens; calls ring, answer (Y/N with phone closed) and end cleanly
- [ ] With pma-voice installed, two players hear each other on a call
- [ ] 999 call reaches the dispatch event (once the dispatch resource exists)
- [ ] Progress bar: X cancels, movement locks, animation plays; context menus, input and confirm dialogs release mouse focus when closed
- [ ] F5 menu and `/help` work

## Manual checklist, Phase 4 (live server) -- not yet run
- [ ] Buy a vehicle at a dealership (bank, cash and finance); it appears in the delivery garage with a UK plate
- [ ] Retrieve spawns it in a free bay with the right model, plate, fuel, damage and colours; the second retrieve is refused
- [ ] Park and store: condition and mileage persist; the entity is removed
- [ ] L locks/unlocks with a key; a stranger cannot; shared keys work and can be revoked
- [ ] Fuel drains while driving, the engine cuts at 0, pumps refuel and charge the right amount
- [ ] MOT bay test passes/fails by condition; insurance, wreck claim and scrap flow work
- [ ] Selling to a nearby player: offer popup, accept, ownership and money move
- [ ] Police impound then release at the lot; abandoned vehicle is impounded after 10 minutes
- [ ] Restart the server with vehicles out: they return to their garages
- [ ] Verify garage, dealership, pump and MOT coordinates and blips

## Phase 5 (offline): **216 passed, 0 failed** (`docs/TEST_RESULTS_run5.txt`)

## Phase 6 (offline): **143 passed, 0 failed** (`docs/TEST_RESULTS_run6.txt`). All six suites: 1,054 checks.

## Manual checklist, Phase 6 (live server) -- not yet run
- [ ] Dial 999 from the phone: an incident appears for dispatchers and on-duty services; off-duty players are not alerted
- [ ] Dispatch assigns a unit; the unit gets a waypoint; status changes flow through to the tablet
- [ ] Radio: /radio 101 for police, /radio 5 with a radio item; channel 900 is for dispatch only
- [ ] Tablet item opens the tablet; apps change with rank (a constable sees no dispatch)
- [ ] MDT person and wanted lookups work from the tablet; fire hazards can be placed and expire
- [ ] Lightbar: G cycles presets; other players see the LED lights and hear the siren; H toggles the siren
- [ ] Lightbars clear when the driver leaves or goes off duty
- [ ] Verify light positions on each emergency model (they are approximate)

## Manual checklist, menus and map (live server) -- not yet run
- [ ] Every top-level menu shows Close; submenus show Back and return to the parent
- [ ] Hover over admin actions to see what they do; each tab shows its explanation
- [ ] Tablet forms show a hint and ‹ Back to options
- [ ] Stations, hospitals, job centre, banks and shops appear on the map
- [ ] A 999 call makes a flashing incident blip for on-duty services and it disappears when closed
- [ ] Hazard zones show as red circles; unit dots show for emergency crews only

## Playtest fixes (offline 33 checks in run7; 1,088 across seven suites)

## Manual checklist, playtest fixes (live server) -- not yet run
- [ ] Restart the server, then join: the first player becomes owner and can open the staff menu (F9)
- [ ] Creating a character offers "Gypsy, Roma or Traveller" under nationality
- [ ] Wanted stars and police cars never appear when you commit a crime
- [ ] Chat is at the top left; the default FiveM chat does not appear
- [ ] Dying: you lie down, the timer counts from 5:00; an ambulance revive gets you up on the spot with your clothes
- [ ] With nobody reviving you, respawn happens at 0:00 at the hospital, still wearing your clothes
- [ ] HUD panels sit below the build number; street and compass text is small

## World and driving (offline): 39 checks in run8 (`docs/TEST_RESULTS_run8.txt`). All eight suites: 1,127 checks.

## Manual checklist, world, driving and HUD (live server) -- not yet run
- [ ] No minimap by default; the Nexoro health and stamina rings show; /hud can switch the minimap back on
- [ ] Setting a waypoint shows "Route: <street> · x mi" at the bottom of the screen
- [ ] Notifications appear middle right, with a sound; GTA's top-corner feed is gone
- [ ] Fastening the belt plays a click; driving above 15 mph unbelted plays a chime
- [ ] Indicators Q and R work, switch off on their own after about 12 seconds
- [ ] In rain the car slides more; in clear weather it does not
- [ ] The clock matches UK time (check the change in March and October)
- [ ] Weather changes gradually between neighbouring types, not abruptly
- [ ] Traffic and pedestrian density feel right; tune `nexoro_world/config.lua` if not

## Admin, radio, vehicles, civilian economy (offline): 42 checks in run9. All nine suites: 1,169 checks.

## Manual checklist, this batch (live server) -- not yet run
- [ ] Join an empty server: the first account is owner. Otherwise use nexoro_owner_license, or /claimowner with the console code
- [ ] `/mystaff` shows your rank; F9 opens the staff menu
- [ ] Dealership showroom opens only on foot, within a few metres; driving past does nothing
- [ ] The mouse moves on the loading screen (check the `loadscreen_cursor` line works on your build)
- [ ] `/r` on police, ambulance and fire channels reaches only that channel; dispatch calls assignments over the radio
- [ ] Car wash charges £15 and cleans dirt; a hard crash can puncture a tyre; an MOT pass repairs it
- [ ] Shops buy and sell; stock goes down and restocks over hours; crafting refunds ingredients when the result will not fit
- [ ] `/fines` lists outstanding fines and paying one clears it

## Phase 7 (offline): 116 checks in run10. All ten suites: 1,285 checks.

## Manual checklist, Phase 7 (live server) -- not yet run
- [ ] Arrest a suspect with a sentence: they are taken to the cell, cuffs off; release after the time, at the release point
- [ ] Log out and back in while serving: back in the cell
- [ ] Estate agent: buy a flat, give a key, enter and leave, store an item, sell back
- [ ] Missed weekly bills build arrears; the flat is repossessed after four weeks
- [ ] Taxi: offer a fare, the passenger accepts, drive and finish; the fare is charged and the driver is paid
- [ ] Shops, crafting and fines still work (see the earlier checklist)
- [ ] Verify the prison cell, release, agent and taxi coordinates on your map

## Phase 7, continued (offline): 70 checks in run11. All eleven suites: 1,355 checks.

## Manual checklist, Phase 7 continued (live server) -- not yet run
- [ ] Take the driving test at the council office; a pass gives a licence card; a fail costs the fee
- [ ] Buy a fishing licence, then fish at the harbour pier; wait 20 seconds between casts
- [ ] Register a business, deposit, hire an employee; wages arrive hourly in their bank
- [ ] Go on duty as a postal worker, start a round, deliver three drops with E
- [ ] Verify the council office, fishing spot, postal drop and business coordinates in-game

## Phase 7, final batch (offline): 68 checks in run12. All twelve suites: 1,423 checks.

## Manual checklist, final Phase 7 batch (live server) -- not yet run
- [ ] Tap on at a bus stop and off at another; the fare is taken from the bank
- [ ] Sell items at the pawn shop
- [ ] List an item at the auction house; bid; get outbid and see the refund; claim after it ends
- [ ] Rob the corner store or ATM with a lockpick; a police incident appears in dispatch; the cooldown holds
- [ ] Plant wheat on a farm plot, come back after 10 minutes, harvest
- [ ] Verify bus stops, pawn shop, auction house, robbery targets and farm plots in-game

## Static integrity check (tests/integrity.py)
Checks every resource without running the game: files named in manifests exist (including cross-resource @ references), dependencies exist, exports called from other resources are defined, client callbacks have a server handler, and the server.cfg start order respects dependencies. Last run: 0 problems across 43 resources and 97 callbacks.
It was tested against planted faults (a missing file and a misspelled callback), and both were caught.

## Phase 8, first part (offline): 40 checks in run13. All thirteen suites and the integrity check pass.

## Manual checklist, Phase 8 first part (live server) -- not yet run
- [ ] The loading screen plays (or at least shows without errors) with the placeholder music.mp3; replace it with a real track
- [ ] Buy a lottery ticket at the counter; the pot grows; the draw runs weekly
- [ ] Buy scratchcards at the corner shop counter; the daily £100 limit blocks further stakes
- [ ] Verify the lottery counter and scratchcard counter coordinates in-game

## Supply drops (offline): 26 checks in run14. All fourteen suites and the integrity check pass.

## Manual checklist, supply drops (live server) -- not yet run
- [ ] Five minutes before 18:00 and 21:00 everyone is told where and when; the waypoint is set
- [ ] The crate appears at Legion Square on the map and on the ground at the set time
- [ ] A civilian cannot open it; an on-duty police officer standing at it can
- [ ] Only one person gets the loot; the crate disappears for everyone
- [ ] An unopened crate disappears after 15 minutes
- [ ] Verify the Legion Square coordinates in-game

## Crews and hunting (offline): 38 checks in run15. All fifteen suites and the integrity check: 1,527 checks.

## Manual checklist, crews and hunting (live server) -- not yet run
- [ ] /crew create <name>; invite someone; they accept with /crew accept; /crew shows the members
- [ ] An invite expires after a minute; a member cannot kick; the leader can
- [ ] Buy a hunting licence at the council office; hunt at Paleto Woods; wait between tries
- [ ] Verify the Paleto Woods coordinates in-game

## Encampments and scrap collecting (offline): 36 checks in run16. All sixteen suites and the integrity check: 1,563 checks.

## Manual checklist, encampments and scrap (live server) -- not yet run
- [ ] Claim a pitch on Sandy Shores; the pitch shows on the map; a second claim is refused
- [ ] A constable serves a notice; a warrant is refused until the 14 days have passed, then a sergeant can issue one
- [ ] The occupant opens and closes their gate; a stranger cannot; police with a warrant can
- [ ] /scrap duty; collect at a point; the point rests for ten minutes; sell scrap at the Builders Yard
- [ ] Verify pitch, gate and scrap point coordinates in-game

## Test tools (offline): 37 checks in run17. All seventeen suites and the integrity check: 1,602 checks.

## Manual checklist, test tools (test server only) -- not yet run
- [ ] With dev mode off, /devmoney does nothing and says dev mode is off
- [ ] With dev mode on, the owner can use /devmoney, /devitem, /devtp, /devheal and /devjob; a civilian cannot
- [ ] /devselfcheck passes every line on a healthy server
- [ ] nexoro_dbreset with the right token drops the tables; restart rebuilds them; /devselfcheck passes again

## Firearms licence and MLO (offline): 13 checks in run18. All eighteen suites and the static check: 1,615 checks.

## Manual checklist, MLO and firearms (live server) -- not yet run
- [ ] The firearms licence can be bought at the council office for £500 and is refused to anyone with an arrest on record
- [ ] With the MLO files in place, the Traveller site loads; the gate prop swings when the occupant or a warrant-holding officer opens it
- [ ] Verify the gate prop model and headings with your MLO

## Crime (offline): 34 checks in run19. All nineteen suites and the static check: 1,649 checks.

## Manual checklist, crime (live server) -- not yet run
- [ ] /steal next to someone else's car that is out on the street: lockpick used, a theft recorded, dispatch alerted
- [ ] A constable on duty recovers the car
- [ ] Rob a house whose owner is offline; the stash items go to you; dispatch alerted; the house cools down
- [ ] Sell stolen goods at the back-room fence; the daily cap applies; buy a lockpick
- [ ] Verify the crime coordinates (fence and house doors) in-game

## Markets, civilian jobs, night traffic (offline): 31 checks in run20. All twenty suites and the static check: 1,680 checks.

## Manual checklist, markets and civilian jobs (live server) -- not yet run
- [ ] Take a civilian job at the job centre; go on duty; do a task at a job point; the pay arrives in the bank; the cooldown holds
- [ ] Sell narcotics packets to the corner contact; the daily cap applies
- [ ] Buy an unregistered pistol from the back-alley dealer
- [ ] At night, traffic and pedestrians are noticeably lighter
- [ ] Verify the job points, job centre and contact coordinates in-game

## Outstanding bugs

## Manual checklist, Phase 5 (live server) -- not yet run
- [ ] Hire a player into a department (inspector or above), promote, demote and dismiss; ranks show in the menu
- [ ] F6 opens the service menu for emergency members only; roster and callsign work
- [ ] Going on duty applies the uniform; going off duty restores civilian clothes
- [ ] Chat shows [POLICE], [AMBULANCE] and [FIRE & RESCUE] only while on duty
- [ ] Cuff, arrest and release a nearby player; the suspect is held and cannot sprint, jump or fight
- [ ] Penalty notice charges the bank; short funds leave it outstanding
- [ ] Revive a dead player on scene; bandage with a bandage item
- [ ] Admit at the hospital area; discharge
- [ ] Raise a fire incident, attend, extinguish; hazard zone warnings appear when walking in
- [ ] Verify uniform component IDs and hospital and fire coordinates in-game

## Outstanding bugs
None known. Unknown until live testing: native/NUI behaviour listed in README.
