local file = require("file")
local log = require("log")

assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

---@param s string
---@return Inlines
local function parseInlineMarkdown(s)
  return pandoc.utils.blocks_to_inlines(pandoc.read(s, "gfm").blocks)
end

---@param s string
---@return Blocks
local function parseBlockMarkdown(s)
  return pandoc.read(s, "gfm").blocks
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
    return start_date .. " - " .. end_date
  end
end

---@param doc Pandoc
---@param opts WriterOptions
---@return string
function Writer(doc, opts)
  ---@type Cv
  local cv =
    pandoc.json.decode(file.Read(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "example.json" })))
  local config = {
    profile_header = "Profile",
    skills_header = "Skills",
    projects_header = "Projects",
    education_header = "Education",
    experience_header = "Experience",
    date_present = "Present",
    date_months = {
      [1] = "January",
      [2] = "February",
      [3] = "March",
      [4] = "April",
      [5] = "May",
      [6] = "June",
      [7] = "July",
      [8] = "August",
      [9] = "September",
      [10] = "October",
      [11] = "November",
      [12] = "December",
    },
    date_formats = {
      year_month_day = "%B %e, %Y",
      year_month = "%B %Y",
      year = "%Y",
    },
  }

  -- NOTE: Div and Span objects are used here to embed a list of Blocks or Inlines in the output.
  -- An alternative solution of using table.unpack was considered but it seems that it isn't suited
  -- for this case. It behaves differently from python's "...array". There is a different solution
  -- of imperatively appending elements to a table but it seems that it is more verbose and less
  -- readable.

  -- NOTE: Div and Span objects are later stripped from the document by the walk function. If you
  -- use need your own divs and spans, consider marking groupings with a class like ".internal" and
  -- strip only those.

  doc = pandoc.Pandoc(pandoc.Blocks({
    pandoc.Header(1, parseInlineMarkdown(cv.name)),
    pandoc.Header(2, parseInlineMarkdown(cv.role)),
    pandoc.BulletList(cv.contacts:map(function(contact)
      return pandoc.Plain({
        pandoc.Span(parseInlineMarkdown(contact.name)),
        pandoc.Str(": "),
        pandoc.Span(parseInlineMarkdown(contact.description)),
      })
    end)),
    pandoc.Header(3, parseInlineMarkdown(config.profile_header)),
    pandoc.Div(parseBlockMarkdown(cv.profile)),
    pandoc.Header(3, parseInlineMarkdown(config.skills_header)),
    pandoc.BulletList(cv.skills:map(function(skill)
      return pandoc.Plain({
        pandoc.Strong({ pandoc.Span(parseInlineMarkdown(skill.name)), pandoc.Str(":") }),
        pandoc.Str(" "),
        pandoc.Span(parseInlineMarkdown(skill.description)),
      })
    end)),
    pandoc.Header(3, parseInlineMarkdown(config.projects_header)),
    pandoc.Div(cv.projects:map(function(project)
      return pandoc.Div({
        pandoc.Header(4, parseInlineMarkdown(project.name)),
        pandoc.Header(6, parseInlineMarkdown(makeDateRange(project.started_in, project.finished_in, config))),
        pandoc.Div(parseBlockMarkdown(project.description)),
      })
    end)),
    pandoc.Header(3, parseInlineMarkdown(config.education_header)),
    pandoc.Div(cv.education:map(function(x)
      return pandoc.Div({
        pandoc.Header(4, parseInlineMarkdown(x.name)),
        pandoc.Header(6, parseInlineMarkdown(makeDateRange(x.started_in, x.finished_in, config))),
        (x.organization ~= nil and pandoc.Header(6, parseInlineMarkdown(x.organization)) or pandoc.Div({})),
        (x.suborganization ~= nil and pandoc.Header(6, parseInlineMarkdown(x.suborganization)) or pandoc.Div({})),
        pandoc.Div(parseBlockMarkdown(x.description)),
      })
    end)),
    pandoc.Header(3, parseInlineMarkdown(config.experience_header)),
    pandoc.Div(cv.experience:map(function(x)
      return pandoc.Div({
        pandoc.Header(4, parseInlineMarkdown(x.name)),
        pandoc.Header(6, parseInlineMarkdown(makeDateRange(x.started_in, x.finished_in, config))),
        (x.organization ~= nil and pandoc.Header(6, parseInlineMarkdown(x.organization)) or pandoc.Div({})),
        (x.suborganization ~= nil and pandoc.Header(6, parseInlineMarkdown(x.suborganization)) or pandoc.Div({})),
        pandoc.Div(parseBlockMarkdown(x.description)),
      })
    end)),
  }))

  doc = doc:walk({
    ---@param div Div
    ---@return Blocks
    Div = function(div)
      return div.content
    end,

    ---@param span Span
    ---@return Inlines
    Span = function(span)
      return span.content
    end,
  })

  return pandoc.write(doc, "gfm", opts)
end

---@return string
function Template()
  local template = file.Read(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "template.md" }))
  assert(template, "Failed to read template file")
  return template
end

---@type { [string]: boolean }
Extensions = {}
