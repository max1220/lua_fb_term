#!/usr/bin/env lua
local tmt = require("tmt")
local function td(t, i)
	local i = tonumber(i) or 0
	for k,v in pairs(t) do
		print(("\t"):rep(i)..tostring(k),tostring(v))
		if type(v) == "table" then
			td(v, i+1)
		end
	end
end

print("Creating new term")
local term = tmt.new(25, 80)
print("got terminal", term, "testing writing(getting events)")
local events = term:write("Hello World!\n")
print("events:", events)
td(events)
print("getting screen")
local screen = term:get_screen()

local function get_line_str(line_t)
	local line = {}
	for k,v in ipairs(line_t) do
		table.insert(line, string.char(v.char))
	end
	return table.concat(line)
end

local function get_term_str()
	local lines = {}
	for _,line in ipairs(screen.lines) do
		table.insert(lines, get_line_str(line))
	end
	return table.concat(lines, "\n")
end
print(get_term_str())
