
NAME := fstest
HEX := $(NAME).hex
OUT := $(NAME).out
MAP := $(NAME).map
SOURCES := main.c ../filesys.c ../mmc.c spi.c uart.c
HEADERS := ../filesys.h ../mmc.h uart.h
OBJECTS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(SOURCES)))

MCU := atmega328p
MCU_AVRDUDE := atmega328p
MCU_FREQ := 16000000UL

CC := avr-gcc
OBJCOPY := avr-objcopy
SIZE := avr-size -A
DOXYGEN := doxygen

CFLAGS := -Wall -I.. -pedantic -mmcu=$(MCU) -std=c99 -g -Os -DF_CPU=$(MCU_FREQ)

all: $(HEX)

clean:
	rm -f $(HEX) $(OUT) $(MAP) $(OBJECTS)
	rm -rf doc/html

flash: $(HEX)
	avrdude -y -c avrisp2 -P usb -p $(MCU_AVRDUDE) -U flash:w:$(HEX)

$(HEX): $(OUT)
	$(OBJCOPY) -R .eeprom -O ihex $< $@

$(OUT): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ -Wl,-Map,$(MAP) $^
	@echo
	@$(SIZE) $@
	@echo

%.o: ../%.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

%.pp: %.c
	$(CC) $(CFLAGS) -E -o $@ $<

%.ppo: %.c
	$(CC) $(CFLAGS) -E $<

doc: $(HEADERS) $(SOURCES) Doxyfile
	$(DOXYGEN) Doxyfile

.PHONY: all clean flash doc

