local file = {}

---@param path string
---@return boolean
function file.Exists(path)
	local f = io.open(path)
	if f then
		f:close()
	end
	return f ~= nil
end

---@param path string
---@param mode "r"|"rb"
---@return string|nil
local function read(path, mode)
	local f = io.open(path, mode)
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

---@param path string
---@return string|nil
function file.Read(path)
	return read(path, "r")
end

---@param path string
---@return string|nil
function file.ReadBytes(path)
	return read(path, "rb")
end

return file
