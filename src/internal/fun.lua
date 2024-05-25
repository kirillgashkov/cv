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
---@param factory? function | nil
---@return any[]
function fun.Flatten(iterable, factory)
  factory = factory ~= nil and factory or function()
    return {}
  end

  return fun.Reduce(function(flattened, a)
    for _, v in ipairs(a) do
      table.insert(flattened, v)
    end
    return flattened
  end, iterable, factory())
end

---@generic T
---@param iterable any[]
---@param n integer
---@param factory? function | nil
---@return any[]
function fun.Group(iterable, n, factory)
  factory = factory ~= nil and factory or function()
    return {}
  end

  local grouped = factory()

  local group = factory()
  for _, v in ipairs(iterable) do
    if #group == n then
      table.insert(grouped, group)
      group = factory()
    end
    table.insert(group, v)
  end
  if #group > 0 then
    table.insert(grouped, group)
  end

  return grouped
end

---@generic T
---@param iterable any[][]
---@param sep any
---@param factory? function | nil
---@return any[]
function fun.Intersperse(iterable, sep, factory)
  factory = factory ~= nil and factory or function()
    return {}
  end

  local interspersed = fun.Reduce(function(interspersed, v)
    table.insert(interspersed, v)
    table.insert(interspersed, sep)
    return interspersed
  end, iterable, factory())

  -- Remove the extra separator at the end.
  if #interspersed > 0 then
    table.remove(interspersed)
  end

  return interspersed
end

return fun
