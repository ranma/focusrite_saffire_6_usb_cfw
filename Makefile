SDCC ?= sdcc
SDAS ?= sdas8051
CFLAGS = -mmcs51 --model-small --std-c99 --opt-code-size --fomit-frame-pointer --allow-unsafe-read
LDFLAGS = --xram-loc 0xf800 --xram-size 0x10 --model-small
OBJS := main.rel usb.rel

all: focusrite.eep stage1.bin focusrite.bin

clean:
	rm -f *.ihx *.lst *.rel *.map *.sym *.mem *.rst *.bin *.eep

test.ihx: $(OBJS)
	$(SDCC) $(LDFLAGS) $+ -o $@

%.eep: %.bin
	../tusb3200/tusb3200.py -e -o $@ $<

%.ihx: %.rel
	sdld -nmuwxMY -i $@ $<

%.bin: %.ihx
	objcopy -I ihex $< -O binary $@

%.rel: %.c
	$(SDCC) $(CFLAGS) -c $< -o $@

%.rel: %.s
	$(SDAS) -ols $@ $<
