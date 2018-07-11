#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <time.h>

#include "tmt.h"

#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);

#define NS_IN_S 1000000000


typedef struct {
	TMT *vt;
	int w;
	int h;
	int update_lines;
	int update_bell;
	int update_answer;
	int update_cursor;
} tmt_t;


void insert_char_table(int x, lua_State *L, TMTCHAR c) {
	// sets top_table[x+1] to { char=?, bold=?, dim=?, underline=?, blink=?, reverse=?, invisible=?, bg=?, fg=? }
	
	lua_pushinteger(L, x+1);
	lua_newtable(L);

	lua_pushstring(L, "char");
	lua_pushinteger(L, c.c);
	lua_settable(L, -3);
					
	lua_pushstring(L, "bold");
	lua_pushboolean(L, c.a.bold? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "dim");
	lua_pushboolean(L, c.a.dim? 1 : 0);
	lua_settable(L, -3); 
					
	lua_pushstring(L, "underline");
	lua_pushboolean(L, c.a.underline? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "blink");
	lua_pushboolean(L, c.a.blink? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "reverse");
	lua_pushboolean(L, c.a.reverse? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "invisible");
	lua_pushboolean(L, c.a.invisible? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "fg");
	lua_pushinteger(L, (int)c.a.fg? 1 : 0);
	lua_settable(L, -3);
					
	lua_pushstring(L, "bg");
	lua_pushinteger(L, (int)c.a.bg? 1 : 0);
	lua_settable(L, -3);
	
	lua_settable(L, -3);
}

void insert_lines(lua_State *L, TMT *vt) {
	const TMTSCREEN *s = tmt_screen(vt);
	lua_pushstring(L, "lines");
	lua_newtable(L);
	for (uint y=0; y < s->nline; y++) {
		lua_pushinteger(L, y+1);
		lua_newtable(L);
		
		lua_pushstring(L, "dirty");
		lua_pushboolean(L, s->lines[y]->dirty? 1 : 0);
		lua_settable(L, -3);
				
		for (uint x=0; x < s->ncol; x++) {
			insert_char_table(x, L, s->lines[y]->chars[x]);
		}
		
		lua_settable(L, -3);
	}
	lua_settable(L, -3);
}

void input_callback(tmt_msg_t m, TMT *vt, const void *a, void *p) {
	const TMTSCREEN *s = tmt_screen(vt);
	const TMTPOINT *c = tmt_cursor(vt);
	lua_State *L = (lua_State*)p;
	tmt_t *tmt = (tmt_t *)lua_touserdata(L, 1);
	
	if (tmt != NULL) {
		switch (m){
			case TMT_MSG_BELL:
				tmt->update_bell = 1;
				break;
			case TMT_MSG_UPDATE:
				/* the screen image changed; a is a pointer to the TMTSCREEN */
				tmt->update_lines = 1;
				break;
			case TMT_MSG_ANSWER:
				/* the terminal has a response to give to the program; a is a
				 * pointer to a string */
				tmt->update_answer = 1;
				break;
			case TMT_MSG_MOVED:
				/* the cursor moved; a is a pointer to the cursor's TMTPOINT */
				tmt->update_cursor = 1;
				break;
		}
	}
}


static int l_write(lua_State *L) {
	struct timespec t;
	
	tmt_t *tmt = (tmt_t *)lua_touserdata(L, 1);
	if (lua_getmetatable(L, 1) == 0) {
		return 0;
	}
	const char* str = strdup(luaL_checkstring(L, 2));

	const TMTSCREEN *s = tmt_screen(tmt->vt);
	const TMTPOINT *c = tmt_cursor(tmt->vt);
	
	tmt_write(tmt->vt, str, 0);
	
	// tmt_close(tmt->vt);
	
	lua_newtable(L);
	
	int counter = 1;
	
	if (clock_gettime(CLOCK_REALTIME, &t) == 0) {
		lua_pushstring(L, "time");
		lua_pushnumber(L, (double)t.tv_sec + ((double)t.tv_nsec)/NS_IN_S);
		lua_settable(L, -3);
	}
	
	if (tmt->update_lines) {
		tmt->update_lines = 0;
		
		lua_pushinteger(L, counter);
		lua_newtable(L);
		
		lua_pushstring(L, "type");
		lua_pushstring(L, "screen");
		lua_settable(L, -3);
		
		lua_settable(L, -3);
		
		counter = counter + 1;
	}
	
	if (tmt->update_bell) {
		tmt->update_bell = 0;
		
		lua_pushinteger(L, counter);
		lua_newtable(L);
		
		lua_pushstring(L, "type");
		lua_pushstring(L, "bell");
		lua_settable(L, -3);
		
		lua_settable(L, -3);
		
		counter = counter + 1;
	}
	
	if (tmt->update_answer) {
		tmt->update_answer = 0;
		
		lua_pushinteger(L, counter);
		lua_newtable(L);
		
		lua_pushstring(L, "type");
		lua_pushstring(L, "answer");
		lua_settable(L, -3);
		
		lua_settable(L, -3);
		
		counter = counter + 1;
	}
	
	if (tmt->update_cursor) {
		tmt->update_cursor = 0;
		
		lua_pushinteger(L, counter);
		lua_newtable(L);
		
		lua_pushstring(L, "type");
		lua_pushstring(L, "cursor");
		lua_settable(L, -3);
		
		lua_pushstring(L, "x");
		lua_pushinteger(L, c->c);
		lua_settable(L, -3);
		
		lua_pushstring(L, "y");
		lua_pushinteger(L, c->r);
		lua_settable(L, -3);
		
		lua_settable(L, -3);
		
		counter = counter + 1;
	}
	
	return 1;
}


static int l_get_screen(lua_State *L) {
	tmt_t *tmt = (tmt_t *)lua_touserdata(L, 1);
	TMT *vt = tmt->vt;
	const TMTSCREEN *s = tmt_screen(vt);
	
	lua_newtable(L);
	insert_lines(L, vt);
	return 1;
}


static int l_new(lua_State *L) {
	tmt_t *tmt = (tmt_t *)lua_newuserdata(L, sizeof(*tmt));
	int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);
	int cstacki = lua_gettop(L);
	
	TMT *vt = tmt_open((size_t)w, (size_t)h, input_callback, L, NULL);
	
	const TMTSCREEN *s = tmt_screen(vt);
	
	tmt->vt = vt;

	tmt->w = w;
	tmt->h = h;
	tmt->update_lines = 0;
	tmt->update_bell = 0;
	tmt->update_answer = 0;
	tmt->update_cursor = 0;
	
	lua_newtable(L);
	
	lua_pushstring(L, "__index");
	lua_newtable(L);
	
	lua_pushstring(L, "write");
	lua_pushcfunction(L, l_write);
	lua_settable(L, -3);
	
	lua_pushstring(L, "get_screen");
	lua_pushcfunction(L, l_get_screen);
	lua_settable(L, -3);
	
	lua_settable(L, -3);
	
	lua_setmetatable(L, -2);
	return 1;
}


LUALIB_API int luaopen_tmt(lua_State *L) {
	lua_newtable(L);
	LUA_T_PUSH_S_CF("new", l_new)
	LUA_T_PUSH_S_CF("write", l_write)
	LUA_T_PUSH_S_CF("get_screen", l_get_screen)
	return 1;
}
