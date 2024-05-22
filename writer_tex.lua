assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

local file = require("file")
local log = require("log")

local filter = {}

---@param table_ Table
filter.Table = function(table_)
	return table_
end

---@param doc Pandoc
---@param opts WriterOptions
---@return string
function Writer(doc, opts)
	return pandoc.write(doc:walk(filter), "latex", opts)
end

---@return string
function Template()
	local template = file.read_file(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "template.tex" }))
	assert(template, "Failed to read template file")
	return template
end

---@type { [string]: boolean }
Extensions = {}
