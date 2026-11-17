Nexoro = Nexoro or {}

local queue = {}
local flushing = false
local cfg = Config.Logging

-- category: 'economy', 'security', 'character', 'permissions', ...
-- src may be nil (system event). data is any JSON-encodable table.
function Nexoro.Log(category, action, src, data)
    category = tostring(category):sub(1, 32)
    action = tostring(action):sub(1, 64)

    local license, characterId = 'system', 0
    local player = src and Nexoro.Players and Nexoro.Players[src]
    if player then
        license = player.license
        characterId = player.character and player.character.id or 0
    end

    local encoded = ''
    if data ~= nil then
        local ok, result = pcall(json.encode, data)
        encoded = ok and result:sub(1, 8000) or ''
    end

    if cfg.Console then
        print(('^5[Nexoro][%s]^7 %s %s %s'):format(category, action, src and ('src=' .. tostring(src)) or '', encoded:sub(1, 200)))
    end
    if cfg.Database then
        queue[#queue + 1] = { category, action, license, characterId, encoded }
        if #queue >= cfg.BatchSize then CreateThread(Nexoro.FlushLogs) end
    end
end

function Nexoro.FlushLogs()
    if flushing or #queue == 0 then return end
    flushing = true
    local batch = queue
    queue = {}

    local placeholders, params = {}, {}
    for i, entry in ipairs(batch) do
        placeholders[i] = '(?,?,?,?,?)'
        for j = 1, 5 do params[#params + 1] = entry[j] end
    end
    local _, err = NexoroDB.query(
        'INSERT INTO nexoro_logs (category, action, license, character_id, data) VALUES ' .. table.concat(placeholders, ','),
        params)
    if err then print(('^1[Nexoro] failed to write %d log entries^7'):format(#batch)) end
    flushing = false
end

CreateThread(function()
    while true do
        Wait(cfg.FlushIntervalMs)
        Nexoro.FlushLogs()
    end
end)
