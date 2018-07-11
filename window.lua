local pty = require("lpty")
local time = require("time")
local window = {}


window.client = {}


window.server = {}
function window.server.new()
	local server = {}
	
	local windows = {}
	local widgets = {}
	local clients = {}
	
	function server.start_client_local(...)
		local client = {
			type = "pty",
			id = "pty_client:"time.realtime(),
			render_queue = {},
		}
		
		local client_pty = pty.new({
			no_local_echo = {}
		})
		local env = client_pty:getenviron()
		env["IS_WINDOW_CLIENT"] = "y"
		client_pty:start_proc(...)
		
		function client:read()
			if client_pty:readok() then
				return client_pty:readline(false, 0)
			end
		end
		
		function client:write(line)
			if client_pty:sendok() then
				client_pty:send(line .. "\n")
			end
		end
		
		function client:close(kill)
			client_pty:endproc(kill)
			for i,client in ipairs(clients) do
				if client == self then
					table.remove(clients, i)
				end
			end
		end
		
		table.insert(clients, client)
	end
	
	function server.loop()
		local function handle_line(client, line)
			local command, data = line:match("^([%a%d%.:_-]+):(.*)$")
			if command == "create_drawbuffer" then
				local name,w,h = data:match("^(%a%d%.:_-):(%d+):(%d+)$")
				if name and tonumber(w) and tonumber(h) then
					local db = lfb.new_drawbuffer(w,h)
					db:clear(0,0,0,255)
					table.insert(client.render_queue, {
						db = db,
						name = name,
						client = client,
						x = 0,
						y = 0,
						w = w,
						h = h,
						visible = false,
						title = "",
						order = 1000+#client.render_queue,
						flags = {
							window = false,
							-- should this drabuffer be decorated as a window?
							
							widget = false,
							-- should this drabuffer be a desktop widget?
						}
					})
					client:write("create_drawbuffer:ok:" .. #render_queue)
				else
					client:write("create_drawbuffer:fail")
				end
			elseif command == "db_copy_vline" then
			
			elseif command == "db_copy_hline" then
			
			elseif command == "db_set_pixel" then
			
			elseif command == "db_copy_rect" then
			
			elseif command == "db_set_title" then
				
			else
				print("Unknown command: " .. tostring(command) .. "(from line " .. tostring(line) .. " by client " .. client.id .. ")")
				client:close()
			end
		end
		for i,client in ipairs(clients) do
			local line = client:read()
			if line then
				handle_line(line)
			end
		end
		
		-- read all server input devices
		
		-- render all drawbuffers
	end
	
	return server
end
