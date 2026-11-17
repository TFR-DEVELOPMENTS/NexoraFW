Nexoro = Nexoro or {}

-- Players can rebind these in Settings > Key Bindings > FiveM.
function Nexoro.RegisterKeybind(name, description, defaultKey, onPress, onRelease)
    RegisterCommand('+nexoro_' .. name, function() if onPress then onPress() end end, false)
    RegisterCommand('-nexoro_' .. name, function() if onRelease then onRelease() end end, false)
    RegisterKeyMapping('+nexoro_' .. name, description, 'keyboard', defaultKey)
end

exports('RegisterKeybind', Nexoro.RegisterKeybind)
