local RunService = game:GetService("RunService")

local BasicStore = {}

setmetatable(BasicStore, {
	__index = function(_, key)
		if key == "Server" then
			assert(RunService:IsServer(), "BasicStore.Server can only be required on the server")
			local Server = require(script.StoreServer)
			rawset(BasicStore, "Server", Server)
			return Server
		elseif key == "Client" then
			local Client = require(script.StoreClient)
			rawset(BasicStore, "Client", Client)
			return Client
		end
	end,
})

return BasicStore
