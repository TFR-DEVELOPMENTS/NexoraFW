local cfg = Config.Inventory
local isOpen = false

local function setOpen(open)
    isOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = open and 'open' or 'close' })
end

local function refresh()
    local ok, data = NexoroCore.Callback('nexoro_inventory:get')
    if ok then SendNUIMessage({ action = 'update', inventory = data }) end
    return ok
end

local function toggle()
    if isOpen then return setOpen(false) end
    local okLoaded, loaded = pcall(function() return exports.nexoro_core:IsCharacterLoaded() end)
    if not okLoaded or not loaded or IsEntityDead(PlayerPedId()) then return end
    if refresh() then setOpen(true) end
end

RegisterCommand('inventory', function() toggle() end, false)

local function quickUse(slot)
    if isOpen then return end
    CreateThread(function() NexoroCore.Callback('nexoro_inventory:use', { slot = slot }) end)
end

CreateThread(function()
    while GetResourceState('nexoro_core') ~= 'started' do Wait(200) end
    exports.nexoro_core:RegisterKeybind('inventory', 'Open inventory', cfg.OpenKey, toggle)
    for i, key in ipairs(cfg.QuickSlotKeys) do
        exports.nexoro_core:RegisterKeybind('quickslot' .. i, ('Use item in slot %d'):format(i), key, function() quickUse(i) end)
    end
end)

RegisterNetEvent('nexoro_inventory:update', function(inventory)
    if isOpen then SendNUIMessage({ action = 'update', inventory = inventory }) end
end)

RegisterNetEvent('nexoro:client:heal', function(amount)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + (tonumber(amount) or 0)))
end)

AddEventHandler('nexoro:client:characterUnloadedLocal', function() if isOpen then setOpen(false) end end)

RegisterNUICallback('move', function(data, cb)
    local ok, err = NexoroCore.Callback('nexoro_inventory:move', { from = data.from, to = data.to, amount = data.amount })
    cb({ ok = ok, error = not ok and err or nil })
end)

RegisterNUICallback('use', function(data, cb)
    local ok, err = NexoroCore.Callback('nexoro_inventory:use', { slot = data.slot })
    cb({ ok = ok, error = not ok and err or nil })
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

-- Block combat/look controls while the inventory is open.
CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
            DisableControlAction(0, 142, true); DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
