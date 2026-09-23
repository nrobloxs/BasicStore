local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "_remotes"

local function getRemotesContainer(): Folder
	local container = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not container then
		container = Instance.new("Folder")
		container.Name = REMOTES_FOLDER_NAME
		container.Parent = ReplicatedStorage
	end

	return container :: Folder
end

local Remote = {}
Remote.__index = Remote

export type Remote = typeof(setmetatable(
	{} :: {
		_Net: RemoteEvent,
		_Container: Folder,
	},
	Remote
))

function Remote.new(Identifier: string): Remote
	assert(type(Identifier) == "string" and Identifier ~= "", "Identifier must be a non-empty string")

	local self = setmetatable({}, Remote)

	if RunService:IsServer() then
		local container = Instance.new("Folder")
		container.Name = "Container_" .. Identifier
		container.Parent = getRemotesContainer()

		local net = Instance.new("RemoteEvent")
		net.Name = Identifier
		net.Parent = container

		self._Container = container
		self._Net = net
	else
		local remotesContainer = getRemotesContainer()
		local container = remotesContainer:WaitForChild("Container_" .. Identifier, 5)
		assert(container ~= nil, "Remote container for '" .. Identifier .. "' was not found")

		local net = container:WaitForChild(Identifier, 5) --  look inside the container, add a timeout
		assert(net ~= nil, "Remote '" .. Identifier .. "' was not found in the remotes folder")
		assert(net:IsA("RemoteEvent"), "Remote '" .. Identifier .. "' is not a RemoteEvent")

		self._Container = container
		self._Net = net :: RemoteEvent
	end

	return self
end

function Remote.FireServer(self: Remote, ...: any)
	assert(RunService:IsClient(), "Only be called from client domain")
	self._Net:FireServer(...)
end

function Remote.FireClient(self: Remote, Player: Player, ...: any)
	assert(RunService:IsServer(), "Only be called from server domain")
	self._Net:FireClient(Player, ...)
end

function Remote.FireAllClients(self: Remote, ...: any)
	assert(RunService:IsServer(), "Only be called from server domain")
	self._Net:FireAllClients(...)
end

function Remote.OnClientEvent(self: Remote)
	assert(RunService:IsClient(), "Only be called from client domain")
	return self._Net.OnClientEvent
end

function Remote.OnServerEvent(self: Remote)
	assert(RunService:IsServer(), "Only be called from server domain")
	return self._Net.OnServerEvent
end

function Remote.DestroyServer(self: Remote)
	assert(RunService:IsServer(), "Only be called from server domain")
	if self._Net then
		self._Net:Destroy()
	end
	if self._Container then
		self._Container:Destroy()
	end
end

function Remote.DestroyLocal(self: Remote)
	assert(RunService:IsClient(), "Only be called from client domain")
	if self._Net then
		self._Net:Destroy()
	end
	if self._Container then
		self._Container:Destroy()
	end
end

return Remote
