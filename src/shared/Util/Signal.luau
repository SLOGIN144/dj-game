--!strict
-- A minimal signal: services fire it, others (goals, saving) listen without the firing service
-- knowing about them.

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

-- Calls `handler` on every fire. Returns a function that disconnects it.
function Signal.connect(self: Signal, handler: (...any) -> ()): () -> ()
	table.insert(self._handlers, handler)
	return function()
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
end

function Signal.fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
