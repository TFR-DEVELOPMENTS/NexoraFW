Nexoro = Nexoro or {}
local pending = {}
local nextId = 0
local TIMEOUT_MS = 10000

-- cb(ok, dataOrErrorCode). Transport errors arrive as (false, 'rate_limited' | 'timeout' | ...).
function Nexoro.TriggerCallback(name, cb, ...)
    nextId = nextId + 1
    local id = nextId
    pending[id] = cb
    TriggerServerEvent('nexoro:server:callback', name, id, ...)
    SetTimeout(TIMEOUT_MS, function()
        if pending[id] then
            local fn = pending[id]
            pending[id] = nil
            fn(false, 'timeout')
        end
    end)
end

RegisterNetEvent('nexoro:client:callback', function(id, ...)
    local fn = pending[id]
    if not fn then return end
    pending[id] = nil
    fn(...)
end)

exports('TriggerCallback', Nexoro.TriggerCallback)
