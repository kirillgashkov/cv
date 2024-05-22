local M = {}

---@param path string
---@return boolean
function M.file_exists(path)
	local f = io.open(path)
	if f then
		f:close()
	end
	return f ~= nil
end

---@param path string
---@param mode "r"|"rb"
---@return string|nil
local function _read_file(path, mode)
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
function M.read_file(path)
	return _read_file(path, "r")
end

---@param path string
---@return string|nil
function M.read_file_bytes(path)
	return _read_file(path, "rb")
end

return M
