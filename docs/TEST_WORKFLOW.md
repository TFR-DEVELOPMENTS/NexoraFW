# Test server workflow (re-uploading resources and refreshing the database)

For a test server only. Never turn dev mode on a live server.

## Set up once
1. In server.cfg, uncomment `set nexoro_devmode "true"`.
2. Start the server. The console prints a nine-digit reset token. Keep it to hand.

## Each time you upload new resources
1. Stop the server.
2. Replace the changed resource folders in `resources/`.
3. Start the server.
4. In the console, check for errors from the Nexoro resources.
5. In game, as the owner, run `/devselfcheck`. It tests the database, the core tables, the owner, and whether every Nexoro resource started. Failures are listed in the console with the reason.

## Refresh the database (wipes all Nexoro data)
1. In the server console, run `nexoro_dbreset <token>` (the token from startup). This drops every Nexoro table.
2. Stop the server, then start it again. The migrations rebuild the tables.
3. Join. You are owner again on an empty server.
4. Run `/devselfcheck`.

The token works once. A new one is printed at each startup while dev mode is on.

## Quick test setup in game (owner only, dev mode on)
- `/devmoney 5000 bank` or `/devmoney 500 cash`
- `/devitem lockpick 5` (or any item name from the item list)
- `/devjob caledonia_police 1` to try a job, or `/devjob scrapper 0`
- `/devtp legion`, `/devtp council`, `/devtp pawn`, `/devtp hospital`, `/devtp paleto`, `/devtp sandy`, `/devtp farm`
- `/devheal`
Locations are in `nexoro_devtools/config.lua`.

## What to check after a big upload
- `/devselfcheck` passes every line
- the new resource appears in the server console without errors
- the feature's checklist in `docs/TESTING.md`
