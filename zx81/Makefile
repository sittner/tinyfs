NAME := fstest
HEX := $(NAME).hex
MAP := $(NAME).map
BIN := $(NAME).bin
ASOURCES := crt0.s
CSOURCES := main.c filesys.c mmc.c term.c spi.c
HEADERS := filesys.h mmc.h term.h
OBJECTS := $(patsubst %.s,%.rel,$(ASOURCES)) $(patsubst %.c,%.rel,$(CSOURCES))

CC = sdcc
AS = sdasz80

ASFLAGS = -plosgff

MFLAGS := -mz80 --opt-code-size --reserve-regs-iy
CFLAGS := -DLITTLE_ENDIAN=1
LFLAGS := --code-loc 0x2000 --data-loc 0xc000 --no-std-crt0

all: $(BIN) showmem

%.rel: %.c $(HEADERS)
	$(CC) $(MFLAGS) $(CFLAGS) -c -o $@ $<

%.rel: %.s
	$(AS) $(ASFLAGS) $@ $<

$(HEX): $(OBJECTS)
	$(CC) $(MFLAGS) $(LFLAGS) -o $@ $(OBJECTS)

showmem: $(MAP)
	@echo
	@echo 'Area                                    Addr        Size        Decimal Bytes (Attributes)'
	@echo '--------------------------------        ----        ----        ------- ----- ------------'
	@cat $(MAP) | grep '^_'
	@echo

$(BIN): $(HEX)
	sdobjcopy -I ihex -O binary $< $@

clean:
	rm -f *.asm *.rel *.lst *.sym
	rm -f *.lk *.noi
	rm -f $(HEX) $(MAP) $(BIN)

.PHONY: all clean showmem

