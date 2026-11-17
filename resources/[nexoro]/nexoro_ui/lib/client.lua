-- Include in another resource: client_scripts { '@nexoro_ui/lib/client.lua', ... }
-- Yielding helpers (call from a thread or event handler):
--   local done = NexoroUI.Progress({ label = 'Repairing', duration = 5000 })          -> true / false (cancelled)
--   local values = NexoroUI.Input({ title = 'Pay', fields = { { type = 'number', label = 'Amount', name = 'amount', required = true } } })  -> table / nil
--   local yes = NexoroUI.Confirm({ title = 'Sure?', text = '...' })                   -> true / false
--   NexoroUI.Alert({ title = 'Info', text = '...' })
NexoroUI = NexoroUI or {}

local function await(fnName, def)
    local p = promise.new()
    exports.nexoro_ui[fnName](exports.nexoro_ui, def, function(result) p:resolve({ result }) end)
    return Citizen.Await(p)[1]
end

function NexoroUI.Progress(opts) return await('Progress', opts) end
function NexoroUI.Input(def) return await('Input', def) end
function NexoroUI.Confirm(def) return await('Confirm', def) end
function NexoroUI.Alert(def) return await('Alert', def) end
function NexoroUI.RegisterContext(def) return exports.nexoro_ui:RegisterContext(def) end
function NexoroUI.ShowContext(id) return exports.nexoro_ui:ShowContext(id) end
function NexoroUI.HideContext() return exports.nexoro_ui:HideContext() end
function NexoroUI.ShowTextUI(text, key) return exports.nexoro_ui:ShowTextUI(text, key) end
function NexoroUI.HideTextUI() return exports.nexoro_ui:HideTextUI() end
