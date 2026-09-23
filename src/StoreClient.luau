local Mirror = require(script.Parent.Classes.Mirror)
local Remote = require(script.Parent.Classes.Remote)

local StoreClient = {}

function StoreClient.init(self: StoreClient)
	self._Remote = Remote.new("StoreServer")

	self._Remote:OnClientEvent():Connect(function(action, ...)
		if action == "init" then
			local data = ...
			self._Mirror = Mirror.new(data)
		elseif action == "update" then
			local key, oldvalue, newvalue = ...
			self._Mirror:Set(key, newvalue)
		end
	end)
end

function StoreClient.GetMirror(self: StoreClient, Timeout: number?): Mirror.Mirror?
	if self._Mirror then
		return self._Mirror
	end

	local thread = coroutine.running()
	local settled = false

	local conn: RBXScriptConnection
	conn = self._Remote:OnClientEvent():Connect(function(action)
		if action ~= "init" or settled then
			return
		end
		settled = true
		conn:Disconnect()
		task.spawn(thread, self._Mirror)
	end)

	task.delay(Timeout or 5, function()
		if settled then
			return
		end
		settled = true
		conn:Disconnect()
		task.spawn(thread, nil)
	end)

	return coroutine.yield()
end

export type StoreClient = typeof(StoreClient) & {
	_Mirror: Mirror.Mirror?,
	_Remote: Remote.Remote,
}

return StoreClient :: StoreClient
