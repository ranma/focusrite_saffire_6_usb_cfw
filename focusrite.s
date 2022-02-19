.equ GLOBCTL,   0xffb1
.equ OEPINT,    0xffb4
.equ IEPINT,    0xffb3
.equ VECINT,    0xffb2
.equ IEPCNF0,   0xff68
.equ IEPBBAX0,  0xff69
.equ IEPBSIZ0,  0xff6a
.equ IEPDCNTX0, 0xff6b
.equ IEPCNF2,   0xff58
.equ IEPBBAX2,  0xff59
.equ IEPBSIZ2,  0xff5a
.equ IEPDCNTX2, 0xff5b
.equ IEPBBAY2,  0xff5d
.equ IEPDCNTY2, 0xff5f
.equ OEPCNF0,   0xffa8
.equ OEPBBAX0,  0xffa9
.equ OEPBSIZ0,  0xffaa
.equ OEPDCNTX0, 0xffab
.equ OEPCNF1,   0xffa0
.equ OEPBBAX1,  0xffa1
.equ OEPBSIZ1,  0xffa2
.equ OEPDCNTX1, 0xffa3
.equ OEPBBAY1,  0xffa5
.equ SETUP_PKT, 0xff28
.equ MEMCFG,    0xffb0
.equ I2CCTL,    0xffc0
.equ I2CDATO,   0xffc1
.equ I2CDATI,   0xffc2
.equ USBFADR,   0xffff
.equ USBSTA,    0xfffe
.equ USBIMSK,   0xfffd
.equ USBCTL,    0xfffc

; C-port
.equ CPTVSLH,   0xFFD7
.equ CPTVSLL,   0xFFD8
.equ CPTDATH,   0xFFD9
.equ CPTDATL,   0xFFDA
.equ CPTADR,    0xFFDB
.equ CPTSTA,    0xFFDC
.equ CPTCTL,    0xFFDC
.equ CPTCNF4,   0xFFDD
.equ CPTCNF3,   0xFFDE
.equ CPTCNF2,   0xFFDF
.equ CPTCNF1,   0xFFE0

; Adaptive Clock Generator
.equ ACGCTL,    0xFFE1
.equ ACGDCTL,   0xFFE2

.equ ACGCAPH,   0xFFE3
.equ ACGCAPL,   0xFFE4

.equ ACGFRQ2,   0xFFE5
.equ ACGFRQ1,   0xFFE6
.equ ACGFRQ0,   0xFFE7

; DMA
.equ DMACTL0,   0xFFE8
.equ DMATSH0,   0xFFE9
.equ DMATSL0,   0xFFEA

.equ DMACTL1,   0xFFEE
.equ DMATSH1,   0xFFEF
.equ DMATSL1,   0xFFF0

.equ DMACTL2,   0xFFF4
.equ DMATSH2,   0xFFF5
.equ DMATSL2,   0xFFF6

.equ DMACTL3,   0xFFF7
.equ DMATSH3,   0xFFF8
.equ DMATSL3,   0xFFF9


.equ EP0_BYTES,  8
.equ EP0_IN_SIZ,    ((EP0_BYTES + 7) / 8)
.equ EP0_IN,        (SETUP_PKT - (8 * EP0_IN_SIZ))
.equ EP0_IN_BBAX,   ((EP0_IN / 8) & 0xff)

.equ EP0_OUT_SIZ,   ((EP0_BYTES + 7) / 8)
.equ EP0_OUT,       (EP0_IN - (8 * EP0_OUT_SIZ))
.equ EP0_OUT_BBAX,  ((EP0_OUT / 8) & 0xff)

.equ EP1_BYTES,  (288 * 2)
.equ EP1_OUT_SIZ,   ((EP1_BYTES + 7) / 8)
.equ EP1_OUTX,       (EP0_OUT - (8 * EP1_OUT_SIZ))
.equ EP1_OUT_BBAX,  ((EP1_OUTX / 8) & 0xff)
.equ EP1_OUTY,       (EP1_OUTX - (8 * EP1_OUT_SIZ))
.equ EP1_OUT_BBAY,  ((EP1_OUTY / 8) & 0xff)

.equ EP2_BYTES,  288
.equ EP2_IN_SIZ,   ((EP2_BYTES + 7) / 8)
.equ EP2_INX,       (EP1_OUTY - (8 * EP2_IN_SIZ))
.equ EP2_IN_BBAX,  ((EP2_INX / 8) & 0xff)
.equ EP2_INY,       (EP2_INX - (8 * EP2_IN_SIZ))
.equ EP2_IN_BBAY,  ((EP2_INY / 8) & 0xff)

.iflt EP0_IN - 0xff00
.error 1; EP0 buffer start out of range
.endif

.iflt EP0_OUT - 0xff00
.error 1; EP0 buffer start out of range
.endif

; recursive macro example
; usage: sum 0 5
.macro  sum from,to
	.byte   from
	.ifgt   to - from
	sum     (from+1) to
	.endif
.endm

.macro usb_string name value
	.nchr   len, value
	.ifgt   len - 126
	.error 1
	.endif
name:	.byte   2 * (len + 1)
	.ascii  value
.endm

.macro dispatch_address handler
	.iflt handler - . - 1
	.error 1 ; handler adress out of range
	.endif
	.ifgt handler - . - 1 - 255
	.error 1 ; handler adress out of range
	.endif
	.byte handler - . - 1
.endm

.macro dispatch_entry value handler
	.byte value
	dispatch_address handler
.endm

.macro setup_entry type request handler
	.byte type
	.byte request
	.word handler
.endm

.area RSEG    (ABS,DATA)
.org 0x0000
AR0: .ds 1
AR1: .ds 1
AR2: .ds 1
AR3: .ds 1
AR4: .ds 1
AR5: .ds 1
AR6: .ds 1
AR7: .ds 1
BR0: .ds 1
BR1: .ds 1
BR2: .ds 1
BR3: .ds 1
BR4: .ds 1
BR5: .ds 1
BR6: .ds 1
BR7: .ds 1

.area BSEG    (ABS,DATA)
.org 0x0020
usbState: .ds 1
.equ usbStateSetupInvalid, 0
.equ usbStateSetAddress, 1
.equ usbStateIn0Done, 2
.equ usbStateZeroPad, 3
.equ usbStateStringCnt, 4
.equ usbStateHTDData, 5
.equ usbStateCopyIRAM, 6
.equ usbStateCopyXRAM, 7
usbState2: .ds 1
.equ usbStateAddressValid, 8
miscState: .ds 1
.equ uartEmpty, 16
.equ swapOutput, 17  ; In 2ch mode, output on terminals 3+4 instead of 1+2
audioState: .ds 1
.equ audioIf1On,  24
.equ audioIf2On,  25
.equ audio24bit,  26

.org 0x0080
.equ UartBufSize, 0x40
.equ StackSize, 0x40
stack: .ds StackSize
uartbuf: .ds UartBufSize

.area DSEG (DATA)
bmRequestType: .ds 1
bRequest:      .ds 1
wValueLo:      .ds 1
wValueHi:      .ds 1
wIndexLo:      .ds 1
wIndexHi:      .ds 1
wLengthLo:     .ds 1
wLengthHi:     .ds 1

txPtr:    .dw 1
. = . - 2
txPtrLo:  .ds 1
txPtrHi:  .ds 1
txSizeLo: .ds 1
txSizeHi: .ds 1

sofCtr:   .ds 1
freqLockCtr: .ds 1

uartReadPtr:   .ds 1
uartWritePtr:  .ds 1

pACGCapL:   .ds 1
pACGCapH:   .ds 1
acgDeltaL: .ds 1
acgDeltaH: .ds 1
acgFrqLo: .ds 1

getBuf:  .ds 4
codecCache: .ds 8  ; CS4272 has 8 registers

envMaxL: .ds 1
envMaxR: .ds 1

.area CSEG (CODE,ABS)
_reset: ljmp _start
.org 3
	.word infobytes
.org 0x20
	ajmp bad_vec

.org 0x23
	push PSW
	setb PSW.3
	mov R7, A
	ajmp uart_vec

bad_vec:
	clr TI
	mov SBUF, #'!'
bad_vec_wait:
	jnb TI, bad_vec_wait
	sjmp bad_vec

_start:
	clr A
	mov PSW, A
	mov R0, A

clear_iram:
	mov @R0, A
	djnz R0, clear_iram

	mov SP, #0x6f

	; Port defaults
	mov P1, #0xdf  ; Turn on LED1 (LD1)
	mov P2, #0xff  ; Select 0xff00 as base for MOVX with R0/R1
	orl P3, #0x3b
	anl P3, #0xef  ; Turn on front panel USB LED

	mov R0, #GLOBCTL
	mov A, #0xC4 ; Enable 24MHz CPU clock, enable USB block
	movx @R0, A

	mov RCAP2H, #0xff
	mov RCAP2L, #0xf3 ; 57600 baud (~57692; 0.16% error)
	mov T2CON, #0x34
	mov SCON, #0x50
	mov TH2, #0xff
	mov TL2, #0xff

	clr IT0        ; Trigger extint on falling edge

	mov uartReadPtr, #uartbuf
	mov uartWritePtr, #uartbuf
	setb uartEmpty
	mov IE, #0x90        ; Enable interrupts (uart only)

	mov DPTR, #message_hello
	acall serial_puts

wait_uart_finished:
	jnb uartEmpty, wait_uart_finished

	acall usb_init

loop:
	mov R0, #VECINT
	movx A, @R0
	xrl A, #0x24 ; 0x24 => no interrupt pending
	jz loop

	cjne A, #(0x12 ^ 0x24), vec_early_check_not_setup
	sjmp vec_setup_skip_early_ack
vec_early_check_not_setup:

	; ACK interrupt
	movx @R0, A

vec_setup_skip_early_ack:
	acall vec_dispatch

	sjmp loop

fetchx_postinc:
	movx A, @DPTR
	inc DPTR
	ret

fetchc_postinc:
	clr A
	movc A, @A+DPTR
	inc DPTR
	ret

fetchi_postinc:
	push AR0
	mov R0, DPL
	mov A, @R0
	inc DPTR
	pop AR0
	ret

vec_dispatch:
	acall dispatch
	dispatch_entry (0x08^0x24) vec_in_ep0
	dispatch_entry (0x00^0x24) vec_out_ep0
	dispatch_entry (0x17^0x24) vec_reset
	dispatch_entry (0x12^0x24) vec_setup
	dispatch_entry (0x13^0x24) vec_psof
	dispatch_entry (0x14^0x24) vec_sof
	dispatch_entry 0 vec_default

vec_default:
	mov A, #'V'
	acall serial_write
	mov R0, #USBIMSK
	movx A, @R0
	acall serial_hex  ; Dump mask
	mov R0, #VECINT
	movx A, @R0
	acall serial_hex  ; Dump vec num
	ret

vec_reset:
	; Turn off power
	setb P1.6

	mov DPTR, #message_rst
	acall serial_puts
	acall usb_init
	ret

vec_psof:
vec_sof:
	ajmp vec_sof_softpll

vec_in_ep0:
	mov A, #'i'
	acall serial_write
	acall write_to_ep0
	jbc usbStateSetAddress, vec_in_ep0_set_addr
	ret

vec_in_ep0_set_addr:
	mov A, wValueLo
	mov R7, A

	mov R0, #USBFADR
	movx @R0, A
	setb usbStateAddressValid

	mov A, #'A'
	acall serial_write
	mov A, R7
	acall serial_hex

	;mov R0, #IEPCNF0
	;movx A, @R0
	;orl A, #0x08  ; Stall endpoint
	;movx @R0, A
	ret

vec_out_ep0:
	mov A, #'o'
	acall serial_write

	mov R0, #OEPDCNTX0
	movx A, @R0
	clr ACC.7
	jz vec_out_ep0_no_data

	; TODO: Copy data to iram
	; Only one place using it so far, so not bothering here
vec_out_ep0_no_data:
	; Clear NAK
	mov R0, #OEPDCNTX0
	clr A
	movx @R0, A

	; TODO: Support multiple packets, not used here.
	jb usbStateHTDData, setup_htd_got_data
	ret

vec_setup:
	mov A, #' '
	acall serial_write
	mov A, #'S'
	acall serial_write

	; Unstall endpoints
	mov A, #0xa4  ; Unstall in/out EP0
	mov R0, #IEPCNF0
	movx @R0, A
	mov R0, #OEPCNF0
	movx @R0, A

	mov A, #0x80  ; NACK IN/OUT
	mov R0, #IEPDCNTX0
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A

	mov usbState, #0
	mov txSizeLo, #0
	mov txSizeHi, #0

	mov R1, #SETUP_PKT
	mov R0, #bmRequestType
	mov R2, #8
copy_setup_pkt:
	movx A, @R1
	mov @R0, A
	inc R1
	inc R0
	djnz R2, copy_setup_pkt

	mov A, bmRequestType
	jb ACC.7, setup_dth

	; host is writing to device, check if there will OUT with data.
	mov A, wLengthLo
	orl A, wLengthHi
	jz setup_htd_no_data

	; Unnak OUT EP0 and wait for data
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A

	setb usbStateHTDData
	sjmp setup_exit

setup_htd_got_data:
setup_htd_no_data:
	sjmp setup_dispatch

setup_dth:
	; Assume that we read the requested size
	mov txSizeLo, wLengthLo
	mov txSizeHi, wLengthHi

setup_dispatch:
	mov DPTR, #(setup_dispatch_table - 2)
setup_dispatch_check_next:
	inc DPTR
	inc DPTR
	acall fetchc_postinc
	mov R2, A
	acall fetchc_postinc
	mov R3, A
	orl A, R2
	inc A
	jnz setup_not_default
	ajmp setup_default
setup_not_default:
	mov A, R2
	xrl A, bmRequestType
	jnz setup_dispatch_check_next
	mov A, R3
	xrl A, bRequest
	jnz setup_dispatch_check_next
	acall fetchc_postinc
	mov R2, A
	acall fetchc_postinc
	mov DPL, A
	mov DPH, R2
	acall setup_dispatch_do_call

	jnb usbStateSetupInvalid, setup_done_valid
	mov A, #0xac  ; Stall IN/OUT EPs
	mov R0, #IEPCNF0
	movx @R0, A
	mov R0, #OEPCNF0
	movx @R0, A
	clr A
	mov R0, #IEPDCNTX0
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A
	sjmp setup_exit

setup_done_valid:
	mov A, bmRequestType
	jb ACC.7, setup_exit

	; Unnak IN for final ACK
	clr A
	mov R0, #IEPDCNTX0
	movx @R0, A

setup_exit:
	; Late ACK for SETUP interrupt
	mov R0, #VECINT
	movx @R0, A
	ret

setup_dispatch_do_call:
	clr A
	jmp @A+DPTR

setup_dispatch_table:
	setup_entry 0x80 0 setup_dth_dev_get_status
	setup_entry 0x80 6 setup_dth_dev_get_descriptor
	setup_entry 0xc0 0x90 setup_dth_vend_read_xram
	setup_entry 0x40 0x91 setup_dth_vend_write_xram
	setup_entry 0xc0 0x94 setup_dth_vend_read_code
	setup_entry 0xc0 0x96 setup_dth_vend_read_iram
	setup_entry 0x40 0x97 setup_dth_vend_write_iram
	setup_entry 0xc0 0x9a setup_dth_vend_read_codec
	setup_entry 0x40 0x9b setup_dth_vend_write_codec
	setup_entry 0xc0 0xa0 setup_dth_vend_read_envelope
	setup_entry 0xa1 0x81 setup_dth_class_if_get_cur
	setup_entry 0xa1 0x82 setup_dth_class_if_get_min
	setup_entry 0xa1 0x83 setup_dth_class_if_get_max
	setup_entry 0xa1 0x84 setup_dth_class_if_get_res
	setup_entry 0x21 0x01 setup_htd_class_if_set_cur
	setup_entry 0x21 0x02 setup_htd_class_if_set_min
	setup_entry 0x21 0x03 setup_htd_class_if_set_max
	setup_entry 0x21 0x04 setup_htd_class_if_set_res
	setup_entry 0x00 5 setup_htd_dev_set_address
	setup_entry 0x00 9 setup_htd_dev_set_configuration
	setup_entry 0x01 0x0b setup_htd_dev_set_interface
	.byte 0xff, 0xff

setup_dth_vend_read_iram:
	mov txPtrLo, wIndexLo
	ajmp writei_to_ep0

setup_dth_vend_read_codec:
	; CS4272 regs are at addr 1 to 8
	mov A, wIndexLo
	dec A
	anl A, #7
	add A, #codecCache
	mov txPtrLo, A  ; read cache value
	ajmp writei_to_ep0

setup_dth_vend_read_xram:
	mov txPtrLo, wIndexLo
	mov txPtrHi, wIndexHi
	ajmp writex_to_ep0

setup_dth_vend_read_code:
	mov txPtrLo, wIndexLo
	mov txPtrHi, wIndexHi
	ajmp write_to_ep0

setup_dth_vend_read_envelope:
	clr A
	xch A, envMaxL
	mov getBuf, A
	clr A
	xch A, envMaxR
	mov getBuf+1, A
	mov txPtrLo, #getBuf
	ajmp writei_to_ep0

setup_dth_vend_write_iram:
	mov R0, wIndexLo
	mov A, wValueLo
	mov @R0, A
	ajmp write_to_ep0  ; 0-byte write

setup_dth_vend_write_codec:
	mov R2, wIndexLo
	mov R3, wValueLo
	acall codec_spi_write
	ajmp write_to_ep0  ; 0-byte write

setup_dth_vend_write_xram:
	mov DPL, wIndexLo
	mov DPH, wIndexHi
	mov A, wValueLo
	movx @DPTR, A
	ajmp write_to_ep0  ; 0-byte write

setup_htd_class_if_set_min:
setup_htd_class_if_set_max:
setup_htd_class_if_set_res:
	; not supported
	setb usbStateSetupInvalid
	ret

setup_htd_class_if_set_cur:
	mov A, #'V'
	acall serial_write

	mov R0, #(EP0_OUT + 1)
	movx A, @R0
	; Negate value (register is attenuation in dB)
	cpl A
	inc A
	anl A, #0x7f
	push ACC
	acall serial_hex
	pop ACC

	; Not bothering exposing the channels seperately here
	mov R2, #CS4272_DAC_A_MUTE_VOL
	mov R3, A
	acall codec_spi_write
	mov R2, #CS4272_DAC_B_MUTE_VOL
	acall codec_spi_write
	ret

setup_dth_class_if_get_write:
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	mov txSizeLo, #0x2
	ajmp write_to_ep0

setup_dth_class_if_get_min:
	mov DPTR, #uac_volume_min
	sjmp setup_dth_class_if_get_write

setup_dth_class_if_get_max:
	mov DPTR, #uac_volume_max
	sjmp setup_dth_class_if_get_write

setup_dth_class_if_get_res:
	mov DPTR, #uac_volume_res
	sjmp setup_dth_class_if_get_write

setup_dth_class_if_get_cur:
	mov A, #'u'
	acall serial_write

	mov A, wIndexHi
	acall serial_hex

	; Check requested control is in supported range
	mov A, wValueHi
	jz setup_dth_class_if_get_stall
	add A, #-3
	jc setup_dth_class_if_get_stall

	mov A, wIndexLo
	acall serial_hex

	mov A, bRequest
	acall serial_hex
	mov A, wValueHi
	acall serial_hex
	mov A, wValueLo
	acall serial_hex
	mov A, wLengthLo
	acall serial_hex

	clr A
	mov getBuf, A
	mov getBuf+1, A

	mov txSizeLo, #0x2
	mov txPtrLo, #getBuf
	acall writei_to_ep0
	
	; not checking wIndex since there only is one feature unit
	ret

setup_dth_class_if_get_stall:
	ajmp write_stall_ep0

setup_dth_dev_get_status:
	mov DPTR, #usb_status_ok
	mov txSizeLo, #2
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	acall write_to_ep0
	ret

setup_dth_dev_get_descriptor:
	mov A, wValueHi
	acall dispatch
	dispatch_entry 3 setup_dth_get_desc_string
	dispatch_entry 2 setup_dth_get_desc_configuration
	dispatch_entry 1 setup_dth_get_desc_device
	dispatch_entry 0 setup_dth_get_desc_bad

clamp_size:
	mov A, wLengthLo
	clr C
	subb A, txSizeLo
	mov A, wLengthHi
	subb A, txSizeHi
	jnc clamp_size_exit
	mov txSizeHi, wLengthHi
	mov txSizeLo, wLengthLo
clamp_size_exit:
	ret

setup_dth_get_desc_device:
	mov DPTR, #usb_dev_desc
	mov txSizeLo, #0x12
setup_dth_get_desc:
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	acall clamp_size

	acall write_to_ep0
	ret

setup_dth_get_desc_configuration:
	mov DPTR, #usb_cnf_desc
	mov txSizeHi, #(usb_cnf_len >> 8)
	mov txSizeLo, #usb_cnf_len
	sjmp setup_dth_get_desc

setup_dth_get_desc_string:
	mov A, wValueLo
	cjne A, #0, not_string_0
	mov DPTR, #usb_string_lang
	mov txSizeLo, #4
	sjmp string_write
not_string_0:
	setb usbStateZeroPad
	setb usbStateStringCnt
	mov DPTR, #usb_s_mfg
	; first byte is precalulated length byte
	clr A
	movc A, @A+DPTR
	mov txSizeLo, A
string_write:
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	acall write_to_ep0
	ret

setup_dth_get_desc_bad:
	mov A, #'d'
	acall serial_write
	mov A, wValueHi
	acall serial_hex
	mov A, wValueLo
	acall serial_hex
	; Cause IN to STALL
	setb usbStateIn0Done
	acall write_to_ep0
	ret

setup_htd_dev_set_address:
	setb usbStateSetAddress
	mov R0, #IEPDCNTX0
	clr A
	movx @R0, A
	mov A, #'a'
	acall serial_write
	ret

setup_htd_dev_set_configuration:
	mov A, #'c'
	acall serial_write

	; TODO: Add delays? Seems to work without...
	; Turn on power
	clr P1.6
	; Basic codec setup (sets up clock)
	acall codec_init
	; Release reset
	clr P1.7
	; External clock, no delay should be needed between releasing
	; reset and starting the cs4272 control port write.
	acall codec_spi_init
	; Enable c-port
	mov R0, #GLOBCTL
	movx A, @R0
	setb ACC.0
	movx @R0, A
	; Basic codec setup (sets up clock)
	; Called again since some settings (e.g. ACGDCTL) don't take unless c-port is enabled already
	; FIXME: There is probably a better "proper" order for these writes.
	; This also sets up ~384KHz MCKLO2, which is needed for syncing the 48V step-up.
	; The wrong step-up sync frequency (in particular too high, observed with 3MHz MCLKO2)
	; can cause overcurrent from keeping the MOSFET on for too long!
	acall codec_init

	; Enable PSOF/SOF interrupt
	mov sofCtr, #0x00
	mov freqLockCtr, #10
	mov R0, #USBIMSK
	movx A, @R0
	orl A, #0x18
	movx @R0, A

	ret

setup_htd_dev_set_interface:
	mov A, #'i'
	acall serial_write
	mov A, wIndexLo   ; interface index
	acall serial_hex
	mov A, #'a'
	acall serial_write
	mov A, wValueLo   ; altsetting index
	acall serial_hex

	mov A, wIndexLo
	cjne A, #1, set_interface_not_if1
	; Interface 1 (playback)
	mov A, wValueLo   ; altsetting index
	xrl A, #0x80
	acall dispatch
	dispatch_entry (0x80^0x00) set_interface_if1_as0_off
	dispatch_entry (0x80^0x01) set_interface_if1_as1_16bit_2ch
	dispatch_entry (0x80^0x02) set_interface_if1_as2_16bit_4ch
	dispatch_entry (0x80^0x03) set_interface_if1_as3_24bit_2ch
	dispatch_entry (0x80^0x04) set_interface_if1_as4_24bit_4ch
	dispatch_entry 0 set_interface_error

set_interface_not_if1:
	cjne A, #2, set_interface_not_if2
	; Interface 2 (record)
	mov A, wValueLo   ; altsetting index
	xrl A, #0x80
	acall dispatch
	dispatch_entry (0x80^0x00) set_interface_if2_as0_off
	dispatch_entry (0x80^0x01) set_interface_if2_as1_16bit_2ch
	dispatch_entry (0x80^0x02) set_interface_if2_as2_24bit_2ch
	dispatch_entry 0 set_interface_error

set_interface_not_if2:
set_interface_error:
	setb usbStateSetupInvalid
	ret

set_interface_if1_as0_off:
	clr audioIf1On
	ret

set_interface_if1_as1_16bit_2ch:
	jnb audioIf2On, set_interface_if1_as1_16bit_2ch_do
	jb audio24bit, set_interface_error
set_interface_if1_as1_16bit_2ch_do:
	mov DPTR, #codec_out_2ch_16bit
	jnb swapOutput, set_interface_if1_as1_16bit_2ch_do_unswapped
	mov DPTR, #codec_out_2ch_16bit_alt
set_interface_if1_as1_16bit_2ch_do_unswapped:
	acall usb_init_loop
	sjmp set_interface_if1_exit_on_16bit

set_interface_if1_as2_16bit_4ch:
	jnb audioIf2On, set_interface_if1_as2_16bit_4ch_do
	jb audio24bit, set_interface_error
set_interface_if1_as2_16bit_4ch_do:
	mov DPTR, #codec_out_4ch_16bit
	acall usb_init_loop
	sjmp set_interface_if1_exit_on_16bit

set_interface_if1_as3_24bit_2ch:
	jnb audioIf2On, set_interface_if1_as3_24bit_2ch_do
	jnb audio24bit, set_interface_error
set_interface_if1_as3_24bit_2ch_do:
	mov DPTR, #codec_out_2ch_24bit
	jnb swapOutput, set_interface_if1_as3_24bit_2ch_do_unswapped
	mov DPTR, #codec_out_2ch_24bit_alt
set_interface_if1_as3_24bit_2ch_do_unswapped:
	acall usb_init_loop
	sjmp set_interface_if1_exit_on_24bit

set_interface_if1_as4_24bit_4ch:
	jnb audioIf2On, set_interface_if1_as4_24bit_4ch_do
	jnb audio24bit, set_interface_error
set_interface_if1_as4_24bit_4ch_do:
	mov DPTR, #codec_out_4ch_24bit
	acall usb_init_loop
	sjmp set_interface_if1_exit_on_24bit

set_interface_if1_exit_on_16bit:
	acall codec_set_16bit
	setb audioIf1On
	ret

set_interface_if1_exit_on_24bit:
	acall codec_set_24bit
	setb audioIf1On
	ret

set_interface_if2_as0_off:
	clr audioIf2On
	ret

set_interface_if2_as1_16bit_2ch:
	jnb audioIf1On, set_interface_if2_as1_16bit_2ch_do
	jb audio24bit, set_interface_error
set_interface_if2_as1_16bit_2ch_do:
	mov DPTR, #codec_in_2ch_16bit
	acall usb_init_loop
	acall codec_set_16bit
	sjmp set_interface_if2_exit_on

set_interface_if2_as2_24bit_2ch:
	jnb audioIf1On, set_interface_if2_as2_24bit_2ch_do
	jnb audio24bit, set_interface_error
set_interface_if2_as2_24bit_2ch_do:
	mov DPTR, #codec_in_2ch_24bit
	acall usb_init_loop
	acall codec_set_24bit
	sjmp set_interface_if2_exit_on

set_interface_if2_exit_on:
	setb audioIf2On
	ret

setup_default:
	setb usbStateSetupInvalid
	mov A, #'?'
	acall serial_write
	mov A, bmRequestType
	acall serial_hex
	mov A, bRequest
	acall serial_hex
	ret

vec_sof_waitlock:
	djnz sofCtr, vec_sof_waitlock_nodec
	dec A
	mov freqLockCtr, A
vec_sof_waitlock_nodec:

	ret

vec_sof_softpll:
	mov A, freqLockCtr
	jnz vec_sof_waitlock

	; Update delta from capture and previous capture
	mov R0, #ACGCAPL
	movx A, @R0
	clr C
	subb A, pACGCapL
	mov acgDeltaL, A
	mov R2, A
	movx A, @R0
	mov pACGCapL, A  ; Update previous value

	mov R0, #ACGCAPH
	movx A, @R0
	subb A, pACGCapH
	add A, #-0x30    ; Subtract expected delta (0x3000 for 48kHz)
	mov acgDeltaH, A
	movx A, @R0
	mov pACGCapH, A  ; Update previous value

	; Load R3 with sign-extend value
	mov A, acgDeltaH
	mov R3, #0
	jnb ACC.7, vec_sof_softpll_delta_pos
	dec R3
vec_sof_softpll_delta_pos:

	; Accumulate error
	; At 48kHz, 1 sample offset is equivalent to 256 running sum
	xch A, R2
	add A, acgFrqLo
	mov acgFrqLo, A
	mov R0, #ACGFRQ0
	movx A, @R0
	addc A, R2
	mov R2, A

	; Ripple carry into ACGFRQ1 + ACGFRQ2
	mov R4, #2
vec_sof_softpll_carry_loop:
	dec R0
	movx A, @R0
	addc A, R3
	movx @R0, A
	djnz R4, vec_sof_softpll_carry_loop

	; Final write to ACGFRQ0 to load latch
	mov R0, #ACGFRQ0
	mov A, R2
	movx @R0, A

	djnz sofCtr, vec_sof_noprint

	mov A, #13
	acall serial_write
	mov A, #10
	acall serial_write
	mov A, #'f'
	acall serial_write
	mov A, acgDeltaH
	acall serial_hex
	mov A, acgDeltaL
	acall serial_hex
	mov R0, #ACGFRQ2
	movx A, @R0
	acall serial_hex
	mov R0, #ACGFRQ1
	movx A, @R0
	acall serial_hex
	mov R0, #ACGFRQ0
	movx A, @R0
	acall serial_hex
	mov A, acgFrqLo
	acall serial_hex

vec_sof_noprint:
	lcall update_envelope
	ret


dispatch:
	pop DPH
	pop DPL
	mov R0, A
dispatch_loop:
	acall fetchc_postinc
	jz dispatch_do
	xrl A, R0
	jz dispatch_do
	inc DPTR
	sjmp dispatch_loop
dispatch_do:
	acall fetchc_postinc
	jmp @A+DPTR

writex_to_ep0:
	setb usbStateCopyXRAM
	sjmp write_to_ep0

writei_to_ep0:
	setb usbStateCopyIRAM

write_to_ep0:
	mov A, #'w'
	jnb usbStateAddressValid, write_to_ep0_addr_not_set
	mov A, #'W'
write_to_ep0_addr_not_set:
	acall serial_write

	; Check if this is a 0byte-write and bail out early
	mov A, txSizeLo
	orl A, txSizeHi
	mov R1, A
	jz write_empty_to_ep0

	mov DPH, txPtrHi
	mov DPL, txPtrLo

	; Clamp packet byte count to EP0 size
	mov A, txSizeHi
	jnz write_to_ep0_big
	mov A, #EP0_BYTES   ; Clamp size
	clr C
	subb A, txSizeLo
	mov R2, txSizeLo
	jnc write_to_ep0_copy
write_to_ep0_big:
	mov R2, #EP0_BYTES

write_to_ep0_copy:
	; Save packet size in R1 for updating IEPDCNTX0 later
	mov R1, AR2
	mov R0, #EP0_IN

	; Copy data into EP0 xmit buffer
desc_copy_loop:
	jb usbStateCopyIRAM, desc_copy_iram
	jb usbStateCopyXRAM, desc_copy_xram
	acall fetchc_postinc
	sjmp desc_copy_write
desc_copy_xram:
	acall fetchx_postinc
	sjmp desc_copy_write
desc_copy_iram:
	acall fetchi_postinc
desc_copy_write:
	movx @R0, A
	inc R0

	; Special case for string descriptor expansion
	jnb usbStateZeroPad, desc_copy_no_zeropad
	dec R2
	mov A, #3
	; Extra-special case for the length byte,
	; the next byte is 3 to indicate a string descriptor.
	jbc usbStateStringCnt, desc_copy_3pad
	clr A
desc_copy_3pad:
	movx @R0, A
	inc R0
desc_copy_no_zeropad:
	djnz R2, desc_copy_loop

	; Update txPtr
	mov txPtrHi, DPH
	mov txPtrLo, DPL

	; Subtract R1 from txSize
	mov A, txSizeLo
	clr C
	subb A, R1
	mov txSizeLo, A
	mov A, txSizeHi
	subb A, #0
	mov txSizeHi, A

write_empty_to_ep0:
	jb usbStateIn0Done, write_stall_ep0
	mov R0, #IEPDCNTX0
	mov A, R1     ; Then un-nak and write the new count
	movx @R0, A
	acall serial_hex
	clr C
	mov A, R1
	subb A, #EP0_BYTES
	jnb usbStateAddressValid, write_done
	jz write_not_yet_done
write_done:
	setb usbStateIn0Done
	; Clear nack for expected status transaction (OUT)
	clr A
	mov R0, #OEPDCNTX0
	movx @R0, A
write_not_yet_done:
	ret
write_stall_ep0:
	mov A, #'s'
	acall serial_write
	mov R0, #IEPCNF0  ; Stall for IN
	movx A, @R0
	orl A, #8
	movx @R0, A
	ret

codec_init:
	mov DPTR, #codec_init_data
	sjmp usb_init_loop

codec_set_16bit:
	jnb audio24bit, codec_set_skip
	clr audio24bit
	mov DPTR, #codec_16bit
	sjmp usb_init_loop
codec_set_skip:
	ret

codec_set_24bit:
	jb audio24bit, codec_set_skip
	setb audio24bit
	mov DPTR, #codec_24bit
	sjmp usb_init_loop

usb_init:
	mov usbState, #0
	mov usbState2, #0
	mov audioState, #0

	mov DPTR, #usb_init_data
usb_init_loop:
	acall fetchc_postinc
	jz usb_init_end

	mov R0, A
	acall fetchc_postinc

	movx @R0, A
	sjmp usb_init_loop

usb_init_end:
serial_puts_done:
	ret

serial_puts:
	acall fetchc_postinc
	jz serial_puts_done
	acall serial_write
	sjmp serial_puts

serial_hex:
	push ACC
	swap A
	acall serial_hex_nibble
	pop ACC
	; fall through to serial_hex_nibble

serial_hex_nibble:
	anl A, #0xf
	add A, #-0xa
	jnc serial_hex_digit
	add A, #0x27 ; 'a' - '0' - 0xa
serial_hex_digit:
	add A, #0x3a ; '0' + 0xa
	; fall through to serial_write

serial_write:
	push AR0
	push AR2
	mov R2, A
serial_write_wait:
	mov A, uartWritePtr
	mov R0, A
	inc A
	orl A, #uartbuf
	xrl A, uartReadPtr
	jz serial_write_wait  ; Wait for buffer to empty
	mov @R0, AR2
	mov A, R0
	inc A
	orl A, #uartbuf
	mov uartWritePtr, A
serial_write_exit:
	pop AR2
	pop AR0
	jbc uartEmpty, serial_trigger
	ret

serial_trigger:
	setb TI
	ret

uart_vec:
	jnb RI, uart_check_tx
	clr RI
uart_check_tx:
	jnb TI, uart_ret
	clr TI
	mov R1, uartReadPtr
	mov A, R1
	xrl A, uartWritePtr
	jz uart_empty
	mov A, @R1
	inc R1
	mov SBUF, A
	mov A, R1
	orl A, #uartbuf
	mov uartReadPtr, A
uart_ret:
	mov A, R7
	pop PSW
	reti
uart_empty:
	setb uartEmpty
	sjmp uart_ret

codec_spi_write:
	clr P1.1 ; SPICLK
	clr P1.3 ; SPICS
	mov A, #0x20
	acall codec_spi_byte
	mov A, R2
	acall codec_spi_byte
	mov A, R3
	acall codec_spi_byte
	setb P1.3 ; SPICS
	setb P1.1 ; SPICLK

	; Save written value in cache for later 'read'
	mov A, R2
	dec A
	anl A, #7
	add A, #codecCache
	mov R0, A
	mov A, R3
	mov @R0, A

codec_spi_init_end:
	ret

codec_spi_init:
	mov DPTR, #codec_spi_init_init_data
codec_spi_init_loop:
	acall fetchc_postinc
	jz codec_spi_init_end

	mov R2, A
	acall fetchc_postinc

	mov R3, A
	acall codec_spi_write
	sjmp codec_spi_init_loop

codec_spi_byte:
	mov R0, #8
codec_spi_bit:
	clr P1.1
	rlc A
	mov P1.0, C
	setb P1.1
	djnz R0, codec_spi_bit
	ret

.equ ENVELOPE_SRC, EP1_OUTX
update_envelope:
	jb audio24bit, update_envelope_24bit

update_envelope_16bit:
	; Short on cycles, just sampling the data...
	; Buffer data  is stored least significant byte first

	; Left channel
	mov R2, envMaxL
	mov DPTR, #(ENVELOPE_SRC + 1)  ; L1
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 1 + (4 * 1))  ; L2
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 1 + (4 * 7))  ; L3
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 1 + (4 * 17))  ; L4
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 1 + (4 * 23))  ; L5
	acall update_max
	mov envMaxL, R2

	; Right channel
	mov R2, envMaxR
	mov DPTR, #(ENVELOPE_SRC + 3)  ; R1
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 3 + (4 * 1))  ; R2
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 3 + (4 * 7))  ; R3
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 3 + (4 * 17))  ; R4
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 3 + (4 * 23))  ; R5
	acall update_max
	mov envMaxR, R2
	ret

update_envelope_24bit:
	; Short on cycles, just sampling the data...
	; Buffer data  is stored least significant byte first

	; Left channel
	mov R2, envMaxL
	mov DPTR, #(ENVELOPE_SRC + 2)  ; L1
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 2 + (6 * 1))  ; L2
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 2 + (6 * 7))  ; L3
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 2 + (6 * 17))  ; L4
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 2 + (6 * 23))  ; L5
	acall update_max
	mov envMaxL, R2

	; Right channel
	mov R2, envMaxR
	mov DPTR, #(ENVELOPE_SRC + 5)  ; R1
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 5 + (6 * 1))  ; R2
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 5 + (6 * 7))  ; R3
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 5 + (6 * 17))  ; R4
	acall update_max
	mov DPTR, #(ENVELOPE_SRC + 5 + (6 * 23))  ; R5
	acall update_max
	mov envMaxR, R2
	ret

update_max:
	movx A, @DPTR
	; Make abs value
	jnb ACC.7, 1$
	cpl A
1$:
	; Compare to envMax
	cjne A, AR2, 3$
2$:
	; Less or equal
	ret
3$:
	jc 2$  ; Jump if A < envMax
	; Greater, update envMax
	mov R2, A
	ret

.ascii "DATA"

usb_init_data:
.byte IEPCNF0, 0x8c  ; IEPCNF0 = 0x8c (Enable EP & irq, stalled)
.byte IEPBBAX0, EP0_IN_BBAX  ; IEPBBAX0 = 0xe4 (=> 0xff20)
.byte IEPBSIZ0, EP0_IN_SIZ  ; IEPBSIZ0 = 0x01 (8 bytes)
.byte OEPCNF0, 0x8c  ; OEPCNF0 = 0x8c
.byte OEPBBAX0, EP0_OUT_BBAX ; OEPBBAX0 = 0xe3 (=> 0xff18)
.byte OEPBSIZ0, EP0_OUT_SIZ  ; OEPBSIZ0 = 0x01 (8 bytes)

.byte OEPCNF1, 0xc3  ; Enable, isochronous, double-buffered, not stalled, 4 bytes per sample
.byte OEPBBAX1, EP1_OUT_BBAX
.byte OEPBBAY1, EP1_OUT_BBAY
.byte OEPBSIZ1, EP1_OUT_SIZ
.byte IEPCNF2, 0xc3 ; Enable, isochronous, double-buffered, not stalled, 4 bytes per sample
.byte IEPBBAX2, EP2_IN_BBAX
.byte IEPBBAY2, EP2_IN_BBAY
.byte IEPBSIZ2, EP2_IN_SIZ

.byte USBFADR, 0x00  ; USBFADDR = 0x00
.byte USBSTA, 0x00  ; USBSTA = 0x00
.byte USBIMSK, 0x84  ; USBIMSK = 0x9c (reset, setup irqs enabled)
.byte USBCTL, 0xc0  ; USBCTL = 0xc0 (enable pull-up and hw)
.byte 0x00

codec_init_data:
; fOut = 25000000 * 192/8/512 / ACGFRQ [24-50]
; ACGFRQ = 1171875 / fOut
; 1171875 / 48000
; 11000.0110101000000000000000000000000000
.byte ACGFRQ1, 0xa8
.byte ACGFRQ2, 0x61 ; 0x61a800 => 24.576MHz MCLK => 48kHz
.byte ACGFRQ0, 0x00
.byte ACGCTL, 0x54  ; Enable MCLKO, capture source MCLKO, input is MCLKI2, enable divider
.byte ACGDCTL, 0x17 ; divm is 2 (MCLKO), divi is 8 (MCLKI2)
.byte CPTCNF1, 0x0c  ; 2 time slot per frame; i2s mode 4 6ch out 2ch in
.byte CPTCNF2, 0xcd  ; 32/32 csclk per slot, 16bits per slot
;.byte CPTCNF2, 0xe5  ; 32/32 csclk per slot, 24bits per slot
.byte CPTCNF3, 0xac  ; endian swap
;.byte CPTCNF3, 0xa8  ; no endian swap
.byte CPTCNF4, 0x03  ; CSCLK is MCLK divided by 4
.byte DMATSH0, 0x40  ; 2 bytes per slot
;.byte DMATSH0, 0x80  ; 3 bytes per slot
.byte DMATSL0, 0x11  ; Enable slots 0,4
;.byte DMATSL0, 0x22  ; Enable slots 1,5
.byte DMACTL0, 0x81  ; Enable, EP 1 OUT
.byte DMATSH1, 0x40  ; 2 bytes per slot
;.byte DMATSH1, 0x80  ; 3 bytes per slot
.byte DMATSL1, 0x11  ; Enable slots 0,4
.byte DMACTL1, 0x8a  ; Enable, EP 2 IN
.byte 0x00

codec_16bit:
.byte DMACTL0, 0x01  ; Disable, EP 1 OUT
.byte DMACTL1, 0x0a  ; Disable, EP 2 IN
.byte GLOBCTL, 0xc4  ; 24MHz, USB on, C-Port off
.byte CPTCNF2, 0xcd  ; 32/32 csclk per slot, 16bits per slot
.byte GLOBCTL, 0xc5  ; 24MHz, USB on, C-Port on
.byte DMATSH0, 0x40  ; 2 bytes per slot
.byte DMATSH1, 0x40  ; 2 bytes per slot
.byte DMACTL0, 0x81  ; Enable, EP 1 OUT
.byte DMACTL1, 0x8a  ; Enable, EP 2 IN
.byte 0x00

codec_24bit:
.byte DMACTL0, 0x01  ; Disable, EP 1 OUT
.byte DMACTL1, 0x0a  ; Disable, EP 2 IN
.byte GLOBCTL, 0xc4  ; 24MHz, USB on, C-Port off
.byte CPTCNF2, 0xe5  ; 32/32 csclk per slot, 24bits per slot
.byte GLOBCTL, 0xc5  ; 24MHz, USB on, C-Port on
.byte DMATSH0, 0x80  ; 3 bytes per slot
.byte DMATSH1, 0x80  ; 3 bytes per slot
.byte DMACTL0, 0x81  ; Enable, EP 1 OUT
.byte DMACTL1, 0x8a  ; Enable, EP 2 IN
.byte 0x00

codec_out_2ch_16bit:
.byte DMATSL0, 0x11  ; Enable slots 0,4
.byte OEPCNF1, 0xc3  ; Enable, isochronous, double-buffered, not stalled, 4 bytes per sample
.byte 0x00

codec_out_2ch_16bit_alt:
.byte DMATSL0, 0x22  ; Enable slots 1,5
.byte OEPCNF1, 0xc3  ; Enable, isochronous, double-buffered, not stalled, 4 bytes per sample
.byte 0x00

codec_out_4ch_16bit:
.byte DMATSL0, 0x33  ; Enable slots 0,1,4,5
.byte OEPCNF1, 0xc7  ; Enable, isochronous, double-buffered, not stalled, 8 bytes per sample
.byte 0x00

codec_out_2ch_24bit:
.byte DMATSL0, 0x11  ; Enable slots 0,4
.byte OEPCNF1, 0xc5  ; Enable, isochronous, double-buffered, not stalled, 6 bytes per sample
.byte 0x00

codec_out_2ch_24bit_alt:
.byte DMATSL0, 0x22  ; Enable slots 1,5
.byte OEPCNF1, 0xc5  ; Enable, isochronous, double-buffered, not stalled, 6 bytes per sample
.byte 0x00

codec_out_4ch_24bit:
.byte DMATSL0, 0x33  ; Enable slots 0,1,4,5
.byte OEPCNF1, 0xcb  ; Enable, isochronous, double-buffered, not stalled, 12 bytes per sample
.byte 0x00

codec_in_2ch_16bit:
.byte DMATSL1, 0x11  ; Enable slots 0,4
.byte IEPCNF2, 0xc3  ; Enable, isochronous, double-buffered, not stalled, 4 bytes per sample
.byte 0x00

codec_in_2ch_24bit:
.byte DMATSL1, 0x11  ; Enable slots 0,4
.byte IEPCNF2, 0xc5  ; Enable, isochronous, double-buffered, not stalled, 6 bytes per sample
.byte 0x00

.equ CS4272_MODE_CONTROL1,   0x01
.equ CS4272_DAC_CONTROL,     0x02
.equ CS4272_DAC_MIX_CONTROL, 0x03
.equ CS4272_DAC_A_MUTE_VOL,  0x04
.equ CS4272_DAC_B_MUTE_VOL,  0x05
.equ CS4272_ADC_CONTROL,     0x06
.equ CS4272_MODE_CONTROL2,   0x07

codec_spi_init_init_data:
.byte 0x07, 0x03 ; mode control 2 = 0x03; power down and enable control port mode
.byte 0x01, 0x01 ; mode control 1 = 0x01; i2s, up to 24bit, singe-speed, slave mode
.byte 0x02, 0x80 ; dac control = 0x80; enable auto-mute
.byte 0x03, 0x39 ; dac & mixing control = 0x39; enable soft-ramp and zero cross
.byte 0x04, 0x80 ; dac a mute & volume; mute
.byte 0x05, 0x80 ; dac b mute & volume; mute
.byte 0x06, 0x1c ; adc control = 0x1c; i2s, up to 24bit, disable 16bit dither, mute
.byte 0x07, 0x02 ; mode control 2 = 0x02; power up, control port mode
.byte 0x07, 0x02 ; mode control 2 = 0x02; power up, control port mode
.byte 0x04, 0x00 ; dac a mute & volume; unmute
.byte 0x05, 0x00 ; dac b mute & volume; unmute
.byte 0x06, 0x10 ; adc control = 0x10; unmute
.byte 0x00

.macro usb_word val
	.byte (val & 0xff)
	.byte (val >> 8)
.endm

.macro usb_ac_freq val
	.byte (val & 0xff)
	.byte (val >> 8)
	.byte (val >> 16)
.endm

.equ DEVICE_DESCRIPTOR, 1
.equ CONFIGURATION_DESCRIPTOR, 2
.equ INTERFACE_DESCRIPTOR, 4
.equ ENDPOINT_DESCRIPTOR, 5
.equ AUDIOCONTROL_INTERFACE_DESCRIPTOR, 36
.equ AUDIOSTREAMING_INTERFACE_DESCRIPTOR, 36
.equ AUDIOSTREAMING_ENDPOINT_DESCRIPTOR, 37

.equ UAC_HEADER, 1
.equ UAC_INPUT_TERMINAL, 2
.equ UAC_OUTPUT_TERMINAL, 3
.equ UAC_FEATURE_UNIT, 6
.equ UAC_AS_GENERAL, 1
.equ UAC_AS_FORMAT_TYPE, 2
.equ UAC_AS_FORMAT_TYPE_I, 1

.equ UAC_FU_MUTE_CONTROL, 1
.equ UAC_FU_VOLUME_CONTROL, 2

usb_dev_desc:
.byte 0x12, DEVICE_DESCRIPTOR  ; Size, type (device)
usb_word 0x0110   ; USB Version (1.10)
.byte 0, 0, 0     ; Class/Subclass/Protocol
.byte EP0_BYTES   ; EP0 max packet size
usb_word 0x0451   ; Vendor 0x0451
usb_word 0x3201   ; Id 0x3201
usb_word 0x0100   ; Device version (1.00)
.byte 1           ; iManufacturer
.byte 1           ; iProduct
.byte 0           ; iSerial
.byte 1           ; bNumConfigurations

usb_cnf_desc:
.byte 0x09, CONFIGURATION_DESCRIPTOR  ; Size, type (config)
usb_word usb_cnf_len ; Total length
.byte 4           ; bNumInterfaces
.byte 1           ; bConfigurationValue
.byte 0           ; iConfiguration
.byte 0x80        ; bmAttributes (bus powered)
.byte 498/2       ; bMaxPower (498mA)

usb_if0_desc:
.byte 0x09, INTERFACE_DESCRIPTOR  ; Size, type (interface)
.byte 0           ; bInterfacenNmber
.byte 0           ; bAlternateSetting
.byte 0           ; bNumEndpoints
.byte 1, 1, 0     ; Class/Subclass/Protocol (Audio/Control)
.byte 0           ; iInterface

uac_if0_desc:
.byte 10, AUDIOCONTROL_INTERFACE_DESCRIPTOR  ; Size, type (audiocontrol interface)
.byte UAC_HEADER  ; bDescriptorSubtype (HEADER)
usb_word 0x0100   ; bcdADC (1.00)
usb_word uac_if0_len ; wTotalLength
.byte 2           ; bInCollection
.byte 1           ; baInterfaceNr(0)
.byte 2           ; baInterfaceNr(1)

.byte 12, AUDIOCONTROL_INTERFACE_DESCRIPTOR
.byte UAC_INPUT_TERMINAL  ; bDescriptorSubtype (INPUT_TERMINAL)
.byte 1           ; bTerminalID
usb_word 0x0101   ; wTerminalType (0x0101 USB Streaming)
.byte 0           ; bAssocTerminal
.byte 4           ; bNrChannels
usb_word 0x0033   ; wChannelConfig (Left Front, Right Front, Left Surround, Right Surround)
.byte 0           ; iChannelNames
.byte 0           ; iTerminal

.byte 8, AUDIOCONTROL_INTERFACE_DESCRIPTOR
.byte UAC_FEATURE_UNIT ; bDescriptorSubtype 6 (FEATURE_UNIT)
.byte 2           ; bUnitID
.byte 1           ; bSourceID
.byte 1           ; bControlSize
.byte 0x02        ; bmaControls0 (Volume)
.byte 0           ; iFeature

.byte 9, AUDIOCONTROL_INTERFACE_DESCRIPTOR
.byte UAC_OUTPUT_TERMINAL ; bDescriptorSubtype      3 (OUTPUT_TERMINAL)
.byte 3           ; bTerminalID
usb_word 0x0301   ; wTerminalType      0x0301 Speaker
.byte 0           ; bAssocTerminal
.byte 2           ; bSourceID
.byte 0           ; iTerminal

.byte 12, AUDIOCONTROL_INTERFACE_DESCRIPTOR
.byte UAC_INPUT_TERMINAL ; bDescriptorSubtype      2 (INPUT_TERMINAL)
.byte 4           ; bTerminalID
usb_word 0x0603   ; wTerminalType      0x0603 Line Connector
.byte 0           ; bAssocTerminal          0
.byte 2           ; bNrChannels             2
usb_word 0x0003   ; wChannelConfig     0x0003 (Left Front, Right Front)
.byte 0           ; iChannelNames
.byte 0           ; iTerminal

.byte 9, AUDIOCONTROL_INTERFACE_DESCRIPTOR
.byte UAC_OUTPUT_TERMINAL ; bDescriptorSubtype      3 (OUTPUT_TERMINAL)
.byte 6          ; bTerminalID             6
usb_word 0x0101  ; wTerminalType      0x0101 USB Streaming
.byte 0          ; bAssocTerminal          0
.byte 4          ; bSourceID               4
.byte 0          ; iTerminal               0
uac_if0_end:
.equ uac_if0_len, (uac_if0_end - uac_if0_desc)
usb_if0_end:

.macro .usb_if_desc bIntfNum bAltSetting bNumEPs bClass bSubClass bProtocol iInterface
.byte 9, INTERFACE_DESCRIPTOR ; Size, type
.byte bIntfNum    ; bInterfaceNumber
.byte bAltSetting ; bAlternateSetting
.byte bNumEPs     ; bNumEndpoints
.byte bClass      ; bInterfaceClass         1 Audio
.byte bSubClass   ; bInterfaceSubClass      2 Streaming
.byte bProtocol   ; bInterfaceProtocol
.byte iInterface  ; iInterface
.endm

.macro .uac_if_out_desc bIntfNum bAltSetting iInterface bTerminal channels bits
.usb_if_desc bIntfNum bAltSetting 1 1 2 0 iInterface
.equ FREQ, 48000
.equ BYTES, (bits / 8 * channels)
.equ PACKET_SIZE, (FREQ / 1000 * BYTES)
.iflt EP1_BYTES - PACKET_SIZE
.error 1; Buffer too small
.endif

.byte 7, AUDIOSTREAMING_INTERFACE_DESCRIPTOR
.byte UAC_AS_GENERAL
.byte bTerminal ; bTerminalLink           1
.byte 0 ; bDelay                  0 frames
usb_word 0x0001 ; wFormatTag         0x0001 PCM

.byte 11, AUDIOSTREAMING_INTERFACE_DESCRIPTOR
.byte UAC_AS_FORMAT_TYPE    ; bDescriptorSubtype
.byte UAC_AS_FORMAT_TYPE_I  ; bFormatType
.byte channels  ; bNrChannels             2
.byte ((bits + 7) / 8)  ; bSubframeSize           2
.byte bits ; bBitResolution         16
.byte 1  ;  bSamFreqType           1 discrete entry
usb_ac_freq FREQ

.byte 9, ENDPOINT_DESCRIPTOR
.byte 0x01 ; bEndpointAddress     0x01  EP 1 OUT
.byte 0xd ; bmAttributes
;          Transfer Type            Isochronous
;          Synch Type               Synchronous
;          Usage Type               Data
usb_word PACKET_SIZE
.byte 1 ; bInterval               1
.byte 0 ; bRefresh                0
.byte 0 ; bSynchAddress           0

.byte 7, AUDIOSTREAMING_ENDPOINT_DESCRIPTOR
.byte 1 ; bDescriptorSubtype      1 (EP_GENERAL)
.byte 0 ; bmAttributes         0x01 (Support sampling frequency control)
.byte 0 ; bLockDelayUnits         0 Undefined
usb_word 0 ; wLockDelay         0x0000
.endm

.macro .uac_if_in_desc bIntfNum bAltSetting iInterface bTerminal channels bits
.usb_if_desc bIntfNum bAltSetting 1 1 2 0 iInterface
.equ FREQ, 48000
.equ BYTES, (bits / 8 * channels)
.equ PACKET_SIZE, (FREQ / 1000 * BYTES)
.iflt EP2_BYTES - PACKET_SIZE
.error 1; Buffer too small
.endif

.byte 7, AUDIOSTREAMING_INTERFACE_DESCRIPTOR
.byte UAC_AS_GENERAL
.byte bTerminal ; bTerminalLink           1
.byte 0 ; bDelay                  0 frames
usb_word 0x0001 ; wFormatTag         0x0001 PCM

.byte 11, AUDIOSTREAMING_INTERFACE_DESCRIPTOR
.byte UAC_AS_FORMAT_TYPE    ; bDescriptorSubtype
.byte UAC_AS_FORMAT_TYPE_I  ; bFormatType
.byte channels  ; bNrChannels             2
.byte ((bits + 7) / 8)  ; bSubframeSize           2
.byte bits ; bBitResolution         16
.byte 1  ;  bSamFreqType           1 discrete entry
usb_ac_freq FREQ

.byte 9, ENDPOINT_DESCRIPTOR
.byte 0x82 ; bEndpointAddress     0x82  EP 2 IN
.byte 0xd ; bmAttributes
;          Transfer Type            Isochronous
;          Synch Type               Synchronous
;          Usage Type               Data
usb_word PACKET_SIZE
.byte 1 ; bInterval               1
.byte 0 ; bRefresh                0
.byte 0 ; bSynchAddress           0


.byte 7, AUDIOSTREAMING_ENDPOINT_DESCRIPTOR
.byte 1 ; bDescriptorSubtype      1 (EP_GENERAL)
.byte 0 ; bmAttributes         0x01 (Support sampling frequency control)
.byte 0 ; bLockDelayUnits         0 Undefined
usb_word 0 ; wLockDelay         0x0000
.endm

.macro .my_if1_desc
; IF 1 Altsetting 0: Streaming off
.usb_if_desc     1 0 0 1 2 0 0
; Altsetting 1: 16bit stereo @ 48kHz
.uac_if_out_desc 1 1 0 1 2 16
; Altsetting 2: 16bit 4ch @ 48kHz
.uac_if_out_desc 1 2 0 1 4 16
; Altsetting 3: 24bit stereo @ 48kHz
.uac_if_out_desc 1 3 0 1 2 24
; Altsetting 4: 24bit 4ch @ 48kHz
.uac_if_out_desc 1 4 0 1 4 24
.endm

.my_if1_desc

.macro .my_if2_desc
; IF 2 Altsetting 0: Streaming off
.usb_if_desc     2 0 0 1 2 0 0
; Altsetting 1: 16bit stereo @ 48kHz
.uac_if_in_desc 2 1 0 1 2 16
; Altsetting 2: 24bit stereo @ 48kHz
.uac_if_in_desc 2 2 0 1 2 24
.endm

.my_if2_desc

.macro .my_if3_desc
; IF 3 Altsetting 0: Vendor control, no EPs
.usb_if_desc     3 0 0 0xff 0xff 0xff 0
.endm

.my_if3_desc

usb_cnf_end:
.equ usb_cnf_len, (usb_cnf_end - usb_cnf_desc)

uac_volume_res:
.byte 0x00, 0x01

uac_volume_min:
.byte 0x00, 0x81

uac_volume_max:
usb_status_ok:
.byte 0x00, 0x00

usb_string_lang:
.byte 4, 3, 9, 4

usb_string usb_s_mfg "Saffire\0406\040USB"

message_hello:
.ascii "\r\nHello world!\r\n\0"
message_rst:
.ascii "\r\nR\0"


sum 0 5

.word usb_cnf_len

infobytes:
.word EP1_OUTX
.word EP1_OUTY
.word EP2_INX
.word EP2_INY
.byte #envMaxL
.byte #envMaxR
