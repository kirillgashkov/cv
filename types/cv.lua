---@meta

---@class config
---@field language string
---@field profile_header string
---@field skills_header string
---@field experience_header string
---@field projects_header string
---@field education_header string

---@class cv
---@field updated_in string
---@field name string
---@field role string
---@field profile string
---@field contacts List<contact>
---@field skills List<skill>
---@field experience List<experience>
---@field projects List<project>
---@field education List<education>

---@class contact
---@field name string
---@field description string

---@class skill
---@field name string
---@field description string

---@class project
---@field name string
---@field description string
---@field organization? string | nil
---@field started_in_finished_in? string | nil
---@field location? string | nil

---@class education
---@field name string
---@field description string
---@field organization? string | nil
---@field started_in_finished_in? string | nil
---@field location? string | nil

---@class experience
---@field name string
---@field description string
---@field organization? string | nil
---@field started_in_finished_in? string | nil
---@field location? string | nil

---@alias item contact | skill | project | education | experience
