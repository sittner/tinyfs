TARGET := fstest
SOURCES := main.c ../filesys.c drive.c
HEADERS := ../filesys.h drive.h
OBJECTS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(SOURCES)))

CC = gcc
CFLAGS = -Wall -I..
LFLAGS =

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS)

%.o: ../%.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS)
	rm -f $(TARGET)

.PHONY: all clean

