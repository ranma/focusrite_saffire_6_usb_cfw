.equ GLOBCTL, 0xffb1
.equ OEPINT, 0xffb4
.equ IEPINT, 0xffb3
.equ VECINT, 0xffb2
.equ ORIG_START, 0x0cf5
.equ IEPCNF0,   0xff68
.equ IEPDCNTX0, 0xff6b
.equ OEPCNF0,   0xffa8
.equ OEPDCNTX0, 0xffab
.equ SETUP_PKT, 0xff28
.equ MEMCFG,    0xffb0
.equ USBFADR,   0xffff
.equ USBIMSK,   0xfffd

.equ ROP_MOVX_DPTR_A, 0x8084 ; 0x8084  movx @DPTR, A
.equ ROP_POP_DPL_DPH_B_ACC, 0x80da ; 0x80da  pop DPL; pop DPH; pop B; pop ACC
.equ RESET_TO_PAYLOAD, 0x8a95 ; reset state and jump to payload (0)
.equ RESET_TO_BOOTLOADER, 0x8ad9 ; reset state and jump to payload (0)
; reg 0xffb0 MEMCFG; write 0 to enable code ram writes, 1 to enable code execution

.equ DATA_TEST, 0x1234

.equ EP0_BYTES,  8
.equ EP0_IN_SIZ,    ((EP0_BYTES + 7) / 8)
.equ EP0_IN,        (SETUP_PKT - (8 * EP0_IN_SIZ))
.equ EP0_OUT_SIZ,   ((EP0_BYTES + 7) / 8)
.equ EP0_OUT,       (EP0_IN - (8 * EP0_OUT_SIZ))
.equ EP0_IN_BBAX,   ((EP0_IN / 8) & 0xff)
.equ EP0_OUT_BBAX,  ((EP0_OUT / 8) & 0xff)

.iflt EP0_IN - 0xff00
.error 1; EP0 buffer start out of range
.endif

.iflt EP0_OUT - 0xff00
.error 1; EP0 buffer start out of range
.endif

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

.macro rop_movx_dptr_a
	.byte (ROP_MOVX_DPTR_A & 0xff)
	.byte (ROP_MOVX_DPTR_A >> 8)
.endm

.macro rop_set_dptr_and_a dptr_val a_val
	.byte a_val
	.byte 0 ; unused B
	.byte (dptr_val >> 8)    ; DPH
	.byte (dptr_val & 0xff)  ; DPL
	.byte (ROP_POP_DPL_DPH_B_ACC & 0xff)
	.byte (ROP_POP_DPL_DPH_B_ACC >> 8)
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
.equ usbStateSetupValid, 0
.equ usbStateSetAddress, 1
.equ usbStateAddressValid, 2
.equ usbStateIn0Done, 3
.equ usbStateZeroPad, 4
.equ usbStateStringCnt, 5
.equ usbState6, 6
.equ usbState7, 7
miscState: .ds 1
.equ uartEmpty, 8

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

txPtrLo:  .ds 1
txPtrHi:  .ds 1
txSize:   .ds 1

uartReadPtr:   .ds 1
uartWritePtr:  .ds 1

rop_stack_ret_addr: .ds 2
rop_stack_template: .ds (rop_template_end - rop_template)
rop_stack_end:

.area CSEG (CODE,ABS)
_reset: ljmp _start
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

	mov DPTR, #rop_template
	mov R0, #rop_stack_template
	mov R1, #(rop_template_end - rop_template)
rop_stack_copy:
	acall fetchc_postinc
	mov @R0, A
	inc R0
	djnz R1, rop_stack_copy

	mov DPTR, #message_hello
	acall serial_puts

wait_uart_finished:
	jnb uartEmpty, wait_uart_finished

	mov DPTR, #DATA_TEST
	mov A, #0xa5
	acall code_poke
	mov DPTR, #DATA_TEST
	clr A
	movc A, @A+DPTR
	acall serial_hex

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

vec_dispatch:
	acall dispatch
	.byte (0x08 ^ 0x24)
	dispatch_address vec_in_ep0
	.byte (0x00 ^ 0x24)
	dispatch_address vec_out_ep0
	.byte (0x17 ^ 0x24)
	dispatch_address vec_reset
	.byte (0x12 ^ 0x24)
	dispatch_address vec_setup
	.byte 0
	dispatch_address vec_default

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
	ret

fetchc_postinc:
	clr A
	movc A, @A+DPTR
	inc DPTR
	ret

vec_setup:
	mov A, #' '
	acall serial_write
	mov A, #'S'
	acall serial_write

	; Unstall endpoints
	mov A, #0xa4  ; Unstall in EP0
	mov R0, #IEPCNF0
	movx @R0, A
	mov R0, #OEPCNF0  ; Unstall out EP0
	movx @R0, A   ; NACK IN/OUT
	mov A, #0x80
	mov R0, #IEPDCNTX0
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A

	mov txSize, #0
	clr usbStateIn0Done
	clr usbStateZeroPad
	setb usbStateSetupValid

	mov R1, #SETUP_PKT
	mov R0, #bmRequestType
	mov R2, #8
copy_setup_pkt:
	movx A, @R1
	mov @R0, A
	inc R1
	inc R0
	djnz R2, copy_setup_pkt

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

	jb usbStateSetupValid, setup_exit
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
	setup_entry 0x40 0x85 setup_dth_vend_reboot_bootloader
	setup_entry 0xc0 0x90 setup_dth_vend_read_xram
	setup_entry 0x40 0x91 setup_dth_vend_write_xram
	setup_entry 0xc0 0x92 setup_dth_vend_read_i2c
	setup_entry 0xc0 0x94 setup_dth_vend_read_code
	setup_entry 0x40 0x95 setup_dth_vend_write_code
	setup_entry 0xc0 0x96 setup_dth_vend_read_iram
	setup_entry 0x40 0x97 setup_dth_vend_write_iram
	setup_entry 0xc0 0x98 setup_dth_vend_read_sfr
	setup_entry 0x00 5 setup_htd_dev_set_address
	setup_entry 0x00 9 setup_htd_dev_set_configuration
	.byte 0xff, 0xff

setup_dth_dev_get_status:
	mov DPTR, #usb_status_ok
	mov txSize, #2
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	acall write_to_ep0
	ret

setup_dth_vend_reboot_bootloader:
	clr A
	mov IE, A
	mov R0, #0xfc
	movx @R0, A
	inc R0
	movx @R0, A
	inc R0
	movx @R0, A
	inc R0
	movx @R0, A
	ljmp RESET_TO_BOOTLOADER

setup_dth_vend_write_iram:
	mov DPTR, #(write_sfr_patch_op + 1)
	mov A, wIndexLo
	acall code_poke
write_sfr_patch_op:
	mov A, wValueLo
	mov 0, A
	sjmp vend_finish_byte_write

setup_dth_vend_write_sfr:
	mov R0, wIndexLo
	mov A, wValueLo
	mov @R0, A
	sjmp vend_finish_byte_write

setup_dth_vend_write_code:
	mov DPL, wIndexLo
	mov DPH, wIndexHi
	mov A, wValueLo
	acall code_poke
	sjmp vend_finish_byte_write

setup_dth_vend_write_xram:
	mov DPL, wIndexLo
	mov DPH, wIndexHi
	mov A, wValueLo
	movx @DPTR, A

vend_finish_byte_write:
	clr A
	mov R0, #IEPDCNTX0
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A
	ret

setup_dth_vend_read_i2c:

setup_dth_vend_read_iram:
	mov R0, wIndexLo
	clr A
	mov A, @R0
	sjmp vend_finish_byte_read

setup_dth_vend_read_sfr:
	mov DPTR, #(read_sfr_patch_op + 1)
	mov A, wIndexLo
	acall code_poke
read_sfr_patch_op:
	mov A, 0
	sjmp vend_finish_byte_read

setup_dth_vend_read_code:
	mov DPL, wIndexLo
	mov DPH, wIndexHi
	clr A
	movc A, @A+DPTR
	sjmp vend_finish_byte_read

setup_dth_vend_read_xram:
	mov DPL, wIndexLo
	mov DPH, wIndexHi
	movx A, @DPTR

vend_finish_byte_read:
	mov R0, #EP0_IN
	movx @R0, A
	clr A
	mov R0, #OEPDCNTX0
	movx @R0, A
	inc A
	mov R0, #IEPDCNTX0
	movx @R0, A
	setb usbStateIn0Done
	ret

setup_dth_dev_get_descriptor:
	mov A, wValueHi
	acall dispatch
	dispatch_entry 3 setup_dth_get_desc_string
	dispatch_entry 2 setup_dth_get_desc_configuration
	dispatch_entry 1 setup_dth_get_desc_device
	dispatch_entry 0 setup_dth_get_desc_bad

clamp_size:
	mov A, wLengthHi
	jnz clamp_size_exit
	mov A, wLengthLo
	clr C
	subb A, txSize
	jnc clamp_size_exit
	mov txSize, wLengthLo
clamp_size_exit:
	ret

setup_dth_get_desc_device:
	mov DPTR, #usb_dev_desc
	mov txSize, #0x12
setup_dth_get_desc:
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	acall clamp_size

	acall write_to_ep0
	ret

setup_dth_get_desc_configuration:
	mov DPTR, #usb_cnf_desc
	mov txSize, #18
	sjmp setup_dth_get_desc

setup_dth_get_desc_string:
	mov A, wValueLo
	cjne A, #0, not_string_0
	mov DPTR, #usb_string_lang
	mov txSize, #4
	mov txPtrHi, DPH
	mov txPtrLo, DPL
	sjmp string_write
not_string_0:
	setb usbStateZeroPad
	setb usbStateStringCnt
	mov DPTR, #usb_string_mfg
	mov txSize, #2
	mov txPtrHi, DPH
	mov txPtrLo, DPL
string_count_size:
	clr A
	movc A, @A+DPTR
	jz string_write
	inc txSize
	inc txSize
	inc DPTR
	sjmp string_count_size
	
string_write:
	acall write_to_ep0
	ret

setup_dth_get_desc_bad:
	mov A, #'d'
	acall serial_write
	mov A, wValueHi
	acall serial_hex
	mov A, wValueLo
	acall serial_hex
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
	clr A
	mov R0, #IEPDCNTX0
	movx @R0, A
	mov R0, #OEPDCNTX0
	movx @R0, A
	mov A, #'c'
	acall serial_write

	; Turn on power
	clr P1.6

	ret

setup_default:
	clr usbStateSetupValid
	mov A, bmRequestType
	acall serial_hex
	mov A, bRequest
	acall serial_hex
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

write_to_ep0:
	mov A, #'w'
	jnb usbStateAddressValid, write_to_ep0_addr_not_set
	mov A, #'W'
write_to_ep0_addr_not_set:
	acall serial_write

	mov DPH, txPtrHi
	mov DPL, txPtrLo
	mov A, txSize
	mov R1, A
	jz write_empty_to_ep0
	mov A, #EP0_BYTES   ; Clamp size
	clr C
	subb A, txSize
	mov R2, txSize
	jnc write_to_ep0_copy
	mov R2, #EP0_BYTES

write_to_ep0_copy:
	mov R1, AR2
	mov R0, #EP0_IN
	jnb usbStateStringCnt, desc_copy_loop
	clr usbStateStringCnt
	mov A, txSize
	movx @R0, A
	inc R0
	dec R2
	dec txSize
	mov A, #3
	movx @R0, A
	inc R0
	dec R2
	dec txSize
desc_copy_loop:
	acall fetchc_postinc
	movx @R0, A
	inc R0
	dec txSize
	jnb usbStateZeroPad, desc_copy_no_zeropad
	dec R2
	clr A
	movx @R0, A
	inc R0
	dec txSize
desc_copy_no_zeropad:
	djnz R2, desc_copy_loop

	mov txPtrHi, DPH
	mov txPtrLo, DPL

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

usb_init:
	mov usbState, #0

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
	push AR2
	mov R2, A
	swap A
	acall serial_hex_nibble
	mov A, R2
	pop AR2
	; fall through to serial_hex_nibble

serial_hex_nibble:
	anl A, #0xf
	clr C
	subb A, #0xa
	jc serial_hex_digit
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

code_poke:
	mov R0, #(rop_stack_end - 3)
	mov @R0, DPL
	dec R0
	mov @R0, DPH
	dec R0
	dec R0
	mov @R0, A
	push IE
	mov IE, #0 ; disable interrupts

	mov R7, SP
	mov SP, #(rop_stack_ret_addr - 1)
	acall do_code_poke
	mov SP, R7

	pop IE
	ret

do_code_poke:
	mov SP, #(rop_stack_end - 1)
	mov DPTR, #MEMCFG
	clr A  ; Map coderam as XRAM (and unshadow the bootrom)
	ljmp ROP_MOVX_DPTR_A

rop_template:
	; 0
	rop_movx_dptr_a
	; 2
	rop_set_dptr_and_a MEMCFG 0x01

	; 8
	rop_movx_dptr_a
	; 10
	rop_set_dptr_and_a DATA_TEST 0x5a
	; 16
rop_template_end:

usb_init_data:
.byte 0x68, 0x8c  ; IEPCNF0 = 0x8c (Enable EP & irq, stalled)
.byte 0x69, EP0_IN_BBAX  ; IEPBBAX0 = 0xe4 (=> 0xff20)
.byte 0x6a, EP0_IN_SIZ  ; IEPBSIZ0 = 0x01 (8 bytes)
.byte 0xa8, 0x8c  ; OEPCNF0 = 0x8c
.byte 0xa9, EP0_OUT_BBAX ; OEPBBAX0 = 0xe3 (=> 0xff18)
.byte 0xaa, EP0_OUT_SIZ  ; OEPBSIZ0 = 0x01 (8 bytes)
.byte 0xff, 0x00  ; USBFADDR = 0x00
.byte 0xfe, 0x00  ; USBSTA = 0x00
.byte 0xfd, 0x84  ; USBIMSK = 0x84 (reset & setup irqs enabled)
.byte 0xfc, 0xc0  ; USBCTL = 0xc0 (enable pull-up and hw)
.byte 0x00

usb_dev_desc:
.byte 0x12, 0x01  ; Size, type (device)
.byte 0x10, 0x01  ; USB Version (1.10)
.byte 0xff, 0, 0  ; Class/Subclass/Protocol
.byte EP0_BYTES   ; EP0 max packet size
.byte 0x51, 0x04  ; Vendor 0x0451
.byte 0x01, 0x32  ; Id 0x3201
.byte 0x00, 0x01  ; Device version (1.0)
.byte 1           ; iManufacturer
.byte 0           ; iProduct
.byte 0           ; iSerial
.byte 1           ; Number of configurations

usb_cnf_desc:
.byte 0x09, 0x02  ; Size, type (config)
.byte 18, 0       ; Total length
.byte 1           ; bNumInterfaces
.byte 1           ; bConfigurationValue
.byte 0           ; iConfiguration
.byte 0x80        ; bmAttributes (bus powered)
.byte 498/2       ; bMaxPower (498mA)
.byte 0x09, 0x04  ; Size, type (interface)
.byte 0           ; bInterfacenNmber
.byte 0           ; bAlternateSetting
.byte 0           ; bNumEndpoints
.byte 0xff, 0, 0  ; Class/Subclass/Protocol
.byte 0           ; iInterface

usb_status_ok:
.byte 0, 0

usb_string_lang:
.byte 4, 3, 9, 4
usb_string_mfg:
.ascii "ranma\0"

message_hello:
.ascii "\r\nHello world!\r\n\0"
message_rst:
.ascii "\r\nR\0"
