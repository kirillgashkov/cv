local element = require("internal.element")
local file = require("internal.file")
local fun = require("internal.fun")
local log = require("internal.log")

local md = element.Md
local mdBlock = element.MdBlock
local merge = element.Merge
local mergeBlock = element.MergeBlock

---@param s string
---@return Inline
local raw = function(s)
	return pandoc.RawInline("latex", s)
end

---@param name string
---@param role string
---@param contacts List<contact>
---@return Block
local function makeNameRoleContactsBlock(name, role, contacts)
	return mergeBlock({})
end

---@param name string
---@param role string
---@return Block
local function makeNameAndRoleBlock(name, role)
	return pandoc.Plain({
		merge({ raw([[{]]), raw("\n") }),
		merge({ raw([[  \centering]]), raw("\n") }),
		merge({ raw([[  {\bfseries\scshape\Huge ]]), md(name), raw([[}\par]]), raw("\n") }),
		merge({ raw([[  \vspace{0.125em}]]), raw("\n") }),
		merge({ raw([[  {\scshape\Large ]]), md(role), raw([[}\par]]), raw("\n") }),
		merge({ raw([[  \par]]), raw("\n") }),
		merge({ raw([[}]]), raw("\n") }),
	})
end

---@param contacts List<contact>
---@return Block
local function makeContactsBlock(contacts)
	local colCount = 2
	local rowCount = math.ceil(#contacts / colCount)

	---@type List<List<Inline>>
	local t = pandoc.List({})
	for _ = 1, rowCount do
		---@type List<Inline>
		local r = pandoc.List({})
		for _ = 1, colCount do
			r:insert({})
		end
		t:insert(r)
	end

	for i, contact in ipairs(contacts) do
		-- The indexes are calculated for the transpose of a table with colCount
		-- rows and rowCount columns. This positions the contacts in the table
		-- in the column-major order.
		local ri = ((i - 1) % rowCount) + 1
		local ci = ((i - 1) // rowCount) + 1
		t[ri][ci] = merge({
			merge({ md(contact.name), md(":") }),
			merge({ raw([[ ]]) }),
			merge({ raw([[\texttt]]), raw([[{]]), md(contact.description), raw([[}]]) }),
		})
	end

	local tableBody = merge({
		raw([[    ]]),
		merge(fun.Intersperse(
			t:map(function(r)
				return merge(fun.Intersperse(r, raw([[ & ]])))
			end),
			merge({ raw([[ \\]]), raw("\n"), raw([[    ]]) })
		)),
	})

	return pandoc.Plain({
		merge({ raw([[{]]), raw("\n") }),
		merge({ raw([[  \centering]]), raw("\n") }),
		merge({ raw([[  \begin{tabular}{l@{\hspace{2em}}l}]]), raw("\n") }),
		merge({ tableBody, raw("\n") }),
		merge({ raw([[  \end{tabular}]]), raw("\n") }),
		merge({ raw([[  \par]]), raw("\n") }),
		merge({ raw([[}]]), raw("\n") }),
	})
end

---@param skills List<skill>
local function makeSkillsBlock(skills)
	return pandoc.Plain({
		merge({ raw([[\begin{itemize}[leftmargin=0pt,label={}] ]]), raw("\n") }),
		merge(skills:map(function(s)
			return merge({
				raw([[\item]]),
				pandoc.Strong({ md(s.name), pandoc.Str(":") }),
				pandoc.Space(),
				pandoc.Span(md(s.description)),
				raw("\n"),
			})
		end) --[[@as List<any>]]),
		merge({ raw([[\end{itemize}]]), raw("\n") }),
	})
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
	-- stylua: ignore
	return mergeBlock({
		pandoc.Plain({
			merge({ raw([[{]]), raw("\n") }),
			merge({ raw([[  \centering]]), raw("\n") }),
			merge({ raw([[  \begin{tabularx}{\textwidth}{@{}Xr@{}}]]), raw("\n") }),
			merge({
				merge({
					raw([[    ]]),
					pandoc.Strong({ md(e.name) }),
					e.tagline and merge({ pandoc.Space(), md("—"), pandoc.Space(), md(e.tagline) }) or merge({}),
					pandoc.Space(),
					raw("&"),
					pandoc.Space(),
					(e.started_in ~= nil or e.finished_in ~= nil) and
					merge({ makeStartedInFinishedIn(e.started_in, e.finished_in, config) }) or merge({}),
				}),
				(e.organization or e.location) and merge({
					pandoc.Space(),
					raw([[\\]]),
					raw("\n"),
					raw([[    ]]),
					e.organization ~= nil and merge({ md(e.organization) }) or merge({}),
					pandoc.Space(),
					raw("&"),
					pandoc.Space(),
					e.location ~= nil and merge({ md(e.location) }) or merge({}),
				}) or merge({}),
				merge({ raw("\n") }),
			}),
			merge({ raw([[  \end{tabularx}]]), raw("\n") }),
			merge({ raw([[  \par]]), raw("\n") }),
			merge({ raw([[}]]), raw("\n") }),
		}),
		pandoc.Plain({ raw([[\vspace{0.5em}]]) }),
		mdBlock(e.description)
	})
end

---@param experiences List<experience>
---@param config config
---@return Block
local function makeExperiencesBlock(experiences, config)
	return mergeBlock(fun.Intersperse(
		experiences:map(function(e)
			return makeExperienceBlock(e, config)
		end) --[[@as List<any>]],
		pandoc.Plain({ raw([[\vspace{0.5em}]]) })
	))
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
		pandoc.Header(1, md(config.profile_heading)),
		mdBlock(cv.profile),
		-- Skills
		pandoc.Header(1, md(config.skills_heading)),
		-- makeSkillsBlock(cv.skills),
		-- Experiences
		mergeBlock(experienceGroups:map(function(g)
			local h = config.experiences_headings[g.type]
			if h == nil then
				log.Error("missing config.experiences_headings for " .. g.type)
				assert(false)
			end
			assert(type(h) == "string")
			return mergeBlock({
				pandoc.Header(1, md(h)),
				makeExperiencesBlock(g.experiences, config),
			})
		end) --[[@as any]]),
	})

	doc = doc:walk({
		---Manually writes link to remove \nolinkurl from the output. With the
		---default writer this would affect the links with URI content.
		---@param link Link
		---@return Inlines
		Link = function(link)
			if link.title ~= "" then
				log.Warning("link title is not supported")
			end
			return {
				raw([[\href]]),
				raw([[{]]),
				pandoc.Str(link.target),
				raw([[}]]),
				raw([[{]]),
				merge(link.content),
				raw([[}]]),
			}
		end,

		---Prevents Pandoc from injecting \def\labelenumi{\arabic{enumi}.} into
		---ordered lists by resetting the style and delimiter list attributes.
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

	doc.meta.template = { i18n = { language = config.babel_language } }

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
	local templateFile = pandoc.path.join({ pandoc.path.directory(scriptPath), "template.tex" })
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
	io.stdout:write(pandoc.write(doc, "latex", { template = makeTemplate(arg[0]) }))
end
