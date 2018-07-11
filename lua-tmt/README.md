lua-tmt
-------

Simple lua binding for (libtmt)[https://github.com/deadpixi/libtmt]

Not yet finished or stable or documented or ready in any way!



example
-------
'''
local tmt = require("tmt")
local term = tmt.new(80, 25)
local cursor_x, cursor_y
local events = term:write("Hello World!")
for _,event in ipairs(events) do
	if event.type == "cursor" then
		-- received cursor update
		print("cursor:", event.x, event.y)
	end
end

local function get_line_str(line_t)
	local line = {}
	for k,v in ipairs(line_t) do
		table.insert(line, string.char(v.char))
	end
	return table.concat(line)
end

local function get_term_str(screen)
	local lines = {}
	for _,line in ipairs(screen.lines) do
		table.insert(lines, get_line_str(line))
	end
	return table.concat(lines, "\n")
end

local screen = term:get_screen()
print(get_term_str(screen))

'''
