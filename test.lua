#!/usr/bin/env luajit
local lfb = require("lfb")
local input = require("input")
local font = require("font")
local rote = require("rote")
local time = require("time")
local json = require("cjson")
local utf8 = require("utf8")
local input_event_codes = require("input-event-codes")
local keyboard_german = require("keyboard_layout_german")


local term = rote.RoteTerm(24, 80)
-- local term = rote.RoteTerm(48, 160)

-- local dprint = print
local dprint = function() end


-- todo: use libpty
term:forkPty("bash")
dprint("Started bash with PID " .. term:childPid())


local fb = lfb.new_framebuffer("/dev/fb0")
local varinfo = fb:get_varinfo()
local xres,yres = varinfo.xres, varinfo.yres
dprint("Got resolution: ",xres, yres)

local colors = {
	{  0,  0,  0,255}, -- 0: black
	{128,  0,  0,255}, -- 1: red
	{  0,128,  0,255}, -- 2: green
	{128,128,  0,255}, -- 3: yellow
	{  0,  0,128,255}, -- 4: blue
	{128,  0,128,255}, -- 5: magenta
	{  0,128,128,255}, -- 6: cyan
	{128,128,128,255}  -- 7: white
}
local cursor_color = {255,255,255,255}
local background_color = {0,0,0,255}

dprint("Loading fonts...")
font:load_from_bmp("7x12b", "7x12b.bmp", 7, 12, 16, 16)
font:load_from_bmp("7x12", "7x12.bmp", 7, 12, 16, 16)
font:load_from_bmp("cga", "lcd.bmp", 8, 8, 32, 8)
font:load_from_bmp("lcd", "lcd.bmp", 8, 8, 32, 8)
-- font:set_default("7x12b", "7x12")
font:set_default("cga", "cga")
-- font:set_default("lcd", "lcd")
dprint("ok")

local font_scale_w = 1
local font_scale_h = 2

local char_w, char_h = font:get_char_size("default")
local term_w = term:cols()*char_w * font_scale_w
local term_h = term:rows()*char_h * font_scale_h
local term_db = lfb.new_drawbuffer(term_w, term_h)



local function draw_term_unicode_braile(threshold, color)
	local start = time.realtime()
	
	local threshold = tonumber(threshold) or 0
	
	local m_floor = math.floor
	local m_min = math.min
	local t_insert = table.insert
	local t_concat = table.concat
	local b_bor = bit.bor
	local b_lshift = bit.lshift
	local rows = term:rows()
	local cols = term:cols()
	
	local lines = {}
	
	local function get_pixel(x,y)
		local r,g,b,a = term_db:get_pixel(x,y)
		local sum = (r+g+b)/3
		if sum > threshold then
			return 1
		else
			return 0
		end
	end
    -- render in unicode braile symbols(1 symbel per 2*x and 4*y)
    for y=0, (term_db.height/4)-1 do
		local cline = {}
		for x=0, (term_db.width/2)-1 do
			local rx = x*2
			local ry = y*4
			-- left 3
			local l_1 = get_pixel(rx+0, ry+0)
			local l_2 = b_lshift(get_pixel(rx+0, ry+1), 1)
			local l_3 = b_lshift(get_pixel(rx+0, ry+2), 2)
        
			--right 3
			local r_1 = b_lshift(get_pixel(rx+1, ry+0), 3)
			local r_2 = b_lshift(get_pixel(rx+1, ry+1), 4)
			local r_3 = b_lshift(get_pixel(rx+1, ry+2), 5)
        
			--bottom 2
			local l_4 = b_lshift(get_pixel(rx+0, ry+3), 6)
			local r_4 = b_lshift(get_pixel(rx+1, ry+3), 7)
        
			if color then
				local term_x = m_floor((x*2/font_scale_w)/char_w)
				local term_y = m_floor((y*4/font_scale_h)/char_h)
				local fg, bg, bold, blink = rote.fromAttr(term:cellAttr(m_min(term_y, rows-1),m_min(term_x, cols-1)))
				t_insert(cline, "\027[" .. (30+fg) .. "m")
			end
			local sum = l_1 + l_2 + l_3 + l_4 + r_1 + r_2 + r_3 + r_4
			if sum > 0 then
				cline[#cline+1] = utf8.char(0x2800 + sum)
			else
				cline[#cline+1] = " "
			end
		end
		lines[#lines + 1] = ":" .. t_concat(cline) .. ":"
    end
    dprint("unicode rendering took", (time.realtime() - start)*1000)
    print("." .. ("."):rep(term_db.width/2) .. ".")
    print(t_concat(lines, "\n"))
    print("'" .. ("'"):rep(term_db.width/2) .. "'")
    -- io.flush()
end





local function render_term_framebuffer(scale_w, scale_h)

	term_db:clear(0,0,0, 255)
	
	local m_floor = math.floor
	local m_min = math.min
	local t_insert = table.insert
	local t_concat = table.concat
	local b_bor = bit.bor
	local b_lshift = bit.lshift
	local b_lshift = bit.lshift
	local rows = term:rows()
	local cols = term:cols()
	local s_byte = string.byte
	
	local scale_w = m_floor(tonumber(scale_w) or 1)
	local scale_h = m_floor(tonumber(scale_h) or 1)
	
	local debug_t = {}
	
	-- draw content
	for y=0, rows-1 do
		for x=0, cols-1 do
			local char = s_byte(term:cellChar(y,x))
			local fg, bg, bold, blink = rote.fromAttr(term:cellAttr(y,x))
			
			-- set background
			term_db:set_rect(x*char_w*scale_w, y*char_h*scale_h, char_w*scale_w, char_h*scale_h, unpack(colors[bg+1]))
			
			if char ~= 0 and char ~= 32 then
				-- draw character
				local font_str = bold and "default_bold" or "default"
				local db = font:render_char_to_db(font_str, char, scale_w, scale_h, colors[fg+1])
				db:draw_to_drawbuffer(term_db, x*char_w*scale_w, y*char_h*scale_h, 0,0, char_w*scale_w, char_h*scale_h)
			end
		end
	end

	-- draw cursor
	local cx = term:col() * char_w * scale_w
	local cy = term:row() * char_h * scale_h + char_h*scale_h - 2*scale_h
	term_db:set_rect(cx,cy, char_w*scale_w, 2*scale_h, unpack(cursor_color))
	
end





local function get_input_devices(nonblocking)
	local inputs = {
		all = {},
		keyboards = {},
		mice = {},
	}
	for k,v in ipairs(input.list()) do
		if v.handlers and v.handlers:match("(event%d+)") then
			local ev = v.handlers:match("(event%d+)")
			local path = "/dev/input/" .. ev
			local info = {
				ev = ev,
				path = path,
				dev = assert(input.open(path, nonblocking))
			}
			table.insert(inputs.all, info)
			if v.handlers:match("kbd") then
				info.is_kbd = true
				table.insert(inputs.keyboards, info)
			elseif v.handlers:match("mouse%d+") then
				info.is_mouse = true
				table.insert(inputs.mice, info)
			end
		end
	end
	return inputs
end



local lshift_down = false
local ralt_down = false
local lctrl_down = false
local function resolve_key(ev)
	if (ev.value == 1) or (ev.value == 2) then
		-- key down/key repeat
		if ev.code == input_event_codes.KEY_LEFTSHIFT then
			lshift_down = true
		elseif ev.code == input_event_codes.KEY_LEFTCTRL then
			lctrl_down = true
		elseif ev.code == input_event_codes.KEY_RIGHTALT then
			ralt_down = true
		end
		if keyboard_german[ev.code] then
			local norm, caps, ctrl, alt = unpack(keyboard_german[ev.code])
			if (not lshift_down) and (not lctrl_down) and (not ralt_down) then
				return norm
			elseif lshift_down and (not lctrl_down) and (not ralt_down) then
				return caps
			elseif (not lshift_down) and lctrl_down and (not ralt_down) then
				return ctrl
			elseif (not lshift_down) and (not lctrl_down) and ralt_down then
				return alt
			end
		end
	elseif ev.value == 0 then
		-- key up
		if ev.code == input_event_codes.KEY_LEFTSHIFT then
			lshift_down = false
		elseif ev.code == input_event_codes.KEY_LEFTCTRL then
			lctrl_down = false
		elseif ev.code == input_event_codes.KEY_RIGHTALT then
			ralt_down = false
		end
	end
end



local function handle_ev_kbd(ev, dev_info)
	if ev.type == input_event_codes.EV_KEY then
		local val = resolve_key(ev)
		if val then
			term:write(val)
		end
	end
end



local function handle_ev_mouse(ev, dev_info)

end



local function handle_ev_debug(ev, dev_info)
	local function list_by_pattern_value(pattern, value)
		for k,v in pairs(input_event_codes) do
			if k:match(pattern) and v == value then
				return k,v
			end
		end
	end

	local type = list_by_pattern_value("^EV_", ev.type) or ""
	local code
	if type == "EV_KEY" then
		code = list_by_pattern_value("^KEY_", ev.code) or list_by_pattern_value("^BTN_", ev.code)
	elseif type == "EV_ABS" then
		code = list_by_pattern_value("^ABS_", ev.code)
	elseif type == "EV_REL" then
		code = list_by_pattern_value("^REL_", ev.code)
	end
	code = code or ""
	
	print(("\nGot event: path=%q, time=%d, utime=%06d, type=%12s(0x%03X), code=%18s(0x%03X), value=0x%016X"):format(dev_info.path, ev.time, ev.utime, type, ev.type, code, ev.code, ev.value))
end



local devs = get_input_devices(true)
local function check_input()
	for k,info in ipairs(devs.keyboards) do
		local ev = info.dev:read()
		if ev and ev.type ~= input_event_codes.EV_SYN then
			handle_ev_kbd(ev, info)
			handle_ev_debug(ev, info)
		end
	end
end


local ev = 0
local path = "/dev/input/event" .. ev
local dev = input.open(path, true)
local code_ev_syn = input_event_codes.EV_SYN
local function check_input_dbg()
	local ev = dev:read()
	if ev and ev.type ~= code_ev_syn then
		local info = {
			path = path,
			ev = ev,
			dev = dev
		}
		handle_ev_kbd(ev, info)
		handle_ev_debug(ev, info)
	end
end


local draw_framebuffer = false
local draw_unicode = false

local last = time.realtime()
local c = 0
local function loop()
	while true do
		check_input_dbg()
		term:update()
		local start = time.realtime()
		render_term_framebuffer(font_scale_w,font_scale_h)
		dprint("Update took " .. (time.realtime()-start)*1000 ..  " ms")

		c = c + 1
		if c > 1000 then
			font:_sort_cache()
			c = 0
		end

		if draw_framebuffer then
			local start = time.realtime()
			term_db:draw_to_framebuffer(fb, 0,0)
			dprint("Drawing on framebuffer took " .. (time.realtime()-start)*1000 ..  " ms")
		end

		if draw_unicode then
			local start = time.realtime()
			draw_term_unicode_braile(nil, true)
			dprint("Drawing to terminal took " .. (time.realtime()-start)*1000 ..  " ms")
		end
		
		local fps = 1/(time.realtime() - last)
		last = time.realtime()
		dprint("FPS:", fps)
		dprint()
		io.flush()
	end
end


loop()
