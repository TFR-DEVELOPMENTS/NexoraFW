-- SERVER-ONLY. Never add this file to client_scripts or shared_scripts.
Config = Config or {}

local MOD_ALL   = 'nexoro.mod.*'
local STAFF_ALL = 'nexoro.staff.*'

Config.Staff = {
    -- Identifiers that always receive the owner rank, e.g. 'license:0123456789abcdef...'.
    -- Use this to bootstrap the first owner, or use the console command: nexoro_setrank <id> owner
    Owners = {},

    -- Also honour FiveM ACE permissions such as: add_ace group.admin nexoro.admin.money allow
    UseAceFallback = true,

    -- Higher level = more senior. Staff may only act on staff with a LOWER level.
    -- Permissions support exact names, "prefix.*" wildcards and "*".
    Ranks = {
        { name = 'owner',       label = 'Owner',                level = 100, permissions = { '*' } },
        { name = 'director',    label = 'Director',             level = 90,  permissions = { 'nexoro.admin.*', MOD_ALL, STAFF_ALL } },
        { name = 'head_admin',  label = 'Head Administrator',   level = 80,  permissions = {
            'nexoro.admin.dashboard', 'nexoro.admin.players', 'nexoro.admin.teleport', 'nexoro.admin.money', 'nexoro.admin.inventory',
            'nexoro.admin.jobs', 'nexoro.admin.vehicles', 'nexoro.admin.resources', 'nexoro.admin.economy', 'nexoro.admin.bans', 'nexoro.admin.world', 'nexoro.admin.self',
            MOD_ALL, 'nexoro.staff.chat', 'nexoro.staff.duty', 'nexoro.staff.logs' } },
        { name = 'senior_admin', label = 'Senior Administrator', level = 70, permissions = {
            'nexoro.admin.dashboard', 'nexoro.admin.players', 'nexoro.admin.teleport', 'nexoro.admin.money', 'nexoro.admin.inventory',
            'nexoro.admin.jobs', 'nexoro.admin.vehicles', 'nexoro.admin.bans', 'nexoro.admin.world', 'nexoro.admin.self', MOD_ALL, 'nexoro.staff.chat', 'nexoro.staff.duty', 'nexoro.staff.logs' } },
        { name = 'admin',       label = 'Administrator',        level = 60,  permissions = {
            'nexoro.admin.dashboard', 'nexoro.admin.players', 'nexoro.admin.teleport', 'nexoro.admin.vehicles', 'nexoro.admin.bans', 'nexoro.admin.self',
            MOD_ALL, 'nexoro.staff.chat', 'nexoro.staff.duty' } },
        { name = 'junior_admin', label = 'Junior Administrator', level = 50, permissions = {
            'nexoro.admin.dashboard', 'nexoro.admin.players', 'nexoro.admin.teleport', MOD_ALL, 'nexoro.staff.chat', 'nexoro.staff.duty' } },
        { name = 'senior_mod',  label = 'Senior Moderator',     level = 40,  permissions = {
            'nexoro.mod.reports', 'nexoro.mod.warnings', 'nexoro.mod.kick', 'nexoro.mod.spectate', 'nexoro.mod.freeze',
            'nexoro.mod.temporaryban', 'nexoro.mod.escalate', 'nexoro.staff.chat', 'nexoro.staff.duty' } },
        { name = 'moderator',   label = 'Moderator',            level = 30,  permissions = {
            'nexoro.mod.reports', 'nexoro.mod.warnings', 'nexoro.mod.kick', 'nexoro.mod.spectate', 'nexoro.mod.freeze',
            'nexoro.mod.escalate', 'nexoro.staff.chat', 'nexoro.staff.duty' } },
        { name = 'trial_mod',   label = 'Trial Moderator',      level = 20,  permissions = {
            'nexoro.mod.reports', 'nexoro.mod.warnings', 'nexoro.mod.spectate', 'nexoro.mod.escalate', 'nexoro.staff.chat', 'nexoro.staff.duty' } },
        { name = 'support',     label = 'Support Team',         level = 10,  permissions = {
            'nexoro.mod.reports', 'nexoro.staff.chat', 'nexoro.staff.duty' } },
    },
}
