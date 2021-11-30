NAME := fstest
HEX := $(NAME).hex
MAP := $(NAME).map
BIN := $(NAME).bin
ASOURCES := zx81rom.s
CSOURCES := main.c ../filesys.c ../mmc.c
HEADERS := ../filesys.h ../mmc.h
OBJECTS := $(patsubst %.s,%.rel,$(ASOURCES)) $(patsubst %.c,%.rel,$(CSOURCES))

CC = sdcc
AS = sdasz80

ASFLAGS = -plosgff

MFLAGS := -mz80 --opt-code-size --reserve-regs-iy
CFLAGS := -DLITTLE_ENDIAN=1 -I..
LFLAGS := --code-loc 0x2020 --data-loc 0xc000 --no-std-crt0

all: $(BIN)

%.rel: %.c $(HEADERS)
	$(CC) $(MFLAGS) $(CFLAGS) -c -o $@ $<

%.rel: %.s
	$(AS) $(ASFLAGS) $@ $<

$(HEX): $(OBJECTS)
	$(CC) $(MFLAGS) $(LFLAGS) -o $@ $(OBJECTS)

$(BIN): $(HEX)
	sdobjcopy -I ihex -O binary $< $@

clean:
	rm -f *.asm *.rel *.lst *.sym
	rm -f ../*.asm ../*.rel ../*.lst ../*.sym
	rm -f *.lk *.noi
	rm -f $(HEX) $(MAP) $(BIN)

.PHONY: all clean

