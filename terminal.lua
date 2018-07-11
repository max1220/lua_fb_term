local rote = require("rote")
local utf8 = require("utf8")
local font = require("font")
local lfb = require("lfb")
local time = require("time")



local terminal = {}
function terminal.new(config)
	local term = {}
	
	-- upvalues for faster access
	local rows, cols, fg_colors, bg_colors, cursor_color, background_color, font_normal, font_bold, font_scale_w, font_scale_h, char_w, char_h, term_w, term_h, term_db
	
	function term:update_config(alternative_config)
		-- recalculate geometry etc.
		local n_config = alternative_config or config
		config = n_config
		term.config = n_config
	
		rows = tonumber(config.rows) or tonumber(config.h) or 24
		cols = tonumber(config.cols) or tonumber(config.w) or 80

		fg_colors = config.fg_colors or {
			{  0,  0,  0,255}, -- 0: black
			{128,  0,  0,255}, -- 1: red
			{  0,128,  0,255}, -- 2: green
			{128,128,  0,255}, -- 3: yellow
			{  0,  0,128,255}, -- 4: blue
			{128,  0,128,255}, -- 5: magenta
			{  0,128,128,255}, -- 6: cyan
			{128,128,128,255}  -- 7: white
		}
		
		bg_colors = config.bg_colors or config.fg_colors or {
			{  0,  0,  0,255}, -- 0: black
			{128,  0,  0,255}, -- 1: red
			{  0,128,  0,255}, -- 2: green
			{128,128,  0,255}, -- 3: yellow
			{  0,  0,128,255}, -- 4: blue
			{128,  0,128,255}, -- 5: magenta
			{  0,128,128,255}, -- 6: cyan
			{128,128,128,255}  -- 7: white
		}
		
		cursor_color = config.cursor_color or {255,255,255,255}
		background_color = config.background_color or {0,0,0,255}
		
		font_normal = config.font_normal or "default"
		font_bold = config.font_bold or "default_bold"
		
		font_scale_w = tonumber(config.font_scale_w) or 1
		font_scale_h = tonumber(config.font_scale_h) or 1

		char_w, char_h = font:get_char_size(font_normal)
		term_w = cols * char_w * font_scale_w
		term_h = rows * char_h * font_scale_h
		term_db = lfb.new_drawbuffer(term_w, term_h)

		term.db = term_db
	end
	term:update_config()


	local rterm = rote.RoteTerm(rows, cols)
	if config.command then
		rterm:forkPty(config.command)
	end
	term.rterm = rterm
	
	
	function term:render()
		rterm:update()
	
		local m_floor = math.floor
		local m_min = math.min
		local t_insert = table.insert
		local t_concat = table.concat
		local b_bor = bit.bor
		local b_lshift = bit.lshift
		local b_lshift = bit.lshift
		local s_byte = string.byte
		
		local scale_w = font_scale_w
		local scale_h = font_scale_h
		
		local debug_t = {}
		
		-- draw content
		for y=0, rows-1 do
			for x=0, cols-1 do
				local char = s_byte(rterm:cellChar(y,x))
				local fg, bg, bold, blink = rote.fromAttr(rterm:cellAttr(y,x))
				
				-- draw background
				term_db:set_rect(x*char_w*scale_w, y*char_h*scale_h, char_w*scale_w, char_h*scale_h, unpack(bg_colors[bg+1]))
				
				if char ~= 0 and char ~= 32 then
					-- draw character
					local font_str = bold and font_bold or font_normal
					local db = font:render_char_to_db(font_str, char, scale_w, scale_h, fg_colors[fg+1])
					db:draw_to_drawbuffer(term_db, x*char_w*scale_w, y*char_h*scale_h, 0,0, char_w*scale_w, char_h*scale_h)
				end
			end
		end

		-- draw cursor
		if math.floor(time.realtime()*2)%2 == 1 then
			local cx = rterm:col() * char_w * scale_w
			local cy = rterm:row() * char_h * scale_h + char_h*scale_h - 2*scale_h
			term_db:set_rect(cx,cy, char_w*scale_w, 2*scale_h, unpack(cursor_color))
		end
	end
	
	function term:write(str)
		rterm:write(str)
	end
	
	function term:draw_unicode(threshold, color)	
		local threshold = tonumber(threshold) or 0
		
		local m_floor = math.floor
		local m_min = math.min
		local t_insert = table.insert
		local t_concat = table.concat
		local b_bor = bit.bor
		local b_lshift = bit.lshift
		local rows = rows
		local cols = cols
		
		local lines = {}
		
		local unicode_lookup = {
			[0] = " "
		}
		for i=1, 255 do
			unicode_lookup[i] = utf8.char(0x2800 + i)
		end
		
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
			local last_fg
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
					local fg, bg, bold, blink = rote.fromAttr(rterm:cellAttr(m_min(term_y, rows-1),m_min(term_x, cols-1)))
					if fg ~= last_fg then
						cline[#cline+1] = "\027[" .. (30+fg) .. "m"
						last_fg = fg
					end
				end
				local sum = l_1 + l_2 + l_3 + l_4 + r_1 + r_2 + r_3 + r_4
				cline[#cline+1] = unicode_lookup[sum]
			end
			lines[#lines + 1] = ":" .. t_concat(cline) .. "\027[0m:"
		end
		print("." .. ("."):rep(term_db.width/2) .. ".")
		print(t_concat(lines, "\n"))
		print("'" .. ("'"):rep(term_db.width/2) .. "'")
		io.flush()
	end
	
	function term:forsake_child()
		rterm:forsakeChild()
	end
	
	function term:set_fg_colors(colors)
		bg_colors = bg_colors
	end
	
	function term:set_bg_colors(colors)
		fg_colors = fg_colors
	end

	return term
end


return terminal
