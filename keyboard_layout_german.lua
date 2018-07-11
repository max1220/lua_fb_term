local c = require("input-event-codes")

-- german keyboard layout
local mapping = {
	[c.KEY_A] = {"a", "A", "\001"},
	[c.KEY_B] = {"b", "B", "\002"},
	[c.KEY_C] = {"c", "C", "\003"},
	[c.KEY_D] = {"d", "D", "\004"},
	[c.KEY_E] = {"e", "E", "\005"},
	[c.KEY_F] = {"f", "F", "\006"},
	[c.KEY_G] = {"g", "G", "\007"},
	[c.KEY_H] = {"h", "H", "\008"},
	[c.KEY_I] = {"i", "I", "\009"},
	[c.KEY_J] = {"j", "J", "\010"},
	[c.KEY_K] = {"k", "K", "\011"},
	[c.KEY_L] = {"l", "L", "\012"},
	[c.KEY_M] = {"m", "M", "\013"},
	[c.KEY_N] = {"n", "N", "\014"},
	[c.KEY_O] = {"o", "O", "\015"},
	[c.KEY_P] = {"p", "P", "\016"},
	[c.KEY_Q] = {"q", "Q", "\017"},
	[c.KEY_R] = {"r", "R", "\018"},
	[c.KEY_S] = {"s", "S", "\019"},
	[c.KEY_T] = {"t", "T", "\020"},
	[c.KEY_U] = {"u", "U", "\021"},
	[c.KEY_V] = {"v", "V", "\022"},
	[c.KEY_W] = {"w", "W", "\023"},
	[c.KEY_X] = {"x", "X", "\024"},
	[c.KEY_Y] = {"z", "Z", "\026"},
	[c.KEY_Z] = {"y", "Y", "\025"},
	
	[c.KEY_0] = {"0", "=", nil, "}"},
	[c.KEY_1] = {"1", "!", {"toggle_color"}},
	[c.KEY_2] = {"2", "\"", {"increase_font_size"}},
	[c.KEY_3] = {"3", "§", {"decrease_font_size"}},
	[c.KEY_4] = {"4", "$", "\003"},
	[c.KEY_5] = {"5", "%"},
	[c.KEY_6] = {"6", "&"},
	[c.KEY_7] = {"7", "/", nil, "{"},
	[c.KEY_8] = {"8", "(", nil, "["},
	[c.KEY_9] = {"9", ")", nil, "]"},
	
	[c.KEY_MINUS] =			{"ß", "?", nil, "\\"},
	[c.KEY_RIGHTBRACE] =	{"+", "*", nil, "~"},
	[c.KEY_BACKSLASH] = 	{"#", "'"},
	[c.KEY_COMMA] = 		{",", ";"},
	[c.KEY_DOT] = 			{".", ":"},
	[c.KEY_SLASH] = 		{"-", "_"},
	[c.KEY_GRAVE] = 		{"^"},
	[c.KEY_102ND] = 		{"<", ">", nil, "|"},
	
	[c.KEY_UP] =	{"\027[A"},
	[c.KEY_DOWN] =	{"\027[B"},
	[c.KEY_RIGHT] = {"\027[C"},
	[c.KEY_LEFT] =	{"\027[D"},
	
	[c.KEY_DELETE] = {"\004"},
	
	[c.KEY_ESC] = {"\027"},
	
	[c.KEY_PAGEUP]		= {"\027[5~"},
	[c.KEY_PAGEDOWN]	= {"\027[6~"},
	[c.KEY_END]			= {"\027[H"},
	[c.KEY_HOME] 		= {"\027[F"},
	
	[c.KEY_SPACE]		= {" "},
	[c.KEY_ENTER] 		= {"\013"},
	[c.KEY_BACKSPACE]	= {"\008"},
	[c.KEY_TAB]			= {"\009"}
	
}

return mapping
