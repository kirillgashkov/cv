assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

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
          pandoc.Strong({ md(i.name) }),
          pandoc.Space(),
          raw("&"),
          pandoc.Space(),
          (i.started_in_finished_in ~= nil) and merge({ pandoc.Str(i.started_in_finished_in) }) or merge({}),
        }),
        (i.organization or i.location) and merge({
          pandoc.Space(),
          raw([[\\]]),
          raw("\n"),
          raw([[    ]]),
          i.organization ~= nil and merge({ md(i.organization) }) or merge({}),
          pandoc.Space(),
          raw("&"),
          pandoc.Space(),
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
    pandoc.Header(1, md(config.experience_header)),
    mergeBlock(fun.Intersperse(
      cv.experience:map(function(e)
        return makeItemBlock(e, config)
      end) --[[@as List<any>]],
      pandoc.Plain({ raw([[\vspace{0.5em}]]) })
    )),
    pandoc.Header(1, md(config.projects_header)),
    mergeBlock(fun.Intersperse(
      cv.projects:map(function(e)
        return makeItemBlock(e, config)
      end) --[[@as List<any>]],
      pandoc.Plain({ raw([[\vspace{0.5em}]]) })
    )),
    pandoc.Header(1, md(config.education_header)),
    mergeBlock(fun.Intersperse(
      cv.education:map(function(e)
        return makeItemBlock(e, config)
      end) --[[@as List<any>]],
      pandoc.Plain({ raw([[\vspace{0.5em}]]) })
    )),
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

  doc.meta.template = { i18n = { language = config.language } }

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
  io.stdout:write(pandoc.write(doc, "latex", { template = makeTemplate(arg[0]) }))
end
