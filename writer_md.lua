assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

local file = require("file")
local log = require("log")

local filter = {}

---@param table_ Table
filter.Table = function(table_)
	return table_
end

---@param _doc Pandoc
---@param _opts WriterOptions
---@return string
function Writer(_doc, _opts)
	local doc = pandoc.Pandoc(pandoc.Blocks({
		pandoc.Header(1, pandoc.Str("Title")),
	}))
	return pandoc.write(doc, "gfm")
end

---@return string
function Template()
	local template = file.read_file(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "template.md" }))
	assert(template, "Failed to read template file")
	return template
end

---@type { [string]: boolean }
Extensions = {}
