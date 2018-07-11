stuff
-----

The goal is to create a terminal emulator that can run in a self-created
windowing system on the framebuffer.

currently, the main executable is called test2.lua
run it without any parameter and change to a empty vt.

You should now see a terminal window and a background image and a cursor.
If you type something, the launched shell should act accordingly.
(except that caps lock does not work yet).
If you move your cursor onto the terminal and press and hold the right alt key,
you should be able to drag the terminal window around.

to get this to work, find out what /dev/input/event* devices your mouse and
keyboard are, and edit the paths in these lines in test2.lua:

```lua
local kbd = keyboard.open({
	path = "/dev/input/event0",
	nonblocking = true
})

local mouse = mice.open({
	path = "/dev/input/event3",
	nonblocking = true
})
```


The keyboard input is currently german only(You add a diffrent layout after
implementing it by adding a table to the keyboard.open config parameter
table via the layout key, e.g.:

```lua
local kbd = keyboard.open({
	path = "/dev/input/event0",
	layout = require("keyboard_layout_english"),
	nonblocking = true
})
```


files
-----


## test2.lua

currently the main executable.
Loads up hardware wrappers(keyboard, mouse), and renders everything.



## 7x12b.bmp, 7x12.bmp, cga.bmp, lcd.bmp

these files are used as fonts. Fonts are character tiles indexed from
top left to right, bottom(starting at 0).



## bg.bmp

Background image



## pointer.bmp

2 mouse pointer images, side by side (2x 8px*16px = 16px*16px)



## font.lua

Manages fonts. Has a global list of fonts and a global font cache.
Generates lfb drawbuffers for font characters from bitmaps.
Exports following functions:

```lua
font:load_from_table(font_tbl)
font:load_from_bmp(name, bmp_path, char_w, char_h, chars_x, chars_y)
font:load_from_json(json_path, name)
char_w, char_h = font:get_char_size(name, [scale_w], [scale_h])
db = function font:render_char_to_db(name, char_id, [scale_w], [scale_h], [fg])
font:set_default([default_name], [default_bold_name])
font:_sort_cache() --sorts cache by count of access, improves cache access speed
font:_clear_cache([leave_top_n]) --clear cache [but leave to n entrys by access]
```



## keyboard.lua

implements the keycode mapper .
Resolves keys based on it's modifier key states and the
layout(loaded from keyboard_layout_german.lua).
Returns values from the layout for each key.
Reads uinput for keys.
Supports callbacks and event ques.
exports only 1 function, kbd = keyboard.open(config_table).

```lua
kbd:handle_ev(ev) -- mostly internal, handle a uinput ev
kbd:update_one -- handle one uinput event(warning:slow)
kbd:update -- handle all uinput events
kbd:add_key(ret, keycode, shift, ctrl, alt) -- modifys layout
kbd:pop_event(event) -- event logging needs to be enabled
kbd:push_event()
kbd:clear_events()
```



## keyboard_layout_german.lua

A keyboard layout is a mapping of uinput scancodes to tables determining return values for callbacks/events for each modifier(ctrl, shift, right alt).



## terminal.lua

renders a terminal, either to a drawbuffer or to another terminal using unicode
braile characters.
exports only 1 function:

```lua
terminal.new(config_table)
```


term functions:

```lua
term:update_config(alternative_config) --call after updating the config
term:render() --render to drawbuffer
term:write(str) --write str to terminal
term:draw_unicode() --draws terminal to a unicode-terminal using braile chars
```



## mice.lua
Implements mice support.
Works like keyboard, except for mouse input.
mouse functions:

```lua
mouse:handle_ev(ev)
x,y = mouse:get_pos() -- get integer position
x,y = mouse:_get_pos() -- get precise position
mouse:set_pos(x, y) -- set position
w,h = mouse:get_dimensions() -- get/set bounding box
mouse:set_dimensions(w,h)
s = get_sensitivity -- get sensitivity multiplicator
mouse:set_sensitivity(sensitivity, invert) -- set sensitivity(invert means 1/n)
mouse:update()
mouse:update_one()
```


implementation
--------------

I use many diffrent C and lua librarys, some external, some developed by me,
and some developed for this project. Some of the files above could be
used as librarys.


## lua-tmt

This library is the future terminal emulation library.
You can send it strings, and it interpretes them as terminal codes
and updates it's cell matrix.
Not currently used.



## lua-time

My own library for timing-related stuff.provides up to accurate timing function.
(get realtime/monotonic + accurate sleep)



## lfb

My own library for framebuffer and drawing related stuff(Not including loading
bitmaps).
Makes this thing work



## lua-input

Get events from /dev/input/event* (kernel uinput), used to make mouse and
keyboard work.



## bitmap

My own bitmap reading(and limited writing) library. Used to load images for
font rendering etc.



## lua-rote

Because my terminal emulation library didn't work for a long time the 
terminal emulator currently uses lua-rote.
Note however that this library is incomplete/missing features, and the project
that it's binding is abandoned.
This is TODO



## more?

Maybe I use more librarys somewhere. idk :/
this is TODO

