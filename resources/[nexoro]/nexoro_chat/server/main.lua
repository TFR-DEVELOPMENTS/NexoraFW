local cfg = Config.Chat
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroChat = {}
local history = {}
local lastSent, recent, lastText, muted = {}, {}, {}, {}
local nextId = 0

-- Overridable for tests; returns x, y, z of a player's ped on the server.
NexoroChat.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return c.x, c.y, c.z
end

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function clean(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('[\0-\8\11\12\14-\31\127]', '')
    text = trim(text):gsub('%s+', ' ')
    if text == '' or not utf8.len(text) then return nil end
    if utf8.len(text) > cfg.MaxLength then text = text:sub(1, utf8.offset(text, cfg.MaxLength + 1) - 1) end
    return text
end

local function filterProfanity(text)
    if not cfg.Profanity.enabled then return text end
    for _, word in ipairs(cfg.Profanity.words) do
        text = text:gsub('%f[%a]' .. word .. '%f[%A]', function(w) return ('*'):rep(#w) end)
        local cap = word:sub(1, 1):upper() .. word:sub(2)
        text = text:gsub('%f[%a]' .. cap .. '%f[%A]', function(w) return ('*'):rep(#w) end)
        text = text:gsub('%f[%a]' .. word:upper() .. '%f[%A]', function(w) return ('*'):rep(#w) end)
    end
    return text
end

-- The prefix comes ONLY from the server-side job record.
function NexoroChat.GetPrefix(src)
    local job = core().GetJob(src)
    local rule = cfg.Prefixes.default
    if job then
        rule = cfg.Prefixes.byName[job.name] or cfg.Prefixes.byCategory[job.category] or cfg.Prefixes.default
        if rule.requireDuty and not job.onDuty then rule = cfg.Prefixes.default end
    end
    return { label = rule.label, colour = rule.colour }
end

local function displayName(src)
    local c = core().GetCharacter(src)
    return c and (c.firstName .. ' ' .. c.lastName) or 'Unknown'
end

local function timestamp() return os.date('%H:%M') end

local function distanceBetween(a, b)
    local ax, ay, az = NexoroChat.getCoords(a)
    local bx, by, bz = NexoroChat.getCoords(b)
    if not ax or not bx then return math.huge end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2 + (az - bz) ^ 2)
end

function NexoroChat.Mute(src, seconds)
    muted[src] = os.time() + (seconds or 600)
end
function NexoroChat.Unmute(src) muted[src] = nil end
function NexoroChat.IsMuted(src) return muted[src] and muted[src] > os.time() end

-- Radio channel a player is tuned to (set by nexoro_dispatch), or nil.
local function radioOf(src)
    if GetResourceState('nexoro_dispatch') ~= 'started' then return nil end
    local ok, ch = pcall(function() return exports.nexoro_dispatch:GetRadioChannel(src) end)
    return ok and ch or nil
end

local function recipientsFor(src, def, channel, target)
    local out = {}
    local me = core().GetCharacter(src)
    local myRadio = def.radio and radioOf(src) or nil
    for _, p in ipairs(core().GetPlayers()) do
        if p.hasCharacter then
            local ok = false
            if channel == 'global' then ok = true
            elseif channel == 'pm' then ok = (p.source == target or p.source == src)
            elseif def.distance then ok = (p.source == src) or distanceBetween(src, p.source) <= def.distance
            elseif def.permission then ok = core().HasPermission(p.source, def.permission)
            elseif def.emergency then
                local j = core().GetJob(p.source)
                ok = j and cfg.EmergencyCategories[j.category] and true or false
            elseif def.radio then ok = myRadio ~= nil and radioOf(p.source) == myRadio
            elseif def.department then ok = (p.job == me.job)
            end
            if ok then out[#out + 1] = p.source end
        end
    end
    return out
end

-- Returns true | false, errorCode. Never trusts anything but the channel name and text from the client.
function NexoroChat.Send(src, channel, text, target)
    local def = type(channel) == 'string' and cfg.Channels[channel]
    if not def then return false, 'unknown_channel' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    if NexoroChat.IsMuted(src) then return false, 'muted' end

    text = clean(text)
    if not text then return false, 'empty_message' end

    if def.permission and not core().HasPermission(src, def.permission) then return false, 'forbidden' end
    local job = core().GetJob(src)
    if def.emergency and not (job and cfg.EmergencyCategories[job.category] and job.onDuty) then return false, 'not_emergency_service' end
    if def.department and (not job or job.name == 'unemployed') then return false, 'no_department' end
    if def.radio and not radioOf(src) then return false, 'not_on_radio' end
    if channel == 'pm' then
        target = math.tointeger(tonumber(target))
        if not target or not core().GetCharacter(target) then return false, 'target_not_found' end
    end

    local now = GetGameTimer()
    local key = src .. ':' .. channel
    if lastSent[key] and now - lastSent[key] < def.cooldownMs then return false, 'cooldown' end
    local window = recent[src] or {}
    local fresh = {}
    for _, t in ipairs(window) do if now - t < cfg.Spam.windowMs then fresh[#fresh + 1] = t end end
    if #fresh >= cfg.Spam.maxMessages then
        NexoroChat.Mute(src, cfg.Spam.muteSecondsOnSpam)
        core().Log('chat', 'auto_muted_spam', src, {})
        return false, 'spam_muted'
    end
    local last = lastText[src]
    if last and last.text == text and now - last.at < cfg.Spam.duplicateWindowMs then return false, 'duplicate' end
    fresh[#fresh + 1] = now
    recent[src], lastSent[key], lastText[src] = fresh, now, { text = text, at = now }

    nextId = nextId + 1
    local message = {
        id = nextId, time = timestamp(), channel = channel, channelLabel = def.label, channelColour = def.colour,
        prefix = NexoroChat.GetPrefix(src), name = displayName(src), text = filterProfanity(text), action = def.action or false,
    }
    if channel == 'staff' then message.prefix = { label = 'STAFF', colour = '#f472b6' } end
    if channel == 'pm' then message.pmTo = displayName(target) end
    if channel == 'radio' then message.channelLabel = 'RADIO ' .. tostring(radioOf(src)) end

    for _, dest in ipairs(recipientsFor(src, def, channel, target)) do
        TriggerClientEvent('nexoro_chat:message', dest, message)
    end
    if channel == 'global' then
        history[#history + 1] = message
        if #history > cfg.HistorySize then table.remove(history, 1) end
    end
    core().Log('chat', channel, src, { text = text:sub(1, 120) })
    return true
end

function NexoroChat.System(src, text, colour)
    TriggerClientEvent('nexoro_chat:message', src, { id = 0, time = timestamp(), channel = 'system', channelLabel = 'SYSTEM', channelColour = colour or '#FFCC00', prefix = { label = 'Nexoro', colour = '#FFCC00' }, name = '', text = tostring(text):sub(1, 400) })
end

function NexoroChat.Announce(text)
    for _, p in ipairs(core().GetPlayers()) do
        TriggerClientEvent('nexoro_chat:message', p.source, { id = 0, time = timestamp(), channel = 'announcement', channelLabel = 'ANNOUNCEMENT', channelColour = '#FFCC00', prefix = { label = 'SERVER', colour = '#FFCC00' }, name = '', text = tostring(text):sub(1, 300) })
    end
end

local ERRORS = {
    cooldown = 'You are sending messages too quickly.', duplicate = 'Please do not repeat the same message.',
    spam_muted = 'You have been muted briefly for spamming.', muted = 'You are muted.', forbidden = 'You do not have access to that channel.',
    not_emergency_service = 'You must be on duty with an emergency service to use that channel.', no_department = 'You are not in a department.',
    target_not_found = 'That player was not found.', empty_message = 'Type a message first.', not_on_radio = 'You are not on a radio channel. Use /radio <channel>.',
}

local function register()
    Core = nil
    core().RegisterSecureEvent('nexoro_chat:send', { requireCharacter = true, rateLimit = { max = 20, windowMs = 10000 } }, function(src, channel, text, target)
        local ok, err = NexoroChat.Send(src, channel, text, target)
        if not ok then core().Notify(src, ERRORS[err] or 'Message not sent.', 'warning', 3000) end
    end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:characterLoaded', function(src)
    for _, m in ipairs(history) do TriggerClientEvent('nexoro_chat:message', src, m) end
end)
AddEventHandler('nexoro:server:playerDropped', function(src)
    lastSent[src], recent[src], lastText[src], muted[src] = nil, nil, nil, nil
    for k in pairs(lastSent) do if tostring(k):match('^' .. src .. ':') then lastSent[k] = nil end end
end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Send', function(src, channel, text, target) return NexoroChat.Send(src, channel, text, target) end)
exports('Announce', NexoroChat.Announce)
exports('System', NexoroChat.System)
exports('Mute', NexoroChat.Mute)
exports('Unmute', NexoroChat.Unmute)
exports('IsMuted', function(src) return NexoroChat.IsMuted(src) and true or false end)
exports('GetPrefix', NexoroChat.GetPrefix)

-- Dispatch and automated chatter to everyone tuned to a radio channel.
function NexoroChat.RadioBroadcast(channel, text, senderName)
    local msg = {
        id = 0, time = timestamp(), channel = 'radio', channelLabel = 'RADIO ' .. tostring(channel), channelColour = '#fbbf24',
        prefix = { label = 'DISPATCH', colour = '#fbbf24' }, name = senderName or 'Dispatch', text = tostring(text):sub(1, 240), action = false,
    }
    for _, p in ipairs(core().GetPlayers()) do
        if p.hasCharacter and radioOf(p.source) == channel then TriggerClientEvent('nexoro_chat:message', p.source, msg) end
    end
    return true
end
exports('RadioBroadcast', NexoroChat.RadioBroadcast)
