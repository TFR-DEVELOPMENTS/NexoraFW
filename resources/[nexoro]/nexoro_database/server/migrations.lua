NexoroMigrations = {}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function checksum(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return string.format('%08x', h)
end

-- Statements are separated by a line containing only "-- @@".
-- Full-line "--" comments are stripped before execution.
function NexoroMigrations.Split(sql)
    sql = sql:gsub('\r\n', '\n')
    local statements = {}
    for chunk in (sql .. '\n-- @@\n'):gmatch('(.-)\n%-%- @@\n') do
        local lines = {}
        for line in (chunk .. '\n'):gmatch('(.-)\n') do
            if not line:match('^%s*%-%-') then lines[#lines + 1] = line end
        end
        local stmt = trim(table.concat(lines, '\n'))
        stmt = trim((stmt:gsub(';%s*$', '')))
        if stmt ~= '' then statements[#statements + 1] = stmt end
    end
    return statements
end

local function discover()
    local found, seen = {}, {}
    for _, name in ipairs(Config.MigrationOrder) do
        if GetResourceState(name) ~= 'missing' then
            found[#found + 1] = name
            seen[name] = true
        end
    end
    local extra = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and name:sub(1, 5) == 'nexoro_' and not seen[name] then extra[#extra + 1] = name end
    end
    table.sort(extra)
    for _, name in ipairs(extra) do found[#found + 1] = name end
    return found
end

local function apply(resource, file)
    if not file:match('^[%w_%-%.]+%.sql$') then
        return false, ('invalid migration file name "%s" in %s'):format(file, resource)
    end
    local sql = LoadResourceFile(resource, 'sql/migrations/' .. file)
    if not sql then return false, ('migration file missing: %s/sql/migrations/%s'):format(resource, file) end

    local sum = checksum(sql)
    local row = NexoroDB.single('SELECT checksum FROM nexoro_schema_migrations WHERE resource = ? AND name = ?', { resource, file })
    if row then
        if row.checksum ~= sum then
            print(('^3[Nexoro][migrate] WARNING: %s/%s changed after being applied. Add a new migration instead of editing old ones.^7'):format(resource, file))
        end
        return true, false
    end

    for index, statement in ipairs(NexoroMigrations.Split(sql)) do
        local _, err = NexoroDB.query(statement)
        if err then
            return false, ('%s/%s failed at statement %d: %s'):format(resource, file, index, err)
        end
    end
    local _, err = NexoroDB.insert('INSERT INTO nexoro_schema_migrations (resource, name, checksum) VALUES (?, ?, ?)', { resource, file, sum })
    if err then return false, err end
    print(('^2[Nexoro][migrate] applied %s/%s^7'):format(resource, file))
    return true, true
end

function NexoroMigrations.Run()
    local _, err = NexoroDB.query([[
        CREATE TABLE IF NOT EXISTS nexoro_schema_migrations (
            resource   VARCHAR(64)  NOT NULL,
            name       VARCHAR(128) NOT NULL,
            checksum   CHAR(8)      NOT NULL,
            applied_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (resource, name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if err then return false, 0, err end

    local appliedCount = 0
    for _, resource in ipairs(discover()) do
        local raw = LoadResourceFile(resource, 'sql/migrations.json')
        if raw then
            local okJson, list = pcall(json.decode, raw)
            if not okJson or type(list) ~= 'table' then
                return false, appliedCount, ('invalid sql/migrations.json in ' .. resource)
            end
            for _, file in ipairs(list) do
                local ok, result = apply(resource, file)
                if not ok then return false, appliedCount, result end
                if result == true then appliedCount = appliedCount + 1 end
            end
        end
    end
    return true, appliedCount
end
