TARGET := fstest
CSOURCES := main.c filesys.c mmc-emu.c
HEADERS := 
OBJECTS := $(patsubst %.c,%.o,$(CSOURCES))

CC = gcc
CFLAGS = -Wall -g
LFLAGS =

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS)

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o
	rm -f $(TARGET)

.PHONY: all clean

