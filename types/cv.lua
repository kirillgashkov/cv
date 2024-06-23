---@meta

---@class config
---@field babel_language string
---@field header_colwidths { [1]: number, [2]: number, [3]: number }
---@field profile_heading string
---@field skills_heading string
---@field experiences_headings { [string]: string }
---@field updated_ins { [string]: string }
---@field started_in_finished_ins { [string]: string }

---@class cv
---@field updated_in string
---@field name string
---@field role string
---@field profile string
---@field contacts List<contact>
---@field skills List<skill>
---@field experiences List<experience>

---@class contact
---@field name string
---@field description string

---@class skill
---@field name string
---@field tagline? string | nil
---@field description string

---@class experience
---@field type string
---@field name string
---@field tagline? string | nil
---@field description string | nil
---@field organization? string | nil
---@field location? string | nil
---@field started_in? string | nil
---@field finished_in? string | nil

---@alias item contact | skill | experience
