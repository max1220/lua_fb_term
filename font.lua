local bitmap = require("bitmap")
local lfb = require("lfb")

local font = {}
-- the module we'll return

local fonts = {}
-- loadded fonts(by name)

local font_cache = {}
-- pre-rendered font glyphs(by render_key, see get_font_db)

local font_loaded = false

function font:load_from_table(font)
	-- all fonts are really loaded by this function, the other functions generate this table and call this function
	
	assert(tonumber(font.char_w))
	assert(tonumber(font.char_h))
	assert(tonumber(font.chars_x))
	assert(tonumber(font.chars_y))
	
	assert(#font.chars > 0)
	
	if font_loaded then
		-- not the first font loaded, just add to list
		fonts[font.name] = font
	else
		-- first font is also saved as default and default_bold
		fonts = {
			[font.name] = font,
			["default"] = font,
			["default_bold"] = font,
		}
		font_loaded = true
	end
end

function font:load_from_bmp(name, bmp_path, char_w, char_h, chars_x, chars_y)
	-- load a font from a .bmp
	assert(not fonts[name])
	local f = assert(io.open(bmp_path))
	local c = f:read("*a")
	local img = assert(bitmap.from_string(c))
	local char_w = tonumber(char_w) or 8
	local char_h = tonumber(char_h) or 8
	local chars_x = tonumber(chars_x) or math.floor(img.width / char_w)
	local chars_y = tonumber(chars_y) or math.floor(img.height / char_h)

	local font = {
		name = name,
		char_w = char_w,
		char_h = char_h,
		chars_x = chars_x,
		chars_y = chars_y,
		chars = {}
	}
	
	local function add_char(ox, oy, threshold)
		-- add a character by offset in the source image
		local threshold = tonumber(threshold) or 0
		local pixels = {}
		for y=1, char_h do
			local line = {}
			for x=1, char_w do
				local r,g,b = img:get_pixel(ox+x-1, oy+y-1)
				if r and g and b then
					local avg = math.floor((r+g+b)/3)
					if (avg>threshold) then
						line[x] = avg
					else
						line[x] = 0
					end
				else
					error("Out of bounds!")
				end
			end
			pixels[y] = line
		end
		table.insert(font.chars, {ox=ox,oy=oy, pixels = pixels})
		return #font.chars
	end

	for y=0, char_h*(chars_y-1), char_h do
		for x=0, char_w*(chars_x-1), char_w do
			add_char(x,y)
		end
	end
	
	self:load_from_table(font)
	
end

function font:load_from_json(json_path, name)
	-- loads a font from a .json
	
	local f = assert(io.open(json_path, "r"))
	local font = json.decode(f:read("*a"))
	f:close()
	local name = assert(name or font.name)
	assert(not fonts[name])
	font.name = name
	
	self:load_from_table(font)
	
end

local function concat_list(l, sep)
	local r = {}
	for k,v in ipairs(l) do
		r[k] = tostring(v)
	end
	return table.concat(r, sep)
end

function font:get_char_size(name, scale_w, scale_h)
	local font = assert(fonts[name])
	local scale_w = math.floor(tonumber(scale_w) or 1)
	local scale_h = math.floor(tonumber(scale_h) or 1)
	return font.char_w*scale_w, font.char_h*scale_h
end

function font:render_char_to_db(name, char_id, scale_w, scale_h, fg)
	-- draw the character char_id from the font name with the specified parameters to a new drawbuffer.
	-- this functions output gets cached automaticly, by generating a render_key unique for each parameter combination
	
	local font = assert(fonts[name])
	local char = assert(font.chars[char_id+1])
	local scale_w = math.floor(tonumber(scale_w) or 1)
	local scale_h = math.floor(tonumber(scale_h) or 1)
	local char_w = font.char_w
	local char_h = font.char_h
	local fg = fg or {255,255,255,255}
	local fg_r, fg_g, fg_b, fg_a = unpack(fg)
	--local render_key = concat_list({name, char_id, scale_w, scale_h, fg_r, fg_g, fg_b, fg_a, bg_r, bg_g, bg_b, bg_a}, ".")
	local render_key = concat_list({name, char_id, scale_w, scale_h, fg_r, fg_g, fg_b, fg_a}, ".")
	for _, cache_entry in ipairs(font_cache) do
		if cache_entry.key == render_key then
			cache_entry.counter = cache_entry.counter + 1
			return cache_entry.value
		end
	end
	
	local db = lfb.new_drawbuffer(char_w*scale_w,char_h*scale_h)
	
	local function set_px(x,y,r,g,b,a)
		-- set a pixel(in character coordinates, this function draws scaled in the drawbuffer if required)
		if (scale_w == 1) and (scale_h == 1) then
			db:set_pixel(x,y, r, g, b, a)
		else
			db:set_rect(x*scale_w,y*scale_h,scale_w, scale_h, r, g, b, a)
		end
	end
	
	for y=1, char_h do
		local line = assert(char.pixels[y])
		for x=1, char_w do
			local px = line[x]
			if px > 0 then
				-- set transparent for db copys (a<1)
				set_px(0,0,0,0)
			else
				-- TODO: translate shading
				set_px(x-1,y-1, fg_r, fg_g, fg_b, fg_a)
			end
		end
	end
	
	table.insert(font_cache, {
		key = render_key,
		value = db,
		counter = 1
	})
	return db
end

function font:set_default(default_name, default_bold_name)
	if default_name then
		fonts["default"] = assert(fonts[default_name])
	end
	if default_bold_name then
		fonts["default_bold"] = assert(fonts[default_bold_name])
	end
end

function font:_get_fonts()
	return fonts
end

function font:_get_cache()
	return font_cache
end

function font:_sort_cache()
	table.sort(font_cache, function(a,b)
		return a.counter > b.counter
	end)
end

function font:_clear_cache(leave_top_n)
	local leave_top_n = tonumber(leave_top_n)
	if leave_top_n then
		self:_sort_cache()
		for i=leave_top_n, #font_cache do
			font_cache[i] = nil
		end
	else
		font_cache = {}
	end
end

return font
