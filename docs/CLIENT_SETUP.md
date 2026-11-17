# Player setup (client-side)

Some things a player has to install on their own PC. The server cannot install them.

## Required for the framework
- None. FiveM and the Nexoro server resources are enough.

## Recommended: Realistic Handling for Vanilla Vehicles (Taira)
- Credit: Taira (realistichandlingbyTaira). Source: the author's GitHub and the Cfx forum thread "[FREE] Realistic Handling Pack Vanilla Vehicles". The author asks that you mention them when you share or stream it.
- A FiveM resource. Install the folder into your server's resources and `ensure` it. Players download it from the server automatically. Nobody installs anything on their PC.
- Covers stock cars only (for example Bravado Bison, Bravado Rumpo, Declasse Burrito, Karin Sultan, Benefactor Panto), so it doesn't touch the Lore Friendly pack cars.
- Not yet tested in Nexoro. Test it with the dealership cars, the stock vans and the police cars.

## Optional: realistic handling (Vehicle Handling V)
- Author: Cass. Page: https://www.gta5-mods.com/vehicles/vehicle-handling-v
- This changes GTA's own game files, so it applies on every server a player joins. Install it with OpenIV, following the READ ME included with the download.
- The author asks that the mod not be copied or redistributed. Players should download it from the author's page, not from the Nexoro repository.
- Check before sending it to players: the page's last update is 2017, and some comments say newer versions are paid or early access. Confirm which version is free and works with the current game build (the server pins sv_enforceGameBuild 3095).
- Players who use it should test a few cars: the mod changes top speed, damage and traction.

## Optional: Lore-Friendly car pack (SpiritsCreations)
- Source: https://github.com/SpiritsCreations/FiveM-Lore-Friendly-Pack
- Installed on the server as the resource `Lore-Friendly-Car-Pack`. Players download the cars automatically from the server.
- The pack's licence: no hosting elsewhere, no selling or monetising. It is for private use only.
- The pack's README says some cars need sv_enforceGameBuild 3258.

## Conflicts
- Handling mods and vehicle packs may have competing handling lines. Test any combination before you use it with players.
