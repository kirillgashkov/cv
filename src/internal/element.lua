local element = {}

local mdFormat = "gfm-yaml_metadata_block+smart"

---@param attr Attr
---@return boolean
function element.IsMerge(attr)
	return attr.attributes["data-template--is-merge"] == "1"
end

---@param inlines Inlines
---@return Inline
function element.Merge(inlines)
	local i = pandoc.Span(inlines)
	i.attr.attributes["data-template--is-merge"] = "1"
	return i
end

---@param blocks Blocks
---@return Block
function element.MergeBlock(blocks)
	local b = pandoc.Div(blocks)
	b.attr.attributes["data-template--is-merge"] = "1"
	return b
end

---@param s string
---@return Inline
function element.Md(s)
	return element.Merge(pandoc.utils.blocks_to_inlines(pandoc.read(s, mdFormat).blocks))
end

---@param s string
---@return Block
function element.MdBlock(s)
	return element.MergeBlock(pandoc.read(s, mdFormat).blocks)
end

return element
