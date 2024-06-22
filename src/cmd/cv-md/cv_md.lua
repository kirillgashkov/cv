local element = require("internal.element")
local file = require("internal.file")
local log = require("internal.log")

local md = element.Md
local mdBlock = element.MdBlock
local mergeBlock = element.MergeBlock

---@param name string
---@param role string
---@return Block
local function makeNameAndRoleBlock(name, role)
	return mergeBlock({
		pandoc.Header(1, md(name)),
		pandoc.Header(2, md(role)),
	})
end

---@param contacts List<contact>
---@return Block
local function makeContactsBlock(contacts)
	return pandoc.BulletList(contacts:map(function(contact)
		return pandoc.Plain({ md(contact.name), pandoc.Str(": "), md(contact.description) })
	end))
end

---@param skills List<skill>
local function makeSkillsBlock(skills)
	return pandoc.BulletList(skills:map(function(skill)
		return pandoc.Plain({
			pandoc.Strong({ md(skill.name), pandoc.Str(":") }),
			pandoc.Str(" "),
			md(skill.description),
		})
	end))
end

---@param i item
---@return Block
local function makeItemBlock(i)
	return mergeBlock({
		pandoc.Header(4, md(i.name)),
		i.organization ~= nil and pandoc.Header(6, md(i.organization)) or mergeBlock({}),
		i.started_in_finished_in ~= nil and pandoc.Header(6, md(i.started_in_finished_in)) or mergeBlock({}),
		i.location ~= nil and pandoc.Header(6, md(i.location)) or mergeBlock({}),
		mdBlock(i.description),
	})
end

---@param items List<item>
---@return Block
local function makeItemsBlock(items)
	return mergeBlock(items:map(function(e)
		return makeItemBlock(e)
	end) --[[@as List<any>]])
end

---@param cv cv
---@param config config
---@return Pandoc
local function makeCvDocument(cv, config)
	local doc = pandoc.Pandoc({
		-- Header
		makeNameAndRoleBlock(cv.name, cv.role),
		makeContactsBlock(cv.contacts),
		-- Main
		mergeBlock(config.sections:map(function(s)
			if s.name == "profile" then
				return mergeBlock({
					pandoc.Header(3, md(s.header)),
					mdBlock(cv.profile),
				})
			elseif s.name == "skills" then
				return mergeBlock({
					pandoc.Header(3, md(s.header)),
					-- makeSkillsBlock(cv.skills),
				})
			elseif s.name == "experience" then
				return mergeBlock({
					pandoc.Header(3, md(s.header)),
					-- makeItemsBlock(cv.experience),
				})
			elseif s.name == "projects" then
				return mergeBlock({
					pandoc.Header(3, md(s.header)),
					-- makeItemsBlock(cv.projects),
				})
			elseif s.name == "education" then
				return mergeBlock({
					pandoc.Header(3, md(s.header)),
					-- makeItemsBlock(cv.education),
				})
			else
				log.Error("unrecognized section in config: " .. s.name)
				assert(false)
			end
		end) --[[@as any]]),
	})

	doc = doc:walk({
		---Prevents Pandoc from messing up ordered lists. This was copied from the
		---LaTeX CV generator.
		---@param list OrderedList
		---@return OrderedList
		OrderedList = function(list)
			list.listAttributes = pandoc.ListAttributes(list.listAttributes.start, "DefaultStyle", "DefaultDelim")
			return list
		end,
	})

	-- Collapse merge blocks and inlines.
	doc = doc:walk({
		---@param div Div
		---@return Div | Blocks
		Div = function(div)
			if element.IsMerge(div.attr) then
				return div.content
			end
			return div
		end,

		---@param span Span
		---@return Span | Inlines
		Span = function(span)
			if element.IsMerge(span.attr) then
				return span.content
			end
			return span
		end,
	})

	return doc
end

---@param path string
---@return config
local function makeConfig(path)
	local fileContent = file.Read(path)
	assert(fileContent ~= nil, "config file not found at " .. path)
	return pandoc.json.decode(fileContent)
end

---@param scriptPath string
---@return Template
local function makeTemplate(scriptPath)
	local templateFile = pandoc.path.join({ pandoc.path.directory(scriptPath), "template.md" })
	local templateContent = file.Read(templateFile)
	assert(templateContent ~= nil)
	return pandoc.template.compile(templateContent)
end

---@param path string
---@return cv
local function makeCv(path)
	local fileContent = file.Read(path)
	assert(fileContent ~= nil, "cv file not found at " .. path)
	return pandoc.json.decode(fileContent)
end

if arg ~= nil then
	local expectedPandocApiVersion = "1.23.1"
	if tostring(PANDOC_API_VERSION) ~= expectedPandocApiVersion then
		log.Warning(
			"Expected Pandoc API version " .. expectedPandocApiVersion .. ", got " .. tostring(PANDOC_API_VERSION)
		)
	end

	local config = nil
	local cv = nil

	local configFile = nil
	local cvFile = nil

	local i = 1
	while i <= #arg do
		if arg[i] == "--config" then
			configFile = arg[i + 1]
			assert(configFile ~= nil)
			config = makeConfig(configFile)
			i = i + 2
		elseif arg[i] == "-h" or arg[i] == "--help" then
			io.stderr:write("Usage: " .. arg[0] .. " --config <config> <cv>\n")
			os.exit(0)
		elseif arg[i]:sub(1, 1) == "-" then
			io.stderr:write("Error: unknown option: " .. arg[i] .. "\n")
			os.exit(2)
		else
			if cvFile ~= nil then
				io.stderr:write("Error: too many arguments\n")
				os.exit(2)
			end
			cvFile = arg[i]
			cv = makeCv(cvFile)
			i = i + 1
		end
	end

	if config == nil then
		io.stderr:write("Error: missing config file\n")
		os.exit(2)
	end
	if cv == nil then
		io.stderr:write("Error: missing CV file\n")
		os.exit(2)
	end

	local doc = makeCvDocument(cv, config)
	io.stdout:write(pandoc.write(doc, "gfm", { template = makeTemplate(arg[0]) }))
end
