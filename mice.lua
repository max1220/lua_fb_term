local input = require("input")
local time = require("time")
local input_event_codes = require("input-event-codes")


local mice = {}

function mice.open(config)
	local mouse = {}
	local path = config.path or "/dev/input/event0"
	local nonblocking = config.nonblocking == true
	local dev = input.open(path, nonblocking)
	
	local f = math.floor
	
	local x = 0
	local y = 0
	local x_max = config.max_x or 1000
	local y_max = config.max_y or 1000
	local last_update = time.realtime()
	local sensitivity = 1/10
	
	local down_x
	local down_y
	
	function mouse:handle_ev(ev)
		local m = sensitivity * (last_update-time.realtime())
		if ev.code == input_event_codes.REL_X then
			x = math.max(math.min(x-ev.value * m, x_max),0)
		elseif ev.code == input_event_codes.REL_Y then
			y = math.max(math.min(y-ev.value * m, y_max),0)
		elseif ev.code == input_event_codes.BTN_LEFT then
			self.lmb = ev.value == 1
			if self.lmb then
				down_x = x
				down_y = y
			else
				if self.click_callback then
					self:click_callback(f(x),f(y), down_x and f(down_x), down_y and f(down_y))
					down_x = nil
					down_y = nil
				end
			end
		elseif ev.code == input_event_codes.BTN_RIGHT then
			self.rmb = ev.value == 1
			if self.rmb then
				down_x = x
				down_y = y
			else
				if self.rightclick_callback then
					self:rightclick_callback(f(x),f(y), down_x and f(down_x), down_y and f(down_y))
					down_x = nil
					down_y = nil
				end
			end
		elseif ev.code == input_event_codes.BTN_MIDDLE then
			self.mmb = ev.value == 1
		end
	end
	
	function mouse:get_pos()
		return math.floor(x),math.floor(y)
	end
	
	function mouse:_get_pos()
		return x,y
	end
	
	function mouse:set_pos(x_n, y_n)
		x = x_n
		x = y_n
	end
	
	function mouse:get_dimensions()
		return x_max, y_max
	end
	
	function mouse:set_dimensions(x_max_n, y_max_n)
		x_max = x_max_n
		y_max = y_max_n
	end
	
	function mouse:get_sensitivity(sensitivity, invert)
		return sensitivity
	end
	
	function mouse:set_sensitivity(sensitivity_n, invert)
		if invert then
			sensitivity = 1/sensitivity_n
		else
			sensitivity = sensitivity_n
		end
	end
	
	function mouse:update()
		-- read & handle all events
		local ev = dev:read()
		while ev do
			self:handle_ev(ev)
			ev = dev:read()
		end
	end
	
	function mouse:update_one()
		-- read & handle one event
		local ev = dev:read()
		if ev and ev.type ~= input_event_codes.EV_SYN then
			self:handle_ev(ev)
		end
	end
	
	
	
	return mouse
end

return mice
