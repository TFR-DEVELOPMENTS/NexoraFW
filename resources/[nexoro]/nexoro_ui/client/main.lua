local modal = nil           -- { kind = 'context'|'input'|'confirm'|'alert', cb = function }
local contexts = {}
local currentContext = nil
local progress = nil        -- { cancelled = bool }

local function focus(on) SetNuiFocus(on, on) end

local function closeModal(result)
    if not modal then return end
    local m = modal
    modal = nil
    focus(false)
    SendNUIMessage({ action = 'closeModal' })
    if m.cb then m.cb(result) end
end

local function openModal(kind, payload, cb)
    if modal then closeModal(nil) end
    modal = { kind = kind, cb = cb }
    payload.action = 'open' .. kind
    SendNUIMessage(payload)
    focus(true)
end

---------------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------------

local function runProgress(opts, cb)
    if progress then return cb(false) end
    opts = type(opts) == 'table' and opts or {}
    local duration = math.min(math.max(tonumber(opts.duration) or 3000, 200), 600000)
    local disable = opts.disable or { move = false, car = true, combat = true }
    local canCancel = opts.canCancel ~= false
    progress = { cancelled = false }
    local current = progress
    SendNUIMessage({ action = 'progressStart', label = tostring(opts.label or 'Working'):sub(1, 60), duration = duration, canCancel = canCancel })

    local ped = PlayerPedId()
    if type(opts.anim) == 'table' and opts.anim.dict and opts.anim.clip then
        RequestAnimDict(opts.anim.dict)
        local deadline = GetGameTimer() + 3000
        while not HasAnimDictLoaded(opts.anim.dict) and GetGameTimer() < deadline do Wait(0) end
        TaskPlayAnim(ped, opts.anim.dict, opts.anim.clip, 3.0, 3.0, -1, opts.anim.flag or 49, 0, false, false, false)
    end

    CreateThread(function()
        local finishAt = GetGameTimer() + duration
        while GetGameTimer() < finishAt and not current.cancelled do
            if disable.move then DisableControlAction(0, 30, true); DisableControlAction(0, 31, true); DisableControlAction(0, 21, true) end
            if disable.car then DisableControlAction(0, 63, true); DisableControlAction(0, 64, true); DisableControlAction(0, 71, true); DisableControlAction(0, 72, true) end
            if disable.combat then DisableControlAction(0, 24, true); DisableControlAction(0, 25, true); DisablePlayerFiring(PlayerId(), true) end
            if canCancel and IsControlJustPressed(0, 73) then current.cancelled = true end
            if IsEntityDead(PlayerPedId()) then current.cancelled = true end
            Wait(0)
        end
        if opts.anim and opts.anim.dict then ClearPedTasks(PlayerPedId()) end
        progress = nil
        SendNUIMessage({ action = 'progressEnd', cancelled = current.cancelled })
        cb(not current.cancelled)
    end)
end

---------------------------------------------------------------------------
-- Context menus
---------------------------------------------------------------------------

local function sanitiseOptions(options)
    local out = {}
    for i, o in ipairs(options or {}) do
        out[i] = {
            title = tostring(o.title or ''):sub(1, 80), description = o.description and tostring(o.description):sub(1, 200) or nil,
            icon = o.icon and tostring(o.icon):sub(1, 4) or nil, disabled = o.disabled == true, arrow = o.arrow == true or o.menu ~= nil,
            metadata = o.metadata, progress = tonumber(o.progress),
        }
    end
    return out
end

local function showContext(id)
    local def = contexts[id]
    if not def then return false end
    currentContext = id
    openModal('context', { title = tostring(def.title or ''):sub(1, 60), back = def.menu ~= nil, options = sanitiseOptions(def.options) }, nil)
    return true
end

RegisterNUICallback('contextSelect', function(data, cb)
    cb({ ok = true })
    local def = contexts[currentContext]
    local option = def and def.options[tonumber(data.index)]
    if not option or option.disabled then return end
    if option.menu then return showContext(option.menu) end
    closeModal(nil)
    if option.onSelect then
        local ok, err = pcall(option.onSelect, option.args)
        if not ok then print(('^1[Nexoro] context onSelect error: %s^7'):format(tostring(err))) end
    elseif option.event then
        TriggerEvent(option.event, option.args)
    elseif option.serverEvent and tostring(option.serverEvent):match('^[%w_:%-]+$') then
        TriggerServerEvent(option.serverEvent, option.args)
    end
end)

RegisterNUICallback('contextBack', function(_, cb)
    cb({ ok = true })
    local def = contexts[currentContext]
    if def and def.menu and contexts[def.menu] then showContext(def.menu) else closeModal(nil) end
end)

---------------------------------------------------------------------------
-- Modal results
---------------------------------------------------------------------------

RegisterNUICallback('modalResult', function(data, cb)
    cb({ ok = true })
    closeModal(data.result)
end)

RegisterNUICallback('modalCancel', function(_, cb)
    cb({ ok = true })
    if modal then
        local kind = modal.kind
        closeModal(kind == 'confirm' and false or nil)
    end
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

exports('Progress', runProgress)
exports('CancelProgress', function() if progress then progress.cancelled = true end end)
exports('IsProgressActive', function() return progress ~= nil end)

exports('Input', function(def, cb)
    def = type(def) == 'table' and def or {}
    local fields = {}
    for i, f in ipairs(def.fields or {}) do
        if i > 12 then break end
        fields[i] = {
            type = ({ input = true, number = true, select = true, checkbox = true, textarea = true })[f.type] and f.type or 'input',
            name = tostring(f.name or ('field' .. i)):sub(1, 30), label = tostring(f.label or ''):sub(1, 60), required = f.required == true,
            default = f.default, options = f.options, min = f.min, max = f.max, step = f.step, placeholder = f.placeholder and tostring(f.placeholder):sub(1, 80) or nil,
            maxLength = tonumber(f.maxLength),
        }
    end
    openModal('input', { title = tostring(def.title or 'Input'):sub(1, 60), submitLabel = def.submitLabel, fields = fields }, cb)
end)
exports('Confirm', function(def, cb)
    def = type(def) == 'table' and def or {}
    openModal('confirm', { title = tostring(def.title or 'Are you sure?'):sub(1, 60), text = tostring(def.text or ''):sub(1, 400), confirmLabel = def.confirmLabel, cancelLabel = def.cancelLabel, danger = def.danger == true }, cb)
end)
exports('Alert', function(def, cb)
    def = type(def) == 'table' and def or {}
    openModal('alert', { title = tostring(def.title or 'Information'):sub(1, 60), text = tostring(def.text or ''):sub(1, 2000), buttonLabel = def.buttonLabel }, cb or function() end)
end)

exports('RegisterContext', function(def)
    if type(def) ~= 'table' or type(def.id) ~= 'string' then return false end
    contexts[def.id] = def
    return true
end)
exports('ShowContext', showContext)
exports('HideContext', function() if modal and modal.kind == 'context' then closeModal(nil) end end)
exports('CloseAll', function() closeModal(nil) end)

local textVisible = false
exports('ShowTextUI', function(text, key)
    textVisible = true
    SendNUIMessage({ action = 'textShow', text = tostring(text or ''):sub(1, 100), key = key and tostring(key):sub(1, 8) or nil })
end)
exports('HideTextUI', function()
    if textVisible then textVisible = false; SendNUIMessage({ action = 'textHide' }) end
end)
exports('IsTextUIOpen', function() return textVisible end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and modal then focus(false) end
end)
