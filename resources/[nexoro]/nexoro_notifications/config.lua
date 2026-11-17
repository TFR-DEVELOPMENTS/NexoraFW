Config = {}

Config.Notifications = {
    Sounds = true,
    -- Frontend sound per notification type: { sound name, sound set }. Verify on your build.
    SoundFor = {
        success = { 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET' },
        error = { 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        warning = { 'Hack_Failed', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
        info = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        emergency = { 'Event_Start_Text', 'GTAO_FM_Events_Soundset' },
        job = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        banking = { 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET' },
        inventory = { 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        staff = { 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    },
    -- Hides GTA's own notification feed (top corner messages) so they do not clash with Nexoro ones.
    HideVanillaFeed = true,
}
