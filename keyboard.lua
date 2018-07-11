local input = require("input")
local input_event_codes = require("input-event-codes")

local keyboard = {}

function keyboard.open(config)
	local kbd = {}
	local path = config.path or "/dev/input/event0"
	local layout = config.layout or require("keyboard_layout_german")
	local nonblocking = config.nonblocking == true
	local dev = input.open(path, nonblocking)
	
	local events = {}
	kbd.lshift_down = false
	kbd.ralt_down = false
	kbd.lctrl_down = false
	kbd.collect_events = false
	local function resolve_ev_default(self, ev)
		if (ev.value == 1) or (ev.value == 2) then
			-- key down/key repeat
			if ev.code == input_event_codes.KEY_LEFTSHIFT then
				self.lshift_down = true
			elseif ev.code == input_event_codes.KEY_LEFTCTRL then
				self.lctrl_down = true
			elseif ev.code == input_event_codes.KEY_RIGHTALT then
				self.ralt_down = true
			end
			if layout[ev.code] then
				local norm, caps, ctrl, alt = unpack(layout[ev.code])
				if (not self.lshift_down) and (not self.lctrl_down) and (not self.ralt_down) then
					return norm
				elseif self.lshift_down and (not self.lctrl_down) and (not self.ralt_down) then
					return caps
				elseif (not self.lshift_down) and self.lctrl_down and (not self.ralt_down) then
					return ctrl
				elseif (not self.lshift_down) and (not self.lctrl_down) and self.ralt_down then
					return alt
				end
			end
		elseif ev.value == 0 then
			-- key up
			if ev.code == input_event_codes.KEY_LEFTSHIFT then
				self.lshift_down = false
			elseif ev.code == input_event_codes.KEY_LEFTCTRL then
				self.lctrl_down = false
			elseif ev.code == input_event_codes.KEY_RIGHTALT then
				self.ralt_down = false
			end
		end
	end
	kbd.resolve_ev = config.resolve_ev or resolve_ev_default
	
	function kbd:handle_ev(ev)
		if ev.type == input_event_codes.EV_KEY or ev.type == input_event_codes.EV_BTN then
			if self.raw_key_callback then
				self:raw_key_callback(ev)
			end
			local ret = self:resolve_ev(ev)
			if ret then
				if self.key_callback then
					self:key_callback(ret)
				end
				if self.collect_events then
					table.insert(events, ret)
				end
			end
		end
	end
	
	function kbd:update_one()
		-- read & handle one event
		local ev = dev:read()
		if ev and ev.type ~= input_event_codes.EV_SYN then
			self:handle_ev(ev)
		end
	end
	
	function kbd:update()
		-- read & handle all events
		local ev = dev:read()
		while ev do
			self:handle_ev(ev)
			ev = dev:read()
		end
	end
	
	function kbd:add_key(ret_value, keycode, shift, ctrl, alt)
		assert(layout[keycode])
		local norm, caps, ctrl, alt
		if (not self.lshift_down) and (not self.lctrl_down) and (not self.ralt_down) then
			layout[keycode][1] = ret_value
		elseif self.lshift_down and (not self.lctrl_down) and (not self.ralt_down) then
			layout[keycode][2] = ret_value
		elseif (not self.lshift_down) and self.lctrl_down and (not self.ralt_down) then
			layout[keycode][3] = ret_value
		elseif (not self.lshift_down) and (not self.lctrl_down) and self.ralt_down then
			layout[keycode][4] = ret_value
		end
		
		
	end
	
	function kbd:pop_event()
		return table.remove(events, 1)
	end
	
	function kbd:push_event(event)
		table.insert(events, event)
	end
	
	function kbd:clear_events()
		events = {}
	end
	
	return kbd
end

return keyboard
