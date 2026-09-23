local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Parent.Modules.Help.Signal)
local Types = require(script.Parent.Parent.Modules.Read.Types)

local Mirror = {}
Mirror.__index = Mirror

export type Mirror = typeof(setmetatable(
	{} :: {
		_LocalData: Types.DataFormat,
		_DataChangedSignal: Signal.Signal,
	},
	Mirror
))

function Mirror.new(LocalData: Types.DataFormat)
	assert(RunService:IsClient())
	if not LocalData then
		return
	end
	local self = setmetatable({}, Mirror)
	self._LocalData = LocalData
	self._DataChangedSignal = Signal.new()
	return self
end

function Mirror.Get(self: Mirror, Key: string)
	if self._LocalData == nil then
		return
	end

	if self._LocalData[Key] == nil then
		warn("Invalid Key")
		return
	end

	return self._LocalData[Key]
end

function Mirror.Set(self: Mirror, Key: string, value: any)
	if self._LocalData == nil then
		return
	end

	local prevVal = self._LocalData[Key]
	self._LocalData[Key] = value

	if prevVal ~= value then
		self._DataChangedSignal:Fire(Key, prevVal, value)
	end

	return self._LocalData[Key]
end

function Mirror.GetRaw(self: Mirror)
	local copy = table.clone(self._LocalData)
	return copy
end

function Mirror.GetDataChangedSignal(self: Mirror)
	return self._DataChangedSignal
end

function Mirror.Destroy(self: Mirror)
	self._DataChangedSignal:Destroy()
end

return Mirror
