NAME := zxsd
HEX := $(NAME).hex
MAP := $(NAME).map
BIN := $(NAME).bin
ROM := $(NAME)-rom.bin
ROMHEX := $(NAME)-rom.hex
ASOURCES := crt0.s
CSOURCES := main.c ../filesys.c ../mmc.c term.c spi.c
HEADERS := ../filesys.h ../mmc.h term.h
OBJECTS := $(patsubst %.s,%.rel,$(ASOURCES)) $(patsubst ../%,%,$(patsubst %.c,%.rel,$(CSOURCES)))

CC = sdcc
AS = sdasz80

ASFLAGS = -plosgff

MFLAGS := -mz80 --opt-code-size --reserve-regs-iy --constseg CDATA
CFLAGS := -I. -I.. -DLITTLE_ENDIAN=1 -DTFS_ENABLE_FORMAT
LFLAGS := --code-loc 0x2000 --data-loc 0xf800 "-Wl-b _CDATA = 0x8000" --no-std-crt0

all: $(ROMHEX) showmem

%.rel: ../%.c $(HEADERS)
	$(CC) $(MFLAGS) $(CFLAGS) -c -o $@ $<

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

$(ROM): $(BIN)
	dd status=none if=$< of=$@ bs=1024 count=16
	dd status=none if=$< of=$@ bs=1024 count=16 seek=16 skip=32

$(ROMHEX): $(ROM)
	sdobjcopy -I binary -O ihex $< $@

clean:
	rm -f *.asm *.rel *.lst *.sym
	rm -f *.lk *.noi
	rm -f $(HEX) $(MAP) $(BIN) $(ROM) $(ROMHEX)

.PHONY: all clean showmem

