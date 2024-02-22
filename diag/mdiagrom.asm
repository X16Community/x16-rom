.segment "DIAG"

.include "cx16.inc"
.include "vera0.9.inc"
.include "i2c.inc"
.include "macros.inc"

charset_addr		= $1F000
screen_addr		= $1B000
VERA_PALETTE_BASE	= $1FA00

ONESEC			= $1900
ZP_START_OFFSET		= $02
START_OFFSET		= $00
END_OFFSET		= $FF

TESTUP			= 0
TESTDOWN		= 1
TESTONLY		= 2
MAX_ERR_X		= $80
MAX_ERR_Y		= $B0+48

str_ptr			= r0
mem_ptr			= r1
num			= r2
numbanks		= r4l
num_x			= r4h
x_cord			= r5l
y_cord			= r5h
err_x			= r6l
err_y			= r6h

err_pattern		= r7l
err_low_addr		= r7h
err_test_type		= r8l

pass_num		= r9

col			= r10l

start:
	sei	; Disable interrupts, we don't have anything handling them
	jmp	basemem_test
basemem_ret:
	ldx	#$FF		; Set stack pointer
	txs

	jsr	vera_init	; Initialize VERA
	lda	#$11		; Set increment=1 and bank=1

	lda	#$B0+41		; Initialize X and Y coordinates for err msgs
	sta	err_y
	stz	err_x

	stz	pass_num	; Initialize pass_num variable to 0
	stz	pass_num+1

	lda	#((BLUE<<4)|WHITE);Initialize standard color
	sta	col

	lda	#0		; Turn all keyboard LEDs off
	jsr	kbdwrite

	GOTOXY #6, #1
	PRINTSTR header
	GOTOXY #5, #2
	PRINTSTR line
	GOTOXY #1, #4
	PRINTSTR first_ok
	GOTOXY #1, #6
	PRINTSTR find_banks
	jsr	detectbanks
	sta	numbanks
	jsr	byte2hex
	PRINTSTR num

test_start:
	ldx	#26
	stx	num_x
	lda	#1
	jsr	kbdwrite
	;00000000
	GOTOXY #1, #8
	PRINTSTR fill_pattern
	PRINTSTR first_pattern
	lda	#%00000000
	jsr	fillbanks

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR first_pattern
	lda	#%00000000
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR first_invert
	lda	#%11111111
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR first_pattern
	lda	#%00000000
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR first_invert
	lda	#%11111111
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_final
	PRINTSTR first_pattern
	lda	#%00000000
	jsr	testbanks

	lda	#2
	jsr	kbdwrite
	;01010101
	inc	y_cord
	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR fill_pattern
	PRINTSTR second_pattern
	lda	#%01010101
	jsr	fillbanks

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR second_pattern
	lda	#%01010101
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR second_invert
	lda	#%10101010
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR second_pattern
	lda	#%01010101
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR second_invert
	lda	#%10101010
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_final
	PRINTSTR second_pattern
	lda	#%01010101
	jsr	testbanks

	lda	#3
	jsr	kbdwrite
	;00110011
	inc	y_cord
	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR fill_pattern
	PRINTSTR third_pattern
	lda	#%00110011
	jsr	fillbanks

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR third_pattern
	lda	#%00110011
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR third_invert
	lda	#%11001100
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR third_pattern
	lda	#%00110011
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR third_invert
	lda	#%11001100
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_final
	PRINTSTR third_pattern
	lda	#%00110011
	jsr	testbanks

	lda	#4
	jsr	kbdwrite
	;00001111
	inc	y_cord
	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR fill_pattern
	PRINTSTR fourth_pattern
	lda	#%00001111
	jsr	fillbanks

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR fourth_pattern
	lda	#%00001111
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up
	PRINTSTR fourth_invert
	lda	#%11110000
	jsr	up_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR fourth_pattern
	lda	#%00001111
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn
	PRINTSTR fourth_invert
	lda	#%11110000
	jsr	down_test

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_final
	PRINTSTR fourth_pattern
	lda	#%00001111
	jsr	testbanks

	lda	#5
	jsr	kbdwrite
	inc	y_cord
	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR low_ram
	PRINTSTR first_pattern
	lda	#$2F		; /
	sta	VERA_DATA0
	inc	VERA_ADDR_L
	PRINTSTR first_invert
	lda	#%00000000
	jsr	testbase

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR low_ram
	PRINTSTR second_pattern
	lda	#$2F		; /
	sta	VERA_DATA0
	inc	VERA_ADDR_L
	PRINTSTR second_pattern
	lda	#%01010101
	jsr	testbase

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR low_ram
	PRINTSTR third_pattern
	lda	#$2F		; /
	sta	VERA_DATA0
	inc	VERA_ADDR_L
	PRINTSTR third_invert
	lda	#%00110011
	jsr	testbase

	inc	y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR low_ram
	PRINTSTR fourth_pattern
	lda	#$2F		; /
	sta	VERA_DATA0
	inc	VERA_ADDR_L
	PRINTSTR fourth_invert
	lda	#%00001111
	jsr	testbase

	lda	#7
	jsr	kbdwrite
	jsr	show_pass_done

	inc	pass_num
	bne	:+
	inc	pass_num+1
:	GOTOXY	#58, #4
	lda	pass_num+1
	jsr	byte2hex
	PRINTSTR num
	lda	pass_num
	jsr	byte2hex
	PRINTSTR num

	; Clear test pattern information from screen
	stz	VERA_ADDR_L
	lda	#$B7
	sta	VERA_ADDR_M
	ldx	#65
	ldy	#33
	jsr	clrscr

	; Switch between VGA and Composite/S-Video output
	lda	VERA_DC_VIDEO
	eor	#$03
	sta	VERA_DC_VIDEO

	jmp	test_start

; .A = code to show on LEDs in binary
kbdwrite:
	pha
	I2C_WRITE_FIRST_BYTE I2C_KBD_VAL, I2C_SMC, I2C_KBD_CMD2
	plx
	lda	kbd_bin_tbl,x
	I2C_WRITE
	I2C_STOP
	rts

show_pass_done:
	ldx	#5
	lda	#$FF
:	phx
	pha
	ldx	#I2C_SMC
	ldy	#SMC_activity_led
	jsr	i2c_write_b
	jsr	delayone
	pla
	eor	#$FF
	plx
	dex
	bne	:-
	; Turn Activity light off
	lda	#$00
	ldx	#I2C_SMC
	ldy	#SMC_activity_led
	jsr	i2c_write_b
	rts

delayone:
	DELAY ONESEC
	rts

; .Y = low order address
; mem_ptr+1 = high order address
; .A = pattern
; .X = test type - 0=up, 1=down, 2=testonly
; RAM_BANK = current RAM bank
handle_error:
	sta	err_pattern		; Save Registers
	sty	err_low_addr
	stx	err_test_type

	lda	err_y			; Set VERA address (GOTOXY)
	sta	VERA_ADDR_M
	lda	err_x
	sta	VERA_ADDR_L
	PRINTSTR err_str, ((BLACK<<4)|WHITE); Print the beginning of Error string
	lda	mem_ptr+1
	cmp	#>RAM_BANK_START	; Is address >= RAM_BANK_START
	bcs	@rambank
	; Here the address is not in BANKED memory
	PRINTSTR err_no_bank, ((BLACK<<4)|WHITE)
	bra	@do_address
@rambank:
	lda	RAM_BANK
	jsr	byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
	lda	#$3A			; :
	sta	VERA_DATA0
	stx	VERA_DATA0
@do_address:
	lda	#$24			; $
	sta	VERA_DATA0
	stx	VERA_DATA0
	lda	mem_ptr+1
	jsr	byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
	lda	err_low_addr
	jsr	byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)

	lda	err_test_type		; switch (err_test_type)
@up:	bne	@down			; case UP
	PRINTSTR err_up, ((BLACK<<4)|WHITE)
	bra	@endswitch
@down:	cmp	#TESTDOWN		; case DOWN
	bne	@test
	PRINTSTR err_dn, ((BLACK<<4)|WHITE)
	bra	@endswitch
@test:	PRINTSTR err_to, ((BLACK<<4)|WHITE); case TESTONLY
@endswitch:
	lda	err_pattern
	jsr	byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
	lda	#$20			; space
	sta	VERA_DATA0
	stx	VERA_DATA0

	; Error has been written, now we need to figure out if the maximum
	; number of errors have been displayed.
	lda	VERA_ADDR_L
	sta	err_x
	cmp	#MAX_ERR_X		; If we have reached max X coordinate 
	bne	@end			; we need to go to next line

	stz	err_x			; Reset X coordinate
	lda	err_y			
	cmp	#MAX_ERR_Y		; If we have reached max Y coordinate
	bne	:+			; we inform about max reached and
	jsr	print_test_stop
	jmp	catastrophic_error	; Show error in activity LED as well
:	inc				; Go to next line
	sta	err_y
@end:	lda	err_pattern		; Restore Registers
	ldy	err_low_addr		; X register restored by caller
	rts

print_test_stop:
	GOTOXY #12, #49
	PRINTSTR test_stop, ((BLACK<<4)|RED)
	rts

fillpages:
	ldx	#<$0200		; Store initial base address to ZP
	stx	mem_ptr
	ldx	#>$0200
	stx	mem_ptr+1
@memloop:
	pha			; Save pattern
	txa			; Write current page to screen
	jsr	printnum
	pla			; Restore pattern
	ldx	mem_ptr+1		; Restore bank in .X
	ldy	#0
@pageloop:
	sta	(mem_ptr),y		; Write pattern to an entire page
	iny
	bne	@pageloop
	inx			; Go to next page
	cpx	#$9F		; If we have reached page $9F, we are done
	beq	:+
	stx	mem_ptr+1		; Save new page
	bra	@memloop
:	rts

page_up:
	ldx	#<$0200		; Store initial base address to ZP
	stx	mem_ptr
	ldx	#>$0200
	stx	mem_ptr+1
@memloop:
	pha			; Save pattern
	txa			; Write current page to screen
	jsr	printnum
	pla			; Restore pattern
	ldx	mem_ptr+1		; Restore bank in .X
	ldy	#0
@pageloop:
	cmp	(mem_ptr),y		; Write pattern to an entire page
	beq	:+
	ldx	#TESTUP
	jsr	handle_error
	ldx	mem_ptr+1
:	eor	#$FF
	sta	(mem_ptr),y
	eor	#$FF
	iny
	bne	@pageloop
	inx			; Go to next page
	cpx	#$9F		; If we have reached page $9F, we are done
	beq	:+
	stx	mem_ptr+1		; Save new page
	bra	@memloop
:	rts

page_down:
	ldx	#<$9E00
	stx	mem_ptr
	ldx	#>$9E00
	stx	mem_ptr+1
@memloop:
	pha			; Save pattern
	txa			; Write current page to screen
	jsr	printnum
	pla
	ldx	mem_ptr+1
	ldy	#0
@pageloop:
	dey			; Write pattern to entire page
	cmp	(mem_ptr),y
	beq	:+
	ldx	#TESTDOWN
	jsr	handle_error
	ldx	mem_ptr+1
:	eor	#$FF
	sta	(mem_ptr),y
	eor	#$FF
	dey
	bne	@pageloop
	dex
	cpx	#$01
	beq	:+
	stx	mem_ptr+1
	bra	@memloop
:	rts

testpages:
	ldx	#<$0200		; Store initial base address to ZP
	stx	mem_ptr
	ldx	#>$0200
	stx	mem_ptr+1
@memloop:
	pha			; Save pattern
	txa			; Write current page to screen
	jsr	printnum
	pla			; Restore pattern
	ldx	mem_ptr+1		; Restore bank in .X
	ldy	#0
@pageloop:
	cmp	(mem_ptr),y		; Write pattern to an entire page
	beq	:+
	ldx	#TESTONLY
	jsr	handle_error
	ldx	mem_ptr+1
:	iny
	bne	@pageloop
	inx			; Go to next page
	cpx	#$9F		; If we have reached page $9F, we are done
	beq	:+
	stx	mem_ptr+1		; Save new page
	bra	@memloop
:	rts
	
testbase:
	jsr	fillpages
	jsr	page_up
	eor	#$FF
	jsr	page_up
	eor	#$FF
	jsr	page_down
	eor	#$FF
	jsr	page_down
	eor	#$FF
	jsr	testpages
	rts

fillbanks:
	stz	RAM_BANK
	ldx	#<RAM_BANK_START
	stx	mem_ptr
@memloop:
	ldx	#>RAM_BANK_START
	stx	mem_ptr+1
	ldy	#0
@pageloop:
	sta	(mem_ptr),y
	iny
	bne	@pageloop
	inx
	stx	mem_ptr+1
	cpx	#>(RAM_BANK_START+RAM_BANK_SIZE)
	bne	@pageloop
	ldy	RAM_BANK
	cpy	numbanks
	beq	:+
	iny
	sty	RAM_BANK
	pha
	tya
	jsr	printnum
	pla
	bra	@memloop
:	rts

up_test:
	stz	RAM_BANK
	ldx	#<RAM_BANK_START
	stx	mem_ptr
@memloop:
	ldx	#>RAM_BANK_START
	stx	mem_ptr+1
	ldy	#0
@pageloop:
	cmp	(mem_ptr),y
	beq	:+
	ldx	#TESTUP
	jsr	handle_error
	ldx	mem_ptr+1
:	eor	#$FF
	sta	(mem_ptr),y
	eor	#$FF
	iny
	bne	@pageloop
	inx
	stx	mem_ptr+1
	cpx	#>(RAM_BANK_START+RAM_BANK_SIZE)
	bne	@pageloop
	ldy	RAM_BANK
	cpy	numbanks
	beq	:+
	iny
	sty	RAM_BANK
	pha
	tya
	jsr	printnum
	pla
	bra	@memloop
:	rts

down_test:
	pha
	lda	numbanks
	sta	RAM_BANK
	jsr	printnum
	pla
	ldx	#<(RAM_BANK_START+RAM_BANK_SIZE)
	stx	mem_ptr
@memloop:
	ldx	#>(RAM_BANK_START+RAM_BANK_SIZE)-1
	stx	mem_ptr+1
	ldy	#0
@pageloop:
	dey
	cmp	(mem_ptr),y
	beq	:+
	ldx	#TESTDOWN
	jsr	handle_error
	ldx	mem_ptr+1
:	eor	#$FF
	sta	(mem_ptr),y
	eor	#$FF
	cpy	#0
	bne	@pageloop
	dex
	stx	mem_ptr+1
	cpx	#>RAM_BANK_START-1
	bne	@pageloop
	ldy	RAM_BANK
	cpy	#0
	beq	:+
	dey
	sty	RAM_BANK
	pha
	tya
	jsr	printnum
	pla
	bra	@memloop
:	rts

testbanks:
	stz	RAM_BANK
	ldx	#<RAM_BANK_START
	stx	mem_ptr
@memloop:
	ldx	#>RAM_BANK_START
	stx	mem_ptr+1
	ldy	#0
@pageloop:
	cmp	(mem_ptr),y
	beq	:+
	ldx	#TESTONLY
	jsr	handle_error
	ldx	mem_ptr+1
:	iny
	bne	@pageloop
	inx
	stx	mem_ptr+1
	cpx	#>(RAM_BANK_START+RAM_BANK_SIZE)
	bne	@pageloop
	ldy	RAM_BANK
	cpy	numbanks
	beq	:+
	iny
	sty	RAM_BANK
	pha
	tya
	jsr	printnum
	pla
	bra	@memloop
:	rts
	
byte2hex:
	ldy	#0
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda	hex_table,x
	jsr	@add_hex
	pla
	and	#$0F
	tax
	lda	hex_table,x
@add_hex:
	sta	num,y
	iny
	lda	#0
	sta	num,y
	rts

printnum:
	jsr	byte2hex
	GOTOXY num_x, y_cord
	PRINTSTR num
	rts

detectbanks:
;
; detect number of RAM banks
; 
	stz	RAM_BANK
	lda	RAM_BANK_START	;get value from 00:a000
	eor	#$FF		;use inverted value as test value for other banks
	tax

	ldy	#1		;bank to test
:	sty 	RAM_BANK
	lda	RAM_BANK_START	;save current value
	stx	RAM_BANK_START	;write test value
	stz	RAM_BANK
	cpx	RAM_BANK_START	;check if 00:a000 is affected = wrap-around
	beq	@memtest2
	sty	RAM_BANK
	sta	RAM_BANK_START	;restore value
	iny			;next bank
	bne	:-

@memtest2:
	stz	RAM_BANK	;restore value in 00:a000
	txa
	eor	#$FF
	sta	RAM_BANK_START

	ldx #1			;start testing from bank 1
	stx	RAM_BANK
:	ldx	#8		;test 8 addresses in each bank
:	lda	RAM_BANK_START,x;read, xor, write, compare
	eor	#$FF
	sta	RAM_BANK_START,x
	cmp	RAM_BANK_START,x
	bne	@test_done	;test failed, we are done
	eor	#$FF		;restore value
	sta	RAM_BANK_START,x
	dex			;test next address
	bne	:-
	inc	RAM_BANK	;select next ank
	cpy	RAM_BANK	;stop at last bank that does not wrap-around to bank0
	bne	:--
@test_done:
	lda	RAM_BANK	;number of RAM banks
	dec
	rts

gotoxy:
	txa
	asl
	sta	VERA_ADDR_L
	tya
	clc
	adc	#$B0
	sta	VERA_ADDR_M
	rts

printstr:
	ldy	#0			; Use .Y as index into string
@loop:	lda	(str_ptr),y
	beq	@end			; If it is 0, jump to end
	sta	VERA_DATA0		; Write character to VERA memory, VERA
	stx	VERA_DATA0		; Write color information
	iny				; Increment .Y
	bra	@loop			; Jump back to get next character
@end:	rts

;---------------------------------------------------------------
; Wait for VERA to be ready
;
; VERA's FPGA needs some time to configure itself. This function
; will see if the configuration is done by writing a VERA
; register and checking if the value is correctly written.
;---------------------------------------------------------------
vera_wait_ready:
	lda	#42
	sta	VERA_ADDR_L
	lda	VERA_ADDR_L
	cmp	#42
	bne	vera_wait_ready
	rts

upload_default_palette:
	stz	VERA_CTRL
	lda	#<VERA_PALETTE_BASE
	sta	VERA_ADDR_L
	lda	#>VERA_PALETTE_BASE
	sta	VERA_ADDR_M
	lda	#(^VERA_PALETTE_BASE) | $10
	sta	VERA_ADDR_H

	ldx #0
@loop1:
	lda default_palette,x
	sta VERA_DATA0
	inx
	bne @loop1
@loop2:
	lda default_palette+256,x
	sta VERA_DATA0
	inx
	bne @loop2
	rts

screen_set_charset:
	lda	#<charset_addr
	sta	VERA_ADDR_L
	lda	#>charset_addr
	sta	VERA_ADDR_M
	lda	#$10 | ^charset_addr
	sta	VERA_ADDR_H

	lda	#<charset
	sta	mem_ptr
	lda	#>charset
	sta	mem_ptr+1
	ldx	#8
	ldy	#0
:	lda	(mem_ptr),y
	sta	VERA_DATA0
	iny
	bne	:-
	inc	mem_ptr+1
	dex
	bne	:-
	rts

vera_init:
	jsr	vera_wait_ready
	lda	#1
	sta	VERA_IEN
	stz	VERA_CTRL
	jsr	screen_set_charset
	jsr	upload_default_palette

	; Layer 1 configuration
	lda	#%01100000		; Map Height = 01b = 64 tiles
	sta	VERA_L1_CONFIG		; Map Width  = 10b = 128 tiles
	lda	#(screen_addr>>9)
	sta	VERA_L1_MAPBASE
	lda	#((charset_addr>>11)<<2)
	sta	VERA_L1_TILEBASE
	stz	VERA_L1_HSCROLL_L
	stz	VERA_L1_HSCROLL_H
	stz	VERA_L1_VSCROLL_L
	stz	VERA_L1_VSCROLL_H
	; Display composer configuration 64x50
	lda	#2
	sta	VERA_CTRL
	; Set Mode 8 = 64x50
	lda	#$14
	sta	VERA_DC_VSTART
	lda	#$DC
	sta	VERA_DC_VSTOP
	lda	#$10
	sta	VERA_DC_HSTART
	lda	#$90
	sta	VERA_DC_HSTOP

	stz	VERA_CTRL
	lda	#$21			; Layer1 enabled, VGA output
	sta	VERA_DC_VIDEO
	lda	#128
	sta	VERA_DC_HSCALE
	sta	VERA_DC_VSCALE
	stz	VERA_DC_BORDER

	lda	#$11			; Increment=1, Bank=1
	sta	VERA_ADDR_H
	lda	#$B0			; Address of top left corner
	sta	VERA_ADDR_M
	stz	VERA_ADDR_L
	; Clear the screen with black background
	ldx	#80
	ldy	#60
	
clrscr:	phx
@loop:	lda	#$20			; Space character
	sta	VERA_DATA0
	lda	#((BLUE<<4)|WHITE)	; White on BLUE
	sta	VERA_DATA0
	dex
	bne	@loop
	plx
	inc	VERA_ADDR_M
	stz	VERA_ADDR_L
	dey
	bne	clrscr
	rts

;---------------------------------------------------------------
; i2c_write_byte
;
; Function: Write a byte value to an offset of an I2C device
;
; Pass:      a    value
;            x    7-bit device address
;            y    offset
;
; Return:    x    device (preserved)
;            y    offset (preserved)
;	     a	  value  (preserved)
;            c	  1 on error (NAK)
;---------------------------------------------------------------
i2c_write_b:
.scope
	phx			; Save register on stack
	phy
	pha
	pha			; Store value on stack
	phy			; Store offset on stack
	phx			; Store device address on stack
	I2C_INIT
	I2C_START
	pla			; address from stack 
	asl
	I2C_WRITE
	bcc	:+
	jmp	error
:	pla			; offset from stack
	I2C_WRITE
	pla			; value from stack
	I2C_WRITE
	I2C_STOP
	clc
	bra	end
error:	sec
	pla
	pla
end:	pla			; Restore registers from stack
	ply
	plx
	rts
.endscope

; !!!!!!!!!!!!!!!! NO STACK USAGE IN BELOW CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
basemem_test:
	; Turn Activity light on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	; Test zero-page
	FILLPAGE $0000, $00, $02
	TEST_PAGE_UP $0000, $00, $02, catastrophic_error
	TEST_PAGE_UP $0000, $FF, $02, catastrophic_error
	TEST_PAGE_DN $0000, $00, $FF, $02, catastrophic_error
	TEST_PAGE_DN $0000, $FF, $FF, $02, catastrophic_error
	TEST_PAGE $0000, $00, $02, catastrophic_error
	FILLPAGE $0000, $55, $02
	TEST_PAGE_UP $0000, $55, $02, catastrophic_error
	TEST_PAGE_UP $0000, $AA, $02, catastrophic_error
	TEST_PAGE_DN $0000, $55, $FF, $02, catastrophic_error
	TEST_PAGE_DN $0000, $AA, $FF, $02, catastrophic_error
	TEST_PAGE $0000, $55, $02, catastrophic_error
	FILLPAGE $0000, $33, $02
	TEST_PAGE_UP $0000, $33, $02, catastrophic_error
	TEST_PAGE_UP $0000, $CC, $02, catastrophic_error
	TEST_PAGE_DN $0000, $33, $FF, $02, catastrophic_error
	TEST_PAGE_DN $0000, $CC, $FF, $02, catastrophic_error
	TEST_PAGE $0000, $33, $02, catastrophic_error
	FILLPAGE $0000, $0F, $02
	TEST_PAGE_UP $0000, $0F, $02, catastrophic_error
	TEST_PAGE_UP $0000, $F0, $02, catastrophic_error
	TEST_PAGE_DN $0000, $0F, $FF, $02, catastrophic_error
	TEST_PAGE_DN $0000, $F0, $FF, $02, catastrophic_error
	TEST_PAGE $0000, $0F, $02, catastrophic_error
	; zero-page seems to be alright in it self

	; Turn Activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	; Test base memory 00000000
	ldx	#$01	; Store address $0100 to ZP
	ldy	#$00
	sty	mem_ptr
	stx	mem_ptr+1
	; Compare the written values to ensure they are correct
	cpy	mem_ptr
	beq	:+
	jmp	catastrophic_error
:	cpx	mem_ptr+1
	beq	:+
	jmp	catastrophic_error
:	TESTMEM %00000000

	; Turn activity LED on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	; Test base memory 01010101
	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1
	ldy	#$00
	TESTMEM %01010101

	; Turn activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	; Test base memory 00110011
	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1
	ldy	#$00
	TESTMEM %00110011

	; Turn activity LED on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	; Test base memory 00001111
	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1
	ldy	#$00
	TESTMEM %00001111

	; Turn activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led

	; Base memory seems to be good now we can start using
	; stack and zero page for real
	jmp	basemem_ret

	catastrophic_error:
.scope
	lda	#24		; 24 loops is approximately 60 seconds
	sta	RAM_BANK
loop:	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY	ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY	ONESEC/2
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY	ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY	ONESEC/2
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY	ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY	ONESEC
	dec	RAM_BANK
	beq	:+
	jmp	loop
:	lda	VERA_DC_VIDEO
	eor	#$03
	sta	VERA_DC_VIDEO
.endscope
	jmp	catastrophic_error
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
kbd_bin_tbl:	.byte 0,1,4,5,2,3,6,7

; convert ASCII codes to VERA screen codes
.repeat $20, i
	.charmap i+$40, i
.endrepeat
header:		.asciiz "MEMORY DIAGNOSTIC V0.3 2024 - HTTPS://JNZ.DK?MDIAG"
line:		.asciiz "===================================================="
first_ok:	.asciiz "LOW RAM $0000-$9EFF TESTED OK!                    PASS#:$0000"
find_banks:	.asciiz "TESTING HIGHEST MEMORY BANK AVAILABLE... $"
fill_pattern:	.asciiz "FILLING BANK            $00 WITH BINARY PATTERN "
test_up:	.asciiz "ASCENDING TEST OF BANK  $00 WITH PATTERN "
test_dn:	.asciiz "DESCENDING TEST OF BANK $00 WITH PATTERN "
test_final:	.asciiz "FINAL TEST OF BANK      $00 WITH PATTERN "
low_ram:	.asciiz "TESTING LOW RAM PAGE    $02 WITH PATTERN "
first_pattern:	.asciiz "00000000"
first_invert:	.asciiz "11111111"
second_pattern:	.asciiz "01010101"
second_invert:	.asciiz "10101010"
third_pattern:	.asciiz "00110011"
third_invert:	.asciiz "11001100"
fourth_pattern:	.asciiz "00001111"
fourth_invert:	.asciiz "11110000"
;err_str:	.asciiz "E$XX:$0000TO$00 ",0
err_str:	.asciiz "E$"
err_no_bank:	.asciiz "XX:"
err_up:		.asciiz "UP$"
err_dn:		.asciiz "DN$"
err_to:		.asciiz "TO$"
test_stop:	.asciiz " !!! TOO MANY ERRORS, TEST STOPPED !!! "
hex_table:	.byte "0123456789ABCDEF"
; convert ASCII codes back to normal ASCII
.repeat $20, i
	.charmap i+$40, i+$40
.endrepeat

.include "charset.inc"
.include "palette.inc"

romstart=$E997	; This information is found in kernal.sym (search for start)
romnmi=$E9BD	; This information is found in kernal.sym 
; start & romnmi in ROM bank 0 uses 4 bytes to switch ROM bank over to
; ROM bank 16. Hence this code starts at romnmi or romstart address + 4

.segment "ROMINIT"
	jmp	:+
continue_original:
	stz	$01		; Reset ROM bank to 0
.segment "ROMNMI"
:	I2C_READ_BYTE I2C_SMC, 9
	cpx	#1		; If this byte is set to 1
	beq	do_diag		; poweron has been done with a long-press
	jmp	continue_original
do_diag:jmp	start

.segment "NAME"
DEVINFO: .byte "JIMMY DANSBO - V0.3 - 2024"

.segment "VECTORS"
.word	start	;nmi
.word	start	;start
.word	$0000	;irq