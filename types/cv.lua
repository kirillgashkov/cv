---@class Cv
---@field updated_in string
---@field name string
---@field role string
---@field profile string
---@field contacts Contact[]
---@field skills Skill[]
---@field projects Project[]
---@field education Education[]
---@field experience Experience[]

---@class Contact
---@field name string
---@field description string

---@class Skill
---@field name string
---@field description string

---@class Project
---@field name string
---@field description string
---@field started_in string
---@field finished_in? string

---@class Education
---@field name string
---@field description string
---@field organization string
---@field suborganization string
---@field location string
---@field started_in string
---@field finished_in? string

---@class Experience
---@field name string
---@field description string
---@field organization string
---@field suborganization string
---@field location string
---@field started_in string
---@field finished_in? string
