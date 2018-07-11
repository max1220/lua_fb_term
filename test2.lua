#!/usr/bin/env luajit
local terminal = require("terminal")
local keyboard = require("keyboard")
local font = require("font")
local time = require("time")
local lfb = require("lfb")
local mice = require("mice")
local bitmap = require("bitmap")

print("Loading fonts...")
font:load_from_bmp("7x12b", "7x12b.bmp", 7, 12, 16, 16)
font:load_from_bmp("7x12", "7x12.bmp", 7, 12, 16, 16)
font:load_from_bmp("cga", "lcd.bmp", 8, 8, 32, 8)
font:load_from_bmp("lcd", "lcd.bmp", 8, 8, 32, 8)
font:set_default("7x12b", "7x12")
print("ok")


local term_config = {
	w = 80,
	h = 25,
	command = "bash",
	font_normal = "7x12b",
	font_bold = "7x12",
	font_scale_w = 1,
	font_scale_h = 1,
}

local term = terminal.new(term_config)

local kbd = keyboard.open({
	path = "/dev/input/event0",
	nonblocking = true
})

local mouse = mice.open({
	path = "/dev/input/event3",
	nonblocking = true
})


local color = true
function kbd:key_callback(key)
	if type(key) == "string" then
		term:write(key)
	elseif type(key) == "table" then
		if key[1] == "toggle_color" then
			color = not color
			term:update_config()
		elseif key[1] == "increase_font_size" then
			term_config.font_scale_w = math.min(term_config.font_scale_w + 1, 4)
			term_config.font_scale_h = math.min(term_config.font_scale_h + 1, 4)
			term:update_config()
			mouse:set_dimensions(term.db.width, term.db.height)
		elseif key[1] == "decrease_font_size" then
			term_config.font_scale_w = math.max(term_config.font_scale_w - 1, 1)
			term_config.font_scale_h = math.max(term_config.font_scale_h - 1, 1)
			term:update_config()
			mouse:set_dimensions(term.db.width, term.db.height)
		elseif key[1] == "set_font_scale" then
			term_config.font_scale_w = tonumber(arg[2]) or term_config.font_scale_w
			term_config.font_scale_h = tonumber(arg[3]) or term_config.font_scale_h
			term:update_config()
		elseif key[1] == "set_font" then
			term_config.font_normal = arg[2] or term_config.font_normal
			term_config.font_bold = arg[3] or term_config.font_bold
			term:update_config()
		end
	end
end


local pointer_db_a = lfb.new_drawbuffer(8, 16)
local pointer_db_b = lfb.new_drawbuffer(8, 16)
local pointer_img = bitmap.from_file("pointer.bmp")
for cy=0, 15 do
	for cx=0, 7 do
		local a = 0xFF
		local r,g,b = pointer_img:get_pixel(cx,cy)
		if r == 0xFF and g == 0x00 and b == 0xFF then
			-- transparency index is r=0xFF g=0x00 b=0xFF ('debug pink')
			a = 0x00
		end
		pointer_db_a:set_pixel(cx,cy,r,g,b,a)
		
		r,g,b = pointer_img:get_pixel(cx+8,cy)
		if r == 0xFF and g == 0x00 and b == 0xFF then
			a = 0x00
		end
		pointer_db_b:set_pixel(cx,cy,r,g,b,a)
	end
end







local fb = lfb.new_framebuffer("/dev/fb0")
local varinfo = fb:get_varinfo()
local screen_w = varinfo.xres
local screen_h = varinfo.yres
local screen_db = lfb.new_drawbuffer(screen_w, screen_h)

mouse:set_dimensions(screen_w-1, screen_h-1)
mouse:set_sensitivity(0.5)


function mouse:click_callback(x,y, d_y,d_y)
	-- print("lmb click x,y, d_y,d_y", x,y, d_y,d_y)
end

function mouse:rightclick_callback(x,y, d_y,d_y)
	-- print("rmb click x,y, d_y,d_y", x,y, d_y,d_y)
end


print("Loading BG image...")
local bg_img = bitmap.from_file("bg.bmp")
local bg_db = lfb.new_drawbuffer(bg_img.width, bg_img.height)
for y=0, bg_db.height - 1 do
	for x=0, bg_db.width - 1 do
		local r,g,b = bg_img:get_pixel(x,y)
		if r and g and b then
			bg_db:set_pixel(x,y,r,g,b,255)
		end
	end
end
print("ok")


local c = 0
local term_x = 0
local term_y = 0
local fps = 0

local decorate_buffers = {
	{
		db = term.db,
		title = "term db",
		moveable = true,
		x = 0,
		y = 0
	}
}
local click_areas = {}

local char_w, char_h = font:get_char_size("7x12b",scale_w, scale_h)
local function font_draw_str(tdb, x, y, str, _font, scale_w, scale_h, fg_color, bg_color)
	local _font = _font or "7x12b"
	local scale_w = scale_w or 1
	local scale_h = scale_h or 1
	local fg_color = fg_color or {255,255,255,255}
	local bg_color = bg_color or {0,0,0,255}
	color = color or {255,255,255,255}
	for i=1, #str do
		local char = string.byte(str:sub(i,i))
		local db = font:render_char_to_db(_font, char, scale_w, scale_h, fg_color, bg_color)
		db:draw_to_drawbuffer(tdb, x,y, 0,0, db.width, db.height)
		x = x + char_w*scale_w
	end
end

local screen_elements = {}

local bg_element = {
	title = "background",
	db = bg_db,
	x = 0,
	y = 0,
	draw_titlebar = false,
	hidden = false,
	order = -1000,
	uncliclable = true
}
table.insert(screen_elements, bg_element)

local pointer_element = {
	title = "pointer",
	db = pointer_db_a,
	x = 0,
	y = 0,
	draw_titlebar = false,
	hidden = false,
	order = 1000,
	unclickable = true
}
table.insert(screen_elements, pointer_element)

local term_element = {
	title = "terminal",
	db = term.db,
	x = 100,
	y = 100,
	draw_titlebar = true,
	hidden = false,
	order = 1,
}
table.insert(screen_elements, term_element)



local function draw_titlebar(e)
	local titlebar_font = "7x12b"
	local titlebar_font_scale = 1
	local titlebar_bg_color = {32,32,32,255}
	local titlebar_fg_color = {255,255,255,255}
	local titlebar_border_color = {16,16,16,255}
	local char_w, char_h = font:get_char_size(titlebar_font, titlebar_font_scale, titlebar_font_scale)
	local titlebar_border = 2
	local e_width = e.width or e.db.width
	local e_height = e.height or e.db.height
	local titlebar_db_width = e_width + titlebar_border*2
	local titlebar_db_height = e_height + char_h + titlebar_border*3 + 2
	
	local titlebar_db = lfb.new_drawbuffer(titlebar_db_width, titlebar_db_height)
	titlebar_db:clear(unpack(titlebar_border_color))
	
	-- draw titlebar background
	titlebar_db:set_rect(titlebar_border,titlebar_border, titlebar_db_width-2*titlebar_border,char_h+2, unpack(titlebar_bg_color))
	
	-- draw titlebar
	font_draw_str(titlebar_db, titlebar_border+2, titlebar_border+1, e.title, titlebar_font, titlebar_font_scale, titlebar_font_scale, titlebar_fg_color, titlebar_bg_color)
	
	titlebar_db:draw_to_drawbuffer(screen_db, e.x - titlebar_border, e.y - (2*titlebar_border+char_h+2), 0,0, titlebar_db_width, titlebar_db_height)
	return titlebar_db
end

local function resort_screen_elements(elements, reverse)
	local elements = elements or screen_elements
	if reverse then
		table.sort(elements, function(a,b)
			return a.order > b.order
		end)
	else
		table.sort(elements, function(a,b)
			return a.order < b.order
		end)
	end
	return elements
end

local function cords_in_rect(x,y, r_x,r_y, r_w,r_h)
	if (x < r_x) or (y < r_y) then
		return
	end
	if (x > r_x+r_w) or (y > r_y+r_h) then
		return
	end
	local l_x = x - r_x 
	local l_y = y - r_y
	return l_x, l_y
end

local function draw_screen_elements()
	for k,v in ipairs(screen_elements) do
		if not v.hidden then
			if v.draw_titlebar then
				draw_titlebar(v)
			end
			v.db:draw_to_drawbuffer(screen_db, v.x,v.y, 0,0, v.width or v.db.width,v.height or v.db.height)
		end
	end
end

local function get_screen_elements_at(x,y, reverse)
	local elements = {}
	for k,element in ipairs(screen_elements) do
		if cords_in_rect(x,y,element.x,element.y,element.width or element.db.width, element.height or element.db.height) then
			table.insert(elements, element)
		end
	end
	resort_screen_elements(elements, reverse)
	return elements
end




print("Entering main loop")
resort_screen_elements()
local move_element
while true do
	
	local start = time.realtime()

	-- let the mouse & keyboard handle events
	kbd:update()
	mouse:update()
	
	if mouse.lmb then
		if kbd.ralt_down then
			local x,y = mouse:get_pos()
			if move_element then
				move_element.e.x = x - move_element.xo
				move_element.e.y = y - move_element.yo
			else
				local current_element = get_screen_elements_at(x,y, true)[1]
				if current_element and not current_element.unclickable then
					local xo = x - current_element.x
					local yo = y - current_element.y
					move_element = {
						e = current_element,
						xo = xo,
						yo = yo
					}
				end
			end
		else
			move_element = nil
		end
	end
	
	-- render the terminal to it's drawbuffer
	term:render()
	-- term:draw_unicode(nil, color)

	-- update mouse position
	local x,y = mouse:get_pos()
	pointer_element.x = x
	pointer_element.y = y
	
	-- draw elements to the drawbuffer
	draw_screen_elements()
	
	if c > 120 then
		-- every few iterations, resort the font cache for faster character drawing
		font:_sort_cache()
		c = 0
	end
	
	-- draw last fps value
	font_draw_str(screen_db, 0,0, ("FPS: %.3f"):format(fps), "cga", 3, 3, {0xFF,0x00,0xFF,0xFF}, {0,0,0,0})
	
	-- draw the screen_db to the framebuffer
	screen_db:draw_to_framebuffer(fb, 0,0)
	
	-- update fps
	fps = 1/(time.realtime() - start)
	
	-- for less CPU utilization
	time.sleep(0.0005)
end
