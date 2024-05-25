local date = {}

function date.FormatDate(year, month, day, formatString, config)
  return formatString
    :gsub("%%B", tostring(config.date_months[month]))
    :gsub("%%e", tostring(day))
    :gsub("%%Y", tostring(year))
end

---@param dateString string # Examples: 2020, 2020-01, 2020-01-01
---@param config any
function date.MakeDate(dateString, config)
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
    return date.FormatDate(year, month, day, config.date_formats.year_month_day, config)
  elseif year ~= nil and month ~= nil then
    return date.FormatDate(year, month, nil, config.date_formats.year_month, config)
  elseif year ~= nil then
    return date.FormatDate(year, nil, nil, config.date_formats.year, config)
  else
    assert(false)
  end
end

---@param startDateString string
---@param endDateString? string
---@param config any
---@return string
function date.MakeDateRange(startDateString, endDateString, config)
  local start_date = date.MakeDate(startDateString, config)
  local end_date = endDateString and date.MakeDate(endDateString, config) or config.date_present

  if start_date == end_date then
    return start_date
  else
    return start_date .. " — " .. end_date
  end
end

return date
