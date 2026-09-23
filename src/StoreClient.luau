--!strict

local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Modules.Help.Signal)
local Mirror = require(script.Parent.Classes.Mirror)
local Remote = require(script.Parent.Classes.Remote)

local StoreClient = {}

function StoreClient.init(self: StoreClient)
	assert(RunService:IsClient())
	self._Remote = Remote.new("StoreServer")
	self._Mirror = nil
	self.MirrorLoaded = Signal.new()
	self._Remote:OnClientEvent():Connect(function(action, ...)
		if action == "init" then
			local data = ...
			self._Mirror = Mirror.new(data)
			self.MirrorLoaded:Fire(self._Mirror)
		elseif action == "update" then
			local key, oldvalue, newvalue = ...
			if self._Mirror then
				self._Mirror:Set(key, newvalue)
			end
		end
	end)
end

function StoreClient.GetMirror(self: StoreClient, Timeout: number?): Mirror.Mirror?
	if self._Mirror then
		return self._Mirror
	end

	local thread = coroutine.running()
	local settled = false

	local loadConn: any
	loadConn = self.MirrorLoaded:Connect(function(mirror)
		if settled then
			return
		end
		settled = true
		if loadConn then
			(loadConn :: any):Disconnect()
		end
		task.spawn(thread, mirror)
	end)

	task.delay(Timeout or 3, function()
		if settled then
			return
		end
		settled = true
		if loadConn then
			(loadConn :: any):Disconnect()
		end
		task.spawn(thread, nil)
	end)

	return coroutine.yield()
end

export type StoreClient = typeof(StoreClient) & {
	_Mirror: Mirror.Mirror?,
	_Remote: Remote.Remote,
	MirrorLoaded: typeof(Signal.new()),
}

return StoreClient :: StoreClient
