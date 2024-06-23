local element = require("internal.element")
local file = require("internal.file")
local log = require("internal.log")

local md = element.Md
local mdBlock = element.MdBlock
local merge = element.Merge
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

---@param name string
---@param role string
---@param contacts List<contact>
---@return Block
local function makeNameRoleContactsBlock(name, role, contacts)
	return mergeBlock({
		makeNameAndRoleBlock(name, role),
		makeContactsBlock(contacts),
	})
end

---@param skills List<skill>
local function makeSkillsBlock(skills)
	return pandoc.BulletList(skills:map(function(skill)
		return pandoc.Plain({
			pandoc.Strong({ md(skill.name), md(":") }),
			pandoc.Space(),
			md(skill.description),
		})
	end))
end

---@param updated_in string | nil
---@param config config
---@return Inline
local function makeUpdatedIn(updated_in, config)
	local key = tostring(updated_in)
	local t = config.updated_ins[key]
	if t == nil then
		log.Error("missing config.updated_ins for " .. key)
		assert(false)
	end
	assert(type(t) == "string")
	return md(t)
end

---@param started_in string | nil
---@param finished_in string | nil
---@param config config
---@return Inline
local function makeStartedInFinishedIn(started_in, finished_in, config)
	local key = tostring(started_in) .. "," .. tostring(finished_in)
	local t = config.started_in_finished_ins[key]
	if t == nil then
		log.Error("missing config.started_in_finished_ins for " .. key)
		assert(false)
	end
	assert(type(t) == "string")
	return md(t)
end

---@param e experience
---@param config config
---@return Block
local function makeExperienceBlock(e, config)
	return mergeBlock({
		pandoc.Header(4,
			merge({
				md(e.name),
				e.tagline and merge({ pandoc.Space(), md("—"), pandoc.Space(), md(e.tagline) }) or merge({}),
			})
		),
		(e.started_in ~= nil or e.finished_in ~= nil)
		and mergeBlock({ pandoc.Header(6, makeStartedInFinishedIn(e.started_in, e.finished_in, config)) })
		or mergeBlock({}),
		e.organization ~= nil and mergeBlock({ pandoc.Header(6, md(e.organization)) }) or mergeBlock({}),
		e.location ~= nil and mergeBlock({ pandoc.Header(6, md(e.location)) }) or mergeBlock({}),
		mdBlock(e.description),
	})
end

---@param experiences List<experience>
---@param config config
---@return Block
local function makeExperiencesBlock(experiences, config)
	return mergeBlock(experiences:map(function(e)
		return makeExperienceBlock(e, config)
	end) --[[@as List<any>]])
end

---@param cv cv
---@param config config
---@return Pandoc
local function makeCvDocument(cv, config)
	---@type List<string>
	local types = pandoc.List({})
	---@type { [string]: List<experience> }
	local typeToExperiences = {}
	for _, e in ipairs(cv.experiences) do
		if typeToExperiences[e.type] == nil then
			types:insert(e.type)
			typeToExperiences[e.type] = pandoc.List({})
		end
		typeToExperiences[e.type]:insert(e)
	end
	---@type List<{ type: string, experiences: List<experience> }>
	local experienceGroups = pandoc.List({})
	for _, t in ipairs(types) do
		experienceGroups:insert({ type = t, experiences = typeToExperiences[t] })
	end

	local doc = pandoc.Pandoc({
		-- Header
		makeNameRoleContactsBlock(cv.name, cv.role, cv.contacts),
		-- Profile
		pandoc.Header(3, md(config.profile_heading)),
		mdBlock(cv.profile),
		-- Skills
		pandoc.Header(3, md(config.skills_heading)),
		makeSkillsBlock(cv.skills),
		-- Experiences
		mergeBlock(experienceGroups:map(function(g)
			local h = config.experiences_headings[g.type]
			if h == nil then
				log.Error("missing config.experiences_headings for " .. g.type)
				assert(false)
			end
			assert(type(h) == "string")
			return mergeBlock({
				pandoc.Header(3, md(h)),
				makeExperiencesBlock(g.experiences, config),
			})
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
