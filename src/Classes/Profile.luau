local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Parent.Modules.Help.Signal)
local Types = require(script.Parent.Parent.Modules.Read.Types)

local Profile = {}
Profile.__index = Profile

export type Profile = typeof(setmetatable(
	{} :: {
		_Data: Types.DataFormat,
		_DataChangedSignal: Signal.Signal,
	},
	Profile
))

function Profile.new(Data: Types.DataFormat?): Profile
	assert(RunService:IsServer(), "Profile.new must be called on the server")

	local self = setmetatable({
		_Data = Data or {},
		_DataChangedSignal = Signal.new(),
	}, Profile)

	return self
end

function Profile.Get(self: Profile, Key: string): any
	if self._Data == nil then
		return nil
	end

	if self._Data[Key] == nil then
		warn("Profile.Get: invalid key '" .. Key .. "'")
		return nil
	end

	return self._Data[Key]
end

function Profile.Set(self: Profile, Key: string, value: any): any
	if self._Data == nil then
		return nil
	end

	local prevVal = self._Data[Key]
	self._Data[Key] = value

	if prevVal ~= value then
		self._DataChangedSignal:Fire(Key, prevVal, value)
	end

	return self._Data[Key]
end

function Profile.GetRaw(self: Profile): Types.DataFormat
	if self._Data == nil then
		return {}
	end

	return table.clone(self._Data)
end

function Profile.GetDataChangedSignal(self: Profile): Signal.Signal
	return self._DataChangedSignal
end

function Profile.GetChangedSignal(self: Profile): Signal.Signal
	return self:GetDataChangedSignal()
end

function Profile.Destroy(self: Profile)
	if self._DataChangedSignal then
		self._DataChangedSignal:Destroy()
	end
end

return Profile
