Nexoro = Nexoro or {}
Nexoro.Jobs = {}

function Nexoro.LoadJobs()
    local jobs = NexoroDB.query('SELECT name, label, category, is_whitelisted FROM nexoro_jobs WHERE enabled = 1') or {}
    local grades = NexoroDB.query('SELECT job_name, grade, label, salary_pence, permissions FROM nexoro_job_grades ORDER BY job_name, grade') or {}
    local loaded = {}
    for _, job in ipairs(jobs) do
        loaded[job.name] = { name = job.name, label = job.label, category = job.category, whitelisted = job.is_whitelisted == 1 or job.is_whitelisted == true, grades = {} }
    end
    for _, g in ipairs(grades) do
        local job = loaded[g.job_name]
        if job then
            local perms = {}
            if g.permissions and g.permissions ~= '' then
                local ok, decoded = pcall(json.decode, g.permissions)
                if ok and type(decoded) == 'table' then perms = decoded end
            end
            job.grades[g.grade] = { label = g.label, salaryPence = g.salary_pence, permissions = perms }
        end
    end
    Nexoro.Jobs = loaded
    return loaded
end

-- Used by nexoro_jobs (Phase 5) and third-party resources to create or update a job definition.
-- def = { name, label, category, whitelisted, grades = { [0] = { label, salary (pounds), permissions }, ... } }
function Nexoro.RegisterJob(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' or not def.name:match('^[a-z0-9_]+$') or #def.name > 50 then
        return false, 'invalid_name'
    end
    if type(def.label) ~= 'string' or def.label == '' or #def.label > 80 then return false, 'invalid_label' end
    if type(def.grades) ~= 'table' or next(def.grades) == nil then return false, 'no_grades' end

    local category = type(def.category) == 'string' and def.category:sub(1, 24) or 'civilian'
    local _, err = NexoroDB.query(
        'INSERT INTO nexoro_jobs (name, label, category, is_whitelisted) VALUES (?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE label = VALUES(label), category = VALUES(category), is_whitelisted = VALUES(is_whitelisted)',
        { def.name, def.label, category, def.whitelisted and 1 or 0 })
    if err then return false, 'database_error' end

    for grade, g in pairs(def.grades) do
        local gradeNumber = Nexoro.Utils.ToInt(grade)
        local pence = Nexoro.Utils.ToPence(g.salary or 0)
        if not gradeNumber or gradeNumber < 0 or gradeNumber > 255 or not pence or pence > 4294967295 then return false, 'invalid_grade' end
        NexoroDB.query(
            'INSERT INTO nexoro_job_grades (job_name, grade, label, salary_pence, permissions) VALUES (?, ?, ?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE label = VALUES(label), salary_pence = VALUES(salary_pence), permissions = VALUES(permissions)',
            { def.name, gradeNumber, tostring(g.label or ('Grade ' .. gradeNumber)):sub(1, 60), pence, json.encode(g.permissions or {}) })
    end
    Nexoro.LoadJobs()
    return true
end
