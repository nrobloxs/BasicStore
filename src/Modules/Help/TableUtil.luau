--!strict

local TableUtil = {}

function TableUtil.IsArray(t: { [any]: any }?): (boolean, number)
	if typeof(t) ~= "table" then
		return false, 0
	end

	local count = 0
	for _ in pairs(t) do
		count += 1
	end

	for i = 1, count do
		if t[i] == nil then
			return false, 0
		end
	end

	return true, count
end

function TableUtil.DeepCopy<T>(orig: T, seen: { [any]: any }?): T
	seen = seen or {}

	if typeof(orig) ~= "table" then
		return (orig :: any) :: T
	end

	if seen[orig] ~= nil then
		return seen[orig] :: T
	end

	local copy: { [any]: any } = {}
	seen[orig] = copy

	for k, v in pairs(orig :: any) do
		copy[TableUtil.DeepCopy(k, seen)] = TableUtil.DeepCopy(v, seen)
	end

	return setmetatable(copy, getmetatable(orig :: any)) :: T
end

function TableUtil.Reconcile(template: { [string]: any }, saved: { [string]: any }?): { [string]: any }
	saved = saved or {}
	local result: { [string]: any } = {}

	for key, defaultValue in pairs(template) do
		local savedValue = saved[key]
		if typeof(defaultValue) == "table" and typeof(savedValue) == "table" then
			result[key] = TableUtil.Reconcile(defaultValue, savedValue)
		elseif savedValue ~= nil then
			result[key] = savedValue
		else
			result[key] = TableUtil.DeepCopy(defaultValue, {})
		end
	end

	return result
end

function TableUtil.DeepMerge(base: { [string]: any }, override: { [string]: any }): { [string]: any }
	local result: { [string]: any } = {}

	for k, v in pairs(base) do
		if typeof(v) == "table" then
			result[k] = TableUtil.DeepMerge(v, {})
		else
			result[k] = v
		end
	end

	for k, v in pairs(override) do
		if typeof(v) == "table" and typeof(result[k]) == "table" then
			result[k] = TableUtil.DeepMerge(result[k], v)
		else
			result[k] = v
		end
	end

	return result
end

function TableUtil.RetryWrap(Retries: number, Function: () -> any): (any, boolean)
	if not Function then
		return nil, false
	end

	if Retries <= 0 or Retries > 100 then
		return nil, false
	end

	local lastError: any
	for i = 1, Retries do
		local Success, Result = pcall(Function)
		if Success then
			return Result, true
		end
		lastError = Result
		task.wait(2 ^ (i - 1) * 0.5)
	end

	warn("RetryWrap exhausted:", lastError)
	return nil, false
end

export type TableUtil = typeof(TableUtil) & {}

return TableUtil :: TableUtil
