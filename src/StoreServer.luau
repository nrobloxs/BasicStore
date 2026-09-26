--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Modules.Help.Signal)
local Profile = require(script.Parent.Classes.Profile)
local Remote = require(script.Parent.Classes.Remote)
local SessionStore = require(script.Parent.Modules.Core.SessionStore)

local TableUtil = require(script.Parent.Modules.Help.TableUtil)
local Template = require(script.Parent.Modules.Read.Template)
local Types = require(script.Parent.Modules.Read.Types)

local StoreServer = {}

function StoreServer._PlayerAdded(self: StoreServer, Player: Player)
	local Data: Types.DataFormat?
	local success = false
	local locked = false
	local attempts = 0

	repeat
		Data, success, locked = SessionStore:GetDataAsync(Player)
		if not success and locked then
			attempts += 1
			if attempts < self.MAX_LOCK_RETRIES and Player.Parent then
				task.wait(self.LOCK_RETRY_DELAY)
			end
		end
	until success or not locked or attempts >= self.MAX_LOCK_RETRIES or not Player.Parent

	if not success then
		if Player.Parent then
			Player:Kick(
				locked and "Your data is loading in another server. Please rejoin in a moment." or "Data Error, Rejoin"
			)
			return
		end
	end

	if not Player.Parent then
		SessionStore:UpdateDataAsync(Player, Data or {}, true)
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
		SessionStore:UpdateDataAsync(Player, _Profile:GetRaw(), true)
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
							SessionStore:UpdateDataAsync(player, profile:GetRaw())
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
	SessionStore:init()
	self._Profiles = {}
	self._AutoSave_Locks = {}
	self._Template = Template or template
	self._Remote = Remote.new("StoreServer")
	self.ProfileLoaded = Signal.new()
	self.AutoSave = AutoSave or false
	self.AUTOSAVE_STEP_DURATION = AutoSave_Step_Duration or 120
	self.DEFAULT_TIMEOUT = 3
	self.MAX_LOCK_RETRIES = 5
	self.LOCK_RETRY_DELAY = 6

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
						SessionStore:UpdateDataAsync(player, profile:GetRaw(), true)
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
	MAX_LOCK_RETRIES: number,
	LOCK_RETRY_DELAY: number,
}

return StoreServer :: StoreServer
