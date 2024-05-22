assert(tostring(PANDOC_API_VERSION) == "1.23.1", "Unsupported Pandoc API")

local file = require("file")
local log = require("log")

---@param s string
---@return Inlines
local function md_inlines(s)
	return pandoc.utils.blocks_to_inlines(pandoc.read(s, "gfm").blocks)
end

---@param s string
---@return Blocks
local function md_blocks(s)
	return pandoc.read(s, "gfm").blocks
end

local function format_date(year, month, day, format_string, config)
	return format_string
		:gsub("%%B", tostring(config.date_months[month]))
		:gsub("%%e", tostring(day))
		:gsub("%%Y", tostring(year))
end

---@param date_string string # Examples: 2020, 2020-01, 2020-01-01
---@param config any
local function make_date(date_string, config)
	local year = nil
	local month = nil
	local day = nil
	if #date_string == 4 then
		year = date_string:match("(%d%d%d%d)")
		year = tonumber(year)
	elseif #date_string == 7 then
		year, month = date_string:match("(%d%d%d%d)%-(%d%d)")
		year, month = tonumber(year), tonumber(month)
	elseif #date_string == 10 then
		year, month, day = date_string:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
		year, month, day = tonumber(year), tonumber(month), tonumber(day)
	else
		assert(false)
	end

	if year ~= nil and month ~= nil and day ~= nil then
		return format_date(year, month, day, config.date_formats.year_month_day, config)
	elseif year ~= nil and month ~= nil then
		return format_date(year, month, nil, config.date_formats.year_month, config)
	elseif year ~= nil then
		return format_date(year, nil, nil, config.date_formats.year, config)
	else
		assert(false)
	end
end

---@param start_date_string string
---@param end_date_string? string
---@param config any
---@return string
local function make_date_range(start_date_string, end_date_string, config)
	local start_date = make_date(start_date_string, config)
	local end_date = end_date_string and make_date(end_date_string, config) or config.date_present

	if start_date == end_date then
		return start_date
	else
		return start_date .. " - " .. end_date
	end
end

---@param _doc Pandoc
---@param opts WriterOptions
---@return string
function Writer(_doc, opts)
	---@type Cv
	local cv = pandoc.json.decode(
		file.read_file(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "example.json" }))
	)
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

	local doc = pandoc.Pandoc(pandoc.Blocks({
		pandoc.Header(1, md_inlines(cv.name)),
		pandoc.Header(2, md_inlines(cv.role)),
		pandoc.BulletList(cv.contacts:map(function(contact)
			return pandoc.Plain({
				pandoc.Span(md_inlines(contact.name)),
				pandoc.Str(": "),
				pandoc.Span(md_inlines(contact.description)),
			})
		end)),
		pandoc.Header(3, md_inlines(config.profile_header)),
		pandoc.Div(md_blocks(cv.profile)),
		pandoc.Header(3, md_inlines(config.skills_header)),
		pandoc.BulletList(cv.skills:map(function(skill)
			return pandoc.Plain({
				pandoc.Strong({ pandoc.Span(md_inlines(skill.name)), pandoc.Str(":") }),
				pandoc.Str(" "),
				pandoc.Span(md_inlines(skill.description)),
			})
		end)),
		pandoc.Header(3, md_inlines(config.projects_header)),
		pandoc.Div(cv.projects:map(function(project)
			return pandoc.Div({
				pandoc.Header(4, md_inlines(project.name)),
				pandoc.Header(6, md_inlines(make_date_range(project.started_in, project.finished_in, config))),
				pandoc.Div(md_blocks(project.description)),
			})
		end)),
		pandoc.Header(3, md_inlines(config.education_header)),
		pandoc.Div(cv.education:map(function(x)
			return pandoc.Div({
				pandoc.Header(4, md_inlines(x.name)),
				pandoc.Header(6, md_inlines(make_date_range(x.started_in, x.finished_in, config))),
				(x.organization ~= nil and pandoc.Header(6, md_inlines(x.organization)) or pandoc.Div({})),
				(x.suborganization ~= nil and pandoc.Header(6, md_inlines(x.suborganization)) or pandoc.Div({})),
				pandoc.Div(md_blocks(x.description)),
			})
		end)),
		pandoc.Header(3, md_inlines(config.experience_header)),
		pandoc.Div(cv.experience:map(function(x)
			return pandoc.Div({
				pandoc.Header(4, md_inlines(x.name)),
				pandoc.Header(6, md_inlines(make_date_range(x.started_in, x.finished_in, config))),
				(x.organization ~= nil and pandoc.Header(6, md_inlines(x.organization)) or pandoc.Div({})),
				(x.suborganization ~= nil and pandoc.Header(6, md_inlines(x.suborganization)) or pandoc.Div({})),
				pandoc.Div(md_blocks(x.description)),
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
	local template = file.read_file(pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), "template.md" }))
	assert(template, "Failed to read template file")
	return template
end

---@type { [string]: boolean }
Extensions = {}
