local fun = {}

---@generic T
---@param f function
---@param iterable any[]
---@param initial T
---@return T
function fun.Reduce(f, iterable, initial)
	local reduced = initial
	for _, v in ipairs(iterable) do
		reduced = f(reduced, v)
	end
	return reduced
end

---@generic T
---@param iterable any[][]
---@return any[]
function fun.Flatten(iterable)
	return fun.Reduce(function(flattened, a)
		for _, v in ipairs(a) do
			table.insert(flattened, v)
		end
		return flattened
	end, iterable, {})
end

return fun
