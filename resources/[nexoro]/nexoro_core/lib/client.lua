-- Include in another resource: client_scripts { '@nexoro_core/lib/client.lua', ... }
-- ok, data = NexoroCore.Callback('name', arg1, arg2)   (yields; call from a thread or NUI callback)
NexoroCore = NexoroCore or {}

function NexoroCore.Callback(name, ...)
    local p = promise.new()
    exports.nexoro_core:TriggerCallback(name, function(...) p:resolve(table.pack(...)) end, ...)
    local result = Citizen.Await(p)
    return table.unpack(result, 1, result.n)
end
