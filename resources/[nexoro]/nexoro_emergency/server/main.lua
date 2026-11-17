local cfg = Config.Emergency
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroEmergency = {}
local E = NexoroEmergency
E.departments = {}   -- [jobName] = { label, prefix, template }

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

-- Cumulative: every tier whose minGrade is at or below the grade applies.
local function permsFor(template, grade)
    local out = {}
    for _, tier in ipairs(template.perms) do
        if grade >= tier.minGrade then
            for _, p in ipairs(tier.list) do out[#out + 1] = p end
        end
    end
    return out
end

function E.Definitions()
    local defs = {}
    for _, dept in ipairs(cfg.Departments) do
        local template = cfg.Templates[dept.template]
        if template then
            local def = { name = dept.job, label = dept.label, category = template.category, whitelisted = true, grades = {} }
            for i, rank in ipairs(template.ranks) do
                def.grades[i - 1] = { label = rank.label, salary = rank.salary, permissions = permsFor(template, i - 1) }
            end
            defs[#defs + 1] = { def = def, dept = dept, template = template }
        end
    end
    return defs
end

-- Writes every department's jobs and ranks to the database. Safe to run again.
function E.RegisterAll()
    local count = 0
    for _, item in ipairs(E.Definitions()) do
        if core().RegisterJob(item.def) then
            E.departments[item.dept.job] = { label = item.dept.label, prefix = item.dept.prefix, template = item.template }
            count = count + 1
        end
    end
    return count
end

function E.Department(jobName) return E.departments[jobName] end

-- The single permission check used by police, ambulance and fire modules.
-- Requires the player to be in a department and (unless allowOffDuty) on duty.
function E.HasPerm(src, perm, allowOffDuty)
    if type(perm) ~= 'string' then return false end
    local job = core().GetJob(src)
    if not job or not E.departments[job.name] then return false end
    if not allowOffDuty and not job.onDuty then return false end
    for _, p in ipairs(core().GetGradePermissions(job.name, job.grade)) do
        if p == perm then return true end
    end
    return false
end

function E.ToggleDuty(src)
    local job = core().GetJob(src)
    local d = job and E.departments[job.name]
    if not d then return false, 'not_emergency' end
    if not E.HasPerm(src, d.template.dutyPerm, true) then return false, 'forbidden' end
    local onDuty = not job.onDuty
    core().SetDuty(src, onDuty)
    core().Log('emergency', onDuty and 'on_duty' or 'off_duty', src, { job = job.name })
    return true, { onDuty = onDuty }
end

function E.SetCallsign(src, value)
    local job = core().GetJob(src)
    local d = job and E.departments[job.name]
    if not d then return false, 'not_emergency' end
    local n = toInt(value)
    if not n or n < 1 or n > cfg.CallsignMax then return false, 'invalid_callsign' end
    local callsign = ('%s-%d'):format(d.prefix, n)
    for _, p in ipairs(core().GetPlayers()) do
        if p.source ~= src and p.job == job.name and core().GetMetadata(p.source, 'callsign') == callsign then
            return false, 'callsign_taken'
        end
    end
    core().SetMetadata(src, 'callsign', callsign)
    return true, { callsign = callsign }
end

function E.Status(src)
    local job = core().GetJob(src)
    local d = job and E.departments[job.name]
    if not d then return false, 'not_emergency' end
    return true, {
        department = d.label, rank = job.gradeLabel, grade = job.grade, onDuty = job.onDuty,
        callsign = core().GetMetadata(src, 'callsign') or '', permissions = core().GetGradePermissions(job.name, job.grade),
    }
end

-- Lists online members of the caller's department (highest rank first).
function E.Roster(src)
    local job = core().GetJob(src)
    local d = job and E.departments[job.name]
    if not d then return false, 'not_emergency' end
    local out = {}
    for _, p in ipairs(core().GetPlayers()) do
        if p.job == job.name then
            local rank = d.template.ranks[(p.jobGrade or 0) + 1]
            out[#out + 1] = {
                name = p.characterName or p.name, grade = p.jobGrade or 0, rank = rank and rank.label or '',
                callsign = core().GetMetadata(p.source, 'callsign') or '', onDuty = p.onDuty == true,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return true, out
end

---------------------------------------------------------------------------
-- Management (needs emergency.manage on duty or off duty)
---------------------------------------------------------------------------

local function manager(src)
    local job = core().GetJob(src)
    local d = job and E.departments[job.name]
    if not d or not E.HasPerm(src, 'emergency.manage', true) then return nil, 'forbidden' end
    return job, d
end

local function targetOf(src, target)
    local t = toInt(target)
    if not t then return nil, 'target_not_found' end
    if t == src then return nil, 'cannot_target_self' end
    if not core().GetCharacter(t) then return nil, 'target_not_found' end
    return t
end

function E.Hire(src, target)
    local job, d = manager(src)
    if not job then return false, d end
    local t, why = targetOf(src, target)
    if not t then return false, why end
    if E.departments[core().GetJob(t).name] then return false, 'already_in_service' end
    core().SetJob(t, job.name, 0)
    core().SetMetadata(t, 'callsign', nil)
    core().Notify(t, ('You have been hired by %s.'):format(d.label), 'job')
    core().Log('emergency', 'hire', src, { target = t, job = job.name })
    return true, { department = d.label }
end

function E.Dismiss(src, target)
    local job, d = manager(src)
    if not job then return false, d end
    local t, why = targetOf(src, target)
    if not t then return false, why end
    local tj = core().GetJob(t)
    if tj.name ~= job.name then return false, 'not_in_department' end
    if tj.grade >= job.grade then return false, 'outranks_you' end
    core().SetJob(t, 'unemployed', 0)
    core().SetMetadata(t, 'callsign', nil)
    core().Notify(t, ('You have left %s.'):format(d.label), 'job')
    core().Log('emergency', 'dismiss', src, { target = t, job = job.name })
    return true
end

function E.Promote(src, target, delta)
    local job, d = manager(src)
    if not job then return false, d end
    local step = toInt(delta)
    if step ~= 1 and step ~= -1 then return false, 'invalid_delta' end
    local t, why = targetOf(src, target)
    if not t then return false, why end
    local tj = core().GetJob(t)
    if tj.name ~= job.name then return false, 'not_in_department' end
    if tj.grade >= job.grade then return false, 'outranks_you' end
    local newGrade = tj.grade + step
    if newGrade < 0 or newGrade >= #d.template.ranks then return false, 'invalid_grade' end
    if newGrade >= job.grade then return false, 'rank_too_high' end
    core().SetJob(t, job.name, newGrade)
    local label = d.template.ranks[newGrade + 1].label
    core().Notify(t, ('Your rank is now %s.'):format(label), 'job')
    core().Log('emergency', 'promote', src, { target = t, grade = newGrade })
    return true, { rank = label }
end

---------------------------------------------------------------------------
-- Registration and lifecycle
---------------------------------------------------------------------------

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_emergency:status', function(src) return E.Status(src) end)
    cb('nexoro_emergency:toggleDuty', function(src) return E.ToggleDuty(src) end, 10)
    cb('nexoro_emergency:setCallsign', function(src, p) return E.SetCallsign(src, arg(p, 'callsign')) end, 10)
    cb('nexoro_emergency:roster', function(src) return E.Roster(src) end)
    cb('nexoro_emergency:hire', function(src, p) return E.Hire(src, arg(p, 'target')) end, 10)
    cb('nexoro_emergency:dismiss', function(src, p) return E.Dismiss(src, arg(p, 'target')) end, 10)
    cb('nexoro_emergency:promote', function(src, p) return E.Promote(src, arg(p, 'target'), arg(p, 'delta')) end, 10)
end

AddEventHandler('nexoro:core:ready', function() E.RegisterAll(); register() end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then E.RegisterAll(); register() end
end)

exports('HasPerm', E.HasPerm)
exports('Department', E.Department)
exports('Status', E.Status)
exports('ToggleDuty', E.ToggleDuty)
exports('SetCallsign', E.SetCallsign)
