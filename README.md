# Nexoro: UK FiveM Roleplay Framework
Developed by Nexoro Network Team. Version 1.15.0-beta. Phases 1 to 6 delivered (plus the in-game staff menu, pulled forward from Phase 8).

Original, standalone framework. No QBCore, QBox, ESX or vRP code. Only third-party dependency: oxmysql (database driver).

## What is in Phase 1
| Resource | Purpose |
|---|---|
| nexoro_database | oxmysql wrapper, checksummed migrations, readiness gate |
| nexoro_core | Players, characters, money, jobs, permissions, callbacks, logging, API, `nexoro_doctor` |
| nexoro_identity | UK character validation, citizen IDs, impersonation-safe names |
| nexoro_character | Character select/create UI, appearance, saved outfits, `/wardrobe`, `/logout` |
| nexoro_notifications | Nine styled notification types |
| nexoro_banking | Deposit, withdraw, transfer by citizen ID, statements, salaries, immutable ledger |
| nexoro_inventory | 40 slots / 30 kg, stacking, metadata, usable items, stashes, drag-and-drop UI, quick slots 1-5 |
| nexoro_chat | Server-verified job prefixes, 8 channels, spam control, profanity filter, history |
| nexoro_admin | Staff menu (F9, /admin, /mod): dashboard, players, self, vehicles, world, economy, bans, logs |
| nexoro_ui | Progress bars, context menus, input/confirm/alert dialogs, text UI |
| nexoro_hud | Premium HUD (UK units), needs system, seatbelt, `/hud` settings |
| nexoro_loading | Custom loading screen with music player and rotating info panels |
| nexoro_phone | Smartphone: contacts, SMS, calls, bank, jobs, GPS, mail, adverts, Chirp, settings, battery |
| nexoro_menu | Player menu (F5) and help centre (`/help`) |
| nexoro_vehicles | UK plates, ownership, keys, locks, fuel, mileage, insurance, MOT, finance, impound, sales |
| nexoro_garages | Public garages and impound lots (store, retrieve, release) |
| nexoro_dealerships | Dealerships with cash, bank or finance purchases and buyback |
| nexoro_emergency | 12 emergency departments: ranks, duty, uniforms, callsigns, rosters, management (F6) |
| nexoro_police | Cuffs, arrests, penalty notices, cautions, warrants, MDT, search, evidence, breath tests |
| nexoro_ambulance | Revive, bandages, assessments, admission and discharge, medical records |
| nexoro_fire | Incidents, extinguishing, extrication, hazard zones |
| nexoro_dispatch | 999/101/111 calls, incidents, unit status, assignment, GPS, radio channels |
| nexoro_tablet | Department tablet: dispatch, MDT, patient records, fire incidents, hazards (permission-filtered) |
| nexoro_lighting | Emergency lightbar patterns, synced LED lights and sirens, driver controls |
| nexoro_map | Stations, hospitals and shops on the map; live incidents, hazard zones and unit positions |
| nexoro_death | Lying down, 300 second bleed-out, emergency revive, hospital respawn with clothes kept |
| nexoro_world | UK real-time clock, realistic weather cycle, traffic and pedestrian density |
| nexoro_driving | Indicators, seatbelt chime, wet-road grip |
| nexoro_shops | Shops with stock that restocks, buy and sell |
| nexoro_crafting | Workbenches and recipes |
| nexoro_courts | Pay outstanding fines in person or by phone |
| nexoro_prison | Sentences from police arrests, time served on the server clock, release |
| nexoro_housing | Buy and sell property, weekly bills, arrears, repossession, keys, storage |
| nexoro_taxi | Civilian taxi job: offers, accepted fares, measured on the server |
| nexoro_licences | Driving licence with a written test, fishing licence |
| nexoro_businesses | Business accounts, staff, hourly wages |
| nexoro_postal | Postal worker delivery rounds |
| nexoro_fishing | Fishing from spots, licence required |
| nexoro_transport | Bus routes, tap on and off, fares by distance |
| nexoro_pawn | Pawn shop with fixed prices |
| nexoro_auctions | Auction house with escrow, bids, fees, claims |
| nexoro_robbery | Store and ATM robberies, lockpicks, cooldowns, police alarms |
| nexoro_farming | Wheat plots: plant, wait, harvest |
| nexoro_gambling | Daily stake limit shared by lottery and scratchcards |
| nexoro_lottery | Weekly national lottery draw with rollover |
| nexoro_scratchcards | Instant-win scratchcards with published odds |
| nexoro_supplydrop | Scheduled Legion Square drops, announced in advance, claimable by one team |
| nexoro_crews | Player crews: create, invite, members, kick, disband |
| nexoro_hunting | Licensed hunting at woodland spots |
| nexoro_encampments | Pitch claims on open land, notices, warrants after the deadline, gates |
| nexoro_scrapping | Scrap collector job: shifts, collection points, cooldowns |
| nexoro_devtools | Test-server tools: quick setup, self-check, console database reset (dev mode only) |
| nexoro_crime | Vehicle theft, house robbery when the owner is away, back-room fence |
| nexoro_markets | Illegal street contacts: narcotics and unregistered weapons, daily caps, alarms |
| nexoro_civilian | Eight civilian jobs from the job centre, paid tasks at job points |
| nexoro_traveller_site | Placeholder for the custom Traveller site MLO (add your files to stream/) |

## Install with the txAdmin recipe
1. Create a MariaDB database and user (`nexoro`, with full rights on database `nexoro`).
2. In txAdmin, add a recipe from `recipe.yaml` (or paste it in). Answer the prompts: server name, your FiveM licence key, your own licence identifier (this makes you owner), and the database password.
3. Put `oxmysql` in the server's resources folder (txAdmin can install it, or download it from the oxmysql release page).
4. Start the server. The first join and the owner setting in `server.cfg` both give you admin. See "Getting owner" below.

The recipe and `dev/server.cfg.template` start the same resources. The integrity check fails if they ever differ.

## Getting owner (admin) on a new server
1. The first account to join an empty server is made owner automatically.
2. Or set `set nexoro_owner_license "license:YOUR_LICENSE"` in server.cfg, then restart.
3. If there is still no owner, a six-digit code appears in the server console on start. In game, type `/claimowner CODE`.
4. Type `/mystaff` to check your rank. The staff menu is F9 or `/admin`.

## Install on a development server
1. Install FiveM server artifacts and a MariaDB 10.6+ database.
2. Download oxmysql into `resources/` and create an empty database.
3. Copy the `[nexoro]` folder into `resources/`.
4. Use `dev/server.cfg.template` as your starting `server.cfg` (set the licence key and connection string).
5. Start the server. Run `nexoro_doctor` in the console: it tells you in plain English what to fix.
6. Join, then in the server console run `nexoro_setrank <your server id> owner`.

Migrations run automatically on start. Do not edit applied migration files; add new ones.

## Status: be clear about what is proven
**Proven offline (1,680 automated checks, real MariaDB 10.11):** dispatch calls, assignment rules, unit status transitions, radio access, tablet app filtering and call allowlists, lightbar ownership and model checks, plus every emergency permission by rank, duty and off-duty lockout, callsign uniqueness, hiring and rank rules, arrest and fine maths (no negative balances), warrant and evidence chains, revive cooldowns, admissions and billing, incident state changes, hazard expiry, plus vehicle ownership, plates, anti-duplication spawning, state sanity checks, fuel/insurance/MOT/finance/impound maths, transfers and race conditions, plus phone numbers/contacts/SMS/calls/mail/adverts/social/battery rules, HUD needs, plus migrations, validation, money safety, atomic transfers, inventory rules (weight, stacking, moves, rollback on failure), chat prefixes/channels/spam, every admin permission and hierarchy rule, bans and the connect hook, audit logs. See `docs/TESTING.md`.

**NOT yet proven (needs a live FiveM server):** all client-side effects (noclip, spectate, vehicle spawn, teleport to waypoint, weather/time), natives and camera scene, NUI rendering for every screen, model/appearance application, oxmysql runtime behaviour, export multi-return values, state bags, spawn flow. The manual checklist in `docs/TESTING.md` covers these. Treat Phase 1 as beta until it is ticked off on a real server.

## Known gaps (documented, not hidden)
- Tablet: no PIN or password lock. Access is gated by holding the item and the permissions for each app. A PIN needs a proper password hash, and Lua has none built in, so this is deliberately left for a later step rather than faked with a weak hash.
- Lighting: the server checks the model, the on-duty service and who set the lights. It does not check that the requester is actually driving the vehicle (server-side seat checks are not reliable across OneSync). Airhorn is local only. Primary and secondary siren tones are not switched yet.
- Dispatch: 999 calls do not capture a spoken description, so operators add it. Unit status lives in memory and rebuilds from duty state after a restart. Multiple-unit radio talk groups depend on pma-voice being installed.
- Hazard zones and lightbar state reset on restart.
- Emergency departments use FICTIONAL names. The brief listed real police, NHS and fire service names. Do not use real service names, crests or branding without permission: it can imply official affiliation. Rename in `nexoro_emergency/config.lua`.
- Police: no roadblocks, spike strips, prisoner transport or prison (Phase 7), no body cameras or CCTV yet. Breath tests read `alcohol` metadata; nothing sets it until drink items are added.
- Ambulance: no stretchers, wheelchairs, carrying or hospital beds UI yet. Medical supplies are bandages only.
- Fire: no appliance allocation or crew lists yet; hazard zones reset on server restart. Dispatch (999 calls creating incidents) is Phase 6.
- Uniform component IDs in `nexoro_emergency/config.lua` are placeholders and must be tuned in-game.
- Duty uniforms only work when `nexoro_character` is running (it restores civilian clothes from its appearance export).
- Salaries are per payday (every 15 minutes by default), so tune them against your economy.
- Vehicles: no mechanic repairs, vehicle modification shops or tuning UI yet (Phase 7 mechanic job calls `AdminRepair`-style server APIs). Boot/glovebox storage UI arrives with the inventory stash UI. Garage, dealership, pump and MOT coordinates are placeholders: check and adjust them in-game.
- Vehicle fuel and mileage run on the client and are checked on the server (values can only get worse, mileage growth is capped). A determined cheater can still burn no fuel locally; pair with an anti-cheat.
- Police plate lookups use `exports.nexoro_vehicles:LookupPlate` (the police MDT arrives in Phase 6).
- Phone: Camera and Gallery need a screenshot resource; Gov, Cars, Homes and Business apps arrive with their systems (tiles are shown greyed out). Call audio needs pma-voice (`Config.Phone.Voice`); without it calls only signal.
- Loading screen: no music file or artwork is bundled (you need the rights). Add `html/audio/theme.mp3` and optionally `html/img/background.jpg`; edit `html/config.js` for your branding.
- HUD: radio shows only if a voice resource sets `LocalPlayer.state.radioChannel`; fuel uses the native fuel level until the vehicles phase adds fuel.
- UI system and every NUI screen are untested in a live client (only their server logic and JavaScript syntax are checked offline).
- Progress bars, context menus, input dialogs, text UI: Phase 3 (UI system).
- Banking has no ATM/branch locations or card UI yet (Phase 3 phone and Phase 7 locations); the callbacks work from anywhere until then.
- Inventory: no ground drops, player-to-player give, vehicle boot/glovebox or house storage UI yet (the stash API exists; UIs arrive with vehicles/housing). Item icons are placeholders (drop PNGs in `nexoro_inventory/html/img/<item>.png`).
- Chat: no radio channels (Phase 6). Admin menu: no reports queue or dispatch tiles (Phase 8 / Phase 6), no vehicle ownership tools (Phase 4), no player-owned business tools (Phase 7).
- Admin client-side effects (noclip, god mode, invisibility) are applied by the client after the server approves; a cheating client can toggle its own, so pair Nexoro with an anti-cheat.
- A separate custom txAdmin-style panel is on the roadmap; the audit log, permission API and `Execute` export are designed for it.
- Database backup tooling: Phase 9.
- Preview scene coordinates in `nexoro_character/config.lua` need an in-game check.
- Character preview uses the player's own ped inside a private routing bucket; verify on your build.

## Docs
`docs/API.md` developer API, events, callbacks, permissions. `docs/TESTING.md` results and checklist. `CHANGELOG.md`.


For a test server with frequent re-uploads, see docs/TEST_WORKFLOW.md.
