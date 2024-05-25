local file = require("file")
local fun = require("fun")
local log = require("log")

assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

local mdFormat = "gfm-yaml_metadata_block"

---@param attr Attr
---@return string|nil
local function getSource(attr)
	return attr.attributes["data-pos"]
end

---@param attr Attr
---@return boolean
local function isMerge(attr)
	return attr.attributes["data-template--is-merge"] == "1"
end

---@param inlines Inlines
---@return Inline
local function merge(inlines)
	local i = pandoc.Span(inlines)
	i.attr.attributes["data-template--is-merge"] = "1"
	return i
end

---@param blocks Blocks
---@return Block
local function mergeBlock(blocks)
	local b = pandoc.Div(blocks)
	b.attr.attributes["data-template--is-merge"] = "1"
	return b
end

---@param s string
---@return Inline
local function raw(s)
	return merge(pandoc.Inlines({ pandoc.RawInline("latex", s) }))
end

---@param s string
---@return Inline
local function str(s)
	return pandoc.Str(s)
end

---@return Inline
local function space()
	return pandoc.Space()
end

---@param s string
---@return Inline
local function md(s)
	return merge(pandoc.utils.blocks_to_inlines(pandoc.read(s, "gfm").blocks))
end

---@param s string
---@return Block
local function mdBlock(s)
	return mergeBlock(pandoc.read(s, mdFormat).blocks)
end

local function formatDate(year, month, day, formatString, config)
	return formatString
		:gsub("%%B", tostring(config.date_months[month]))
		:gsub("%%e", tostring(day))
		:gsub("%%Y", tostring(year))
end

---@param dateString string # Examples: 2020, 2020-01, 2020-01-01
---@param config any
local function makeDate(dateString, config)
	local year = nil
	local month = nil
	local day = nil
	if #dateString == 4 then
		year = dateString:match("(%d%d%d%d)")
		year = tonumber(year)
	elseif #dateString == 7 then
		year, month = dateString:match("(%d%d%d%d)%-(%d%d)")
		year, month = tonumber(year), tonumber(month)
	elseif #dateString == 10 then
		year, month, day = dateString:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
		year, month, day = tonumber(year), tonumber(month), tonumber(day)
	else
		assert(false)
	end

	if year ~= nil and month ~= nil and day ~= nil then
		return formatDate(year, month, day, config.date_formats.year_month_day, config)
	elseif year ~= nil and month ~= nil then
		return formatDate(year, month, nil, config.date_formats.year_month, config)
	elseif year ~= nil then
		return formatDate(year, nil, nil, config.date_formats.year, config)
	else
		assert(false)
	end
end

---@param startDateString string
---@param endDateString? string
---@param config any
---@return string
local function makeDateRange(startDateString, endDateString, config)
	local start_date = makeDate(startDateString, config)
	local end_date = endDateString and makeDate(endDateString, config) or config.date_present

	if start_date == end_date then
		return start_date
	else
		return start_date .. " — " .. end_date
	end
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
				space(),
				pandoc.Span(md(s.description)),
				raw("\n"),
			})
		end)),
		merge({ raw([[\end{itemize}]]), raw("\n") }),
	})
end

---@param i item
---@param config config
---@return Block
local function makeItemBlock(i, config)
  -- stylua: ignore
	return mergeBlock({
    pandoc.Plain({
      merge({ raw([[{]]), raw("\n") }),
      merge({ raw([[  \centering]]), raw("\n") }),
      merge({ raw([[  \begin{tabularx}{\textwidth}{@{}Xr@{}}]]), raw("\n") }),
      merge({
        merge({
          raw([[    ]]),
          pandoc.Strong(i.organization ~= nil and { md(i.name), space(), str(config.experience_at), space(), md(i.organization) } or { md(i.name) }),
          space(),
          raw("&"),
          space(),
          (i.started_in ~= nil or i.finished_in ~= nil) and merge({ str(makeDateRange(i.started_in, i.finished_in, config)) }) or merge({}),
        }),
        (i.suborganization or i.location) and merge({
          space(),
          raw([[\\]]),
          raw("\n"),
          raw([[    ]]),
          i.suborganization ~= nil and merge({ md(i.suborganization) }) or merge({}),
          space(),
          raw("&"),
          space(),
          i.location ~= nil and merge({ md(i.location) }) or merge({}),
        }) or merge({}),
        merge({ raw("\n") }),
      }),
      merge({ raw([[  \end{tabularx}]]), raw("\n") }),
      merge({ raw([[  \par]]), raw("\n") }),
      merge({ raw([[}]]), raw("\n") }),
    }),
    pandoc.Plain({ raw([[\vspace{0.5em}]]) }),
    mdBlock(i.description)
  })
end

---@param cv cv
---@param config config
---@return Pandoc
local function makeCvBlock(cv, config)
	local doc = pandoc.Pandoc({
		-- Header
		makeNameAndRoleBlock(cv.name, cv.role),
		pandoc.Plain({ raw([[\vspace{1em}]]) }),
		makeContactsBlock(cv.contacts),
		-- Main
		pandoc.Header(1, md(config.profile_header)),
		mdBlock(cv.profile),
		pandoc.Header(1, md(config.skills_header)),
		makeSkillsBlock(cv.skills),
		pandoc.Header(1, md(config.projects_header)),
		mergeBlock(cv.projects:map(function(p)
			return makeItemBlock(p, config)
		end)),
		pandoc.Header(1, md(config.experience_header)),
		mergeBlock(cv.experience:map(function(e)
			return makeItemBlock(e, config)
		end)),
		pandoc.Header(1, md(config.education_header)),
		mergeBlock(cv.education:map(function(e)
			return makeItemBlock(e, config)
		end)),
	})

	doc = doc:walk({
		---Manually writes link to remove \nolinkurl from the output. With the
		---default writer this would affect the links with URI content.
		---@param link Link
		---@return Inlines
		Link = function(link)
			if link.title ~= "" then
				log.Warning("link title is not supported", getSource(link.attr))
			end
			return {
				raw([[\href]]),
				raw([[{]]),
				str(link.target),
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
			if isMerge(div.attr) then
				return div.content
			end
			return div
		end,

		---@param span Span
		---@return Span | Inlines
		Span = function(span)
			if isMerge(span.attr) then
				return span.content
			end
			return span
		end,
	})

	doc.meta.template = { i18n = { language = config.language } }

	return doc
end

---@param path string
---@return config
local function makeConfig(path)
	return pandoc.json.decode(file.Read(path))
end

---@param scriptPath string
---@return Template
local function makeTemplate(scriptPath)
	print(PANDOC_SCRIPT_FILE)
	local templateFile = pandoc.path.join({ pandoc.path.directory(scriptPath), "template.tex" })
	local templateContent = file.Read(templateFile)
	assert(templateContent ~= nil)
	return pandoc.template.compile(templateContent)
end

---@param path string
---@return cv
local function makeCv(path)
	return pandoc.json.decode(file.Read(path))
end

if arg ~= nil then
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

	local doc = makeCvBlock(cv, config)
	print(pandoc.write(doc, "latex", { template = makeTemplate(arg[0]) }))
end
