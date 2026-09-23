local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Read.Types)
local Util1 = require(script.Parent.Util1)

local Functions = {}

function Functions.init(self: Functions)
	self.DefaultKey = "PlayerData_"
	self.RetryAmts = {
		GetDataAsync = 3,
		UpdateDataAsync = 3,
	}
	self.Store = DataStoreService:GetDataStore(RunService:IsStudio() and "Test" or "Live")
end

function Functions.GetDataAsync(self: Functions, player: Player, StoreOptions: DataStoreGetOptions?): (any, boolean)
	if not player then
		return nil, false
	end

	local result, success = Util1.RetryWrap(self.RetryAmts.GetDataAsync or 5, function()
		return self.Store:GetAsync(self.DefaultKey .. player.UserId, StoreOptions)
	end)

	return result, success
end

function Functions.UpdateDataAsync(self: Functions, Player: Player, NewData: Types.DataFormat)
	if NewData == nil then
		return
	end

	local _, success = Util1.RetryWrap(self.RetryAmts.UpdateDataAsync, function()
		self.Store:UpdateAsync(self.DefaultKey .. Player.UserId, function(CurrentData, _: DataStoreKeyInfo)
			return Util1.DeepMerge(CurrentData or {}, NewData) :: Types.DataFormat
		end)
	end)

	return success
end

export type Functions = typeof(Functions) & {
	DefaultKey: string,
	RetryAmts: {
		GetDataAsync: number,
		UpdateDataAsync: number,
	},
	Store: DataStore,
}

return Functions :: Functions
