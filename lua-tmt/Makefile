#!/bin/bash

CFLAGS   = -O3 -fPIC -I/usr/include/lua5.1
# CFLAGS = -Wall -Wextra
LIBS     = -shared -llua5.1
OBJFILES = lua_tmt.c tmt.c
TARGET   = tmt.so

all: $(TARGET)

$(TARGET): $(OBJFILES)
	$(CC) -o $(TARGET) $(OBJFILES) $(CFLAGS) $(LIBS)
	# strip $(TARGET)

clean:
	rm -f $(TARGET)
