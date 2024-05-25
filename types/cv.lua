---@meta

---@class config
---@field date_formats { year: string, year_month: string, year_month_day: string }
---@field date_months { [1]: string, [2]: string, [3]: string, [4]: string, [5]: string, [6]: string, [7]: string, [8]: string, [9]: string, [10]: string, [11]: string, [12]: string }
---@field date_present string
---@field education_header string
---@field experience_at string
---@field experience_header string
---@field profile_header string
---@field projects_header string
---@field skills_header string
---@field language string

---@class cv
---@field updated_in string
---@field name string
---@field role string
---@field profile string
---@field contacts contact[]
---@field skills skill[]
---@field experience experience[]
---@field projects project[]
---@field education education[]

---@class contact
---@field name string
---@field description string

---@class skill
---@field name string
---@field description string

---@class project
---@field name string
---@field description string
---@field started_in string
---@field finished_in? string

---@class education
---@field name string
---@field description string
---@field organization string
---@field suborganization string
---@field location string
---@field started_in string
---@field finished_in? string

---@class experience
---@field name string
---@field description string
---@field organization string
---@field suborganization string
---@field location string
---@field started_in string
---@field finished_in? string

---@alias item contact | skill | project | education | experience
