local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Read.Types)
local TableUtil = require(script.Parent.TableUtil)

local JobID = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

local SessionStore = {}

function SessionStore.init(self: SessionStore)
	self.DefaultKey = "PlayerData_"
	self.RetryAmts = {
		GetDataAsync = 3,
		UpdateDataAsync = 3,
	}
	self.Store = DataStoreService:GetDataStore(RunService:IsStudio() and "Test" or "Live")
	self.LOCK_TIMEOUT = 180
end

function SessionStore.GetDataAsync(self: SessionStore, player: Player): (Types.DataFormat?, boolean, boolean)
	if not player then
		return nil, false
	end

	local locked = false

	local result, success = TableUtil.RetryWrap(self.RetryAmts.GetDataAsync or 5, function()
		locked = false
		return self.Store:UpdateAsync(self.DefaultKey .. player.UserId, function(old: Types.StoredRecord?)
			local now = os.time()

			if old and old.SessionLock then
				local lock = old.SessionLock
				local isStale = (now - lock.Timestamp) > self.LOCK_TIMEOUT

				if lock.JobId ~= JobID and not isStale then
					locked = true
					error("SESSION_LOCKED")
				end
			end

			local newRecord: Types.StoredRecord = {
				Data = (old and old.Data) or {},
				SessionLock = { JobId = JobID, Timestamp = now },
			}

			return newRecord
		end)
	end)

	if not success then
		return nil, false, locked
	end

	return (result :: Types.StoredRecord).Data, true, false
end

function SessionStore.UpdateDataAsync(
	self: SessionStore,
	Player: Player,
	NewData: Types.DataFormat,
	Release: boolean
): boolean
	if NewData == nil then
		return
	end

	local lostLock = false

	local _, success = TableUtil.RetryWrap(self.RetryAmts.UpdateDataAsync, function()
		lostLock = false
		self.Store:UpdateAsync(self.DefaultKey .. Player.UserId, function(old: Types.StoredRecord)
			if old and old.SessionLock and old.SessionLock.JobId ~= JobID then
				lostLock = true
				error("LOCK_LOST")
			end

			local merged = TableUtil.DeepMerge((old and old.Data) or {}, NewData)

			local newRecord: Types.StoredRecord = {
				Data = merged :: Types.DataFormat,
				SessionLock = if Release then nil else { JobId = JobID, Timestamp = os.time() },
			}

			return newRecord
		end)
	end)

	if not success and lostLock then
		warn(
			"[SessionStore] Lost session lock for " .. Player.Name .. "; save skipped to avoid overwriting another server"
		)
	end

	return success
end

export type SessionStore = typeof(SessionStore) & {
	DefaultKey: string,
	RetryAmts: {
		GetDataAsync: number,
		UpdateDataAsync: number,
	},
	Store: DataStore,
	LOCK_TIMEOUT: number,
}

return SessionStore :: SessionStore
