-- Bus: a tiny publish/subscribe hub so client modules stay decoupled.

local Bus = {}

local listeners = {}

function Bus.on(name, callback)
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, callback)
end

function Bus.fire(name, ...)
	local list = listeners[name]
	if list then
		for _, callback in ipairs(list) do
			task.spawn(callback, ...)
		end
	end
end

return Bus
