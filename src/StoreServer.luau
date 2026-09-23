--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Modules.Help.Signal)
local Profile = require(script.Parent.Classes.Profile)
local Remote = require(script.Parent.Classes.Remote)
local Functions = require(script.Parent.Modules.Help.Functions)
local TableUtil = require(script.Parent.Modules.Help.TableUtil)
local Template = require(script.Parent.Modules.Read.Template)
local Types = require(script.Parent.Modules.Read.Types)

local StoreServer = {}

function StoreServer._PlayerAdded(self: StoreServer, Player: Player)
	local Data, success = Functions:GetDataAsync(Player)

	if not success then
		if Player.Parent then
			Player:Kick("Data Error, Rejoin")
		end
		return
	end

	if not Player.Parent then
		return -- left mid-load; _PlayerLeft already ran, nothing to save
	end

	local _Profile = Profile.new(TableUtil.Reconcile((Template :: any) :: { [string]: any }, Data or {}))
	self._Profiles[Player.UserId] = _Profile
	self.ProfileLoaded:Fire(Player, _Profile)
	self._Remote:FireClient(Player, "init", _Profile:GetRaw())
	_Profile:GetDataChangedSignal():Connect(function(key, oldvalue, newvalue)
		self._Remote:FireClient(Player, "update", { key = key, oldvalue = oldvalue, newvalue = newvalue })
	end)
end

function StoreServer._PlayerLeft(self: StoreServer, Player: Player)
	local _Profile = self._Profiles[Player.UserId]
	if _Profile then
		Functions:UpdateDataAsync(Player, _Profile:GetRaw())
		_Profile:Destroy()
		self._Profiles[Player.UserId] = nil
		self._AutoSave_Locks[Player] = nil
	end
end

function StoreServer._StartAutoSaveThread(self: StoreServer)
	if self.AutoSave == true then
		task.spawn(function()
			while true do
				for _, player in Players:GetPlayers() do
					if self._AutoSave_Locks[player] then
						continue
					end

					self._AutoSave_Locks[player] = true
					task.spawn(function()
						local profile = self:GetProfile(player, self.DEFAULT_TIMEOUT)
						if profile then
							Functions:UpdateDataAsync(player, profile:GetRaw())
						end

						self._AutoSave_Locks[player] = false
					end)
				end
				task.wait(self.AUTOSAVE_STEP_DURATION)
			end
		end)
	else
		warn("Autosave is not enabled")
	end
end

function StoreServer.init(
	self: StoreServer,
	template: Types.DataFormat,
	AutoSave: boolean,
	AutoSave_Step_Duration: number
)
	assert(RunService:IsServer())
	Functions:init()
	self._Profiles = {}
	self._AutoSave_Locks = {}
	self._Template = Template or template
	self._Remote = Remote.new("StoreServer")
	self.ProfileLoaded = Signal.new()
	self.AutoSave = AutoSave or false
	self.AUTOSAVE_STEP_DURATION = AutoSave_Step_Duration or 120
	self.DEFAULT_TIMEOUT = 3

	for _, player in Players:GetPlayers() do
		self:_PlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_PlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_PlayerLeft(player)
	end)

	game:BindToClose(function()
		local threads = {}
		for _, player in Players:GetPlayers() do
			table.insert(
				threads,
				task.spawn(function()
					local profile = self._Profiles[player.UserId]
					if profile then
						Functions:UpdateDataAsync(player, profile:GetRaw())
					end
				end)
			)
		end
		local allDone = false
		while not allDone do
			allDone = true
			for _, thread in threads do
				if coroutine.status(thread) ~= "dead" then
					allDone = false
					break
				end
			end
			if not allDone then
				task.wait()
			end
		end
	end)

	self:_StartAutoSaveThread()
end

function StoreServer.GetProfile(self: StoreServer, Player: Player, Timeout: number?): Profile.Profile?
	local profile = self._Profiles[Player.UserId]
	if profile then
		return profile
	end

	local thread = coroutine.running()
	local settled = false

	local loadConn: any
	loadConn = self.ProfileLoaded:Connect(function(loadedPlayer, loadedProfile)
		if loadedPlayer ~= Player or settled then
			return
		end
		settled = true
		if loadConn then
			(loadConn :: any):Disconnect()
		end
		task.spawn(thread, loadedProfile)
	end)

	task.delay(Timeout or self.DEFAULT_TIMEOUT, function()
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

type SignalInstance = typeof(Signal.new())

export type StoreServer = typeof(StoreServer) & {
	_Profiles: { [number]: Profile.Profile },
	_AutoSave_Locks: { [Player]: boolean },
	_Template: Template.Template,
	_Remote: Remote.Remote,
	ProfileLoaded: SignalInstance,
	AutoSave: boolean,
	AUTOSAVE_STEP_DURATION: number,
	DEFAULT_TIMEOUT: number,
}

return StoreServer :: StoreServer
