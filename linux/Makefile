TARGET := fstest
CSOURCES := main.c ../filesys.c drive.c
HEADERS := ../filesys.h drive.h
OBJECTS := $(patsubst %.c,%.o,$(CSOURCES))

CC = gcc
CFLAGS = -Wall -I.. -g
LFLAGS =

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS)

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS)
	rm -f $(TARGET)

.PHONY: all clean

