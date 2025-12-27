.segment "JMPTBL"
	; This is only here to make it easy to start the diagnostics
	; from normal operating mode.
	; BANK0,7:SYS$C000
	jmp	diag_start

.segment "DIAG"

.include "io.inc"
.include "regs.inc"
.include "i2c.inc"
.include "macros.inc"
.include "banks.inc"

; Power On Self Test (POST) definitions
; IO port = $9FFF; this is the top of IO space.
POST_IO_PORT		= $9FFF

; These "POST" codes are written to $9FFF for some
; future X16 diagnostic hardware to read and display.
; POST code format: %FSSSCCCC
; F = 1 for fault (system will not continue booting), 0 for normal operation
; SSS = subsystem
; CCCCCCC = code

POST_FAULT                = $80
POST_SYS_GENERIC          = $00
POST_SYS_VERA             = $10
POST_SYS_VIA              = $20
POST_SYS_MEM              = $30
POST_CHECK_VIA            = (POST_SYS_VIA | $00)
POST_CHECK_ZP             = (POST_SYS_MEM | $00)
POST_CHECK_STACK          = (POST_SYS_MEM | $01)
POST_DONE                 = (POST_SYS_GENERIC | $01)

; POST codes for critical faults that prevent further operation
POST_FAULT_CRIT_ZP        = (POST_FAULT | POST_CHECK_ZP)      ; = $B0
POST_FAULT_CRIT_STACK     = (POST_FAULT | POST_CHECK_STACK)   ; = $B1
POST_FAULT_CRIT_VIA       = (POST_FAULT | POST_CHECK_VIA)     ; = $A0

POST_FAULT_VERA           = (POST_FAULT | POST_SYS_VERA)      ; = $90
POST_FAULT_WAIT_VERA      = (POST_FAULT_VERA | $00)           ; = $90
POST_FAULT_INIT_VERA      = (POST_FAULT_VERA | $01)           ; = $91
POST_FAULT_VERA_NOT_READY = (POST_FAULT_VERA | $02)           ; = $92

ONESEC           = $1900
ZP_START_OFFSET  = $02
START_OFFSET     = $00
END_OFFSET       = $FF

RAM_BANK_START   = $A000
RAM_BANK_SIZE    = $2000

BLACK         = $00          ; Colors used in Diag ROM
WHITE         = $01
RED           = $02
BLUE          = $06

I2C_SMC           = $42      ; I2C address of SMC
SMC_activity_led  = $05      ; Offset of activity LED in SMC

TESTUP        = 0            ; Test types
TESTDOWN      = 1
TESTONLY      = 2

; Maximum coordinates for writing error messages. If these are hit,
; there is no more room on the screen to write error messages.
MAX_ERR_X      = $80
MAX_ERR_Y      = $B0+48

; Variables
str_ptr       = r0      ; Pointer used for printing strings
mem_ptr       = r1      ; Pointer used for testing memory
num           = r2      ; String buffer for byte2hex conversion
numbanks      = r4L
num_x         = r4H
x_cord        = r5L
y_cord        = r5H
err_x         = r6L
err_y         = r6H

err_pattern   = r7L
err_low_addr  = r7H
err_test_type = r8L

pass_num      = r9      ; 16bit test-pass counter

color         = r10L
testnum       = r10H
currpattern   = r11L


.assert * = $C010, error, "diag init must start at $C010 like kernal init"
diag_init:
	bra :+
continue_original:
	stz rom_bank   ; Reset ROM bank to 0 to continue loading normal ROM

; Check to see if VIA is present
:	sei            ; Disable interrupts, we don't have anything handling them
	POST POST_CHECK_VIA
	ldy ddr
	ldx #$AA
	stx ddr
	lda ddr
	sty ddr
	cmp #$AA
	beq :+

	; VIA not present, jump to critical fault handler
	POST POST_FAULT_CRIT_VIA
	ldy #POST_FAULT_CRIT_VIA
	jmp diag_fault_critical

; Check to see that we can at least use ZP
:	POST POST_CHECK_ZP
	lda #$55    ; A <= $55
	sta $02     ; ($02) <= $55
	asl         ; A <= $AA
	eor $02     ; A <= $AA ^ $55 == $FF
	inc $02     ; ($02) <= $55 + 1 == $56
	adc $02     ; A <= $FF + $56 == $55
	cmp #$55
	beq :+

	POST POST_FAULT_CRIT_ZP
	ldy #POST_FAULT_CRIT_ZP
	jmp diag_fault_critical ; No ZP

; Check the top few entries of the stack, without these working
; we cannot do any jsr/rts operations.
	POST POST_CHECK_STACK
:	ldx #$FF
	txs
	lda #$A5
	ldx #8
:	pha
	dex
	bne :-

; Pop the top 8 bytes from the stack and verify the expected value
	ldx #8
:	pla
	cmp #$A5
	bne :+
	dex
	bne :-
	POST POST_DONE
	jmp fail_safe_okay

:	POST POST_FAULT_CRIT_STACK
	ldy #POST_FAULT_CRIT_STACK
	jmp diag_fault_critical ; No stack

; If we get here, VIA and memory should be working well enough to check
; if the system was powered on by a long-press of the power button.
fail_safe_okay:
	; Ask SMC if system is powered on by a longpress
	I2C_READ_BYTE I2C_SMC, 9
	cpx #1          ; If this byte is set to 1
	beq diag_start  ; poweron has been done with a long-press
	jmp continue_original
diag_start:
	sei             ; Disable interrupts when starting via JMPTBL
	jmp basemem_test
basemem_ret:
	ldx #$FF        ; Set stack pointer
	txs

	jsr vera_init   ; Initialize VERA
	lda #$11        ; Set increment=1 and bank=1

	lda #$B0+41     ; Initialize X and Y coordinates for err msgs
	sta err_y
	stz err_x

	stz pass_num    ; Initialize pass_num variable to 0
	stz pass_num+1

	lda #((BLUE<<4)|WHITE) ;Initialize standard color
	sta color

	lda #0           ; Turn all keyboard LEDs off
	jsr kbdwrite

	jsr write_nmi_handler

	GOTOXY #6, #1
	PRINTSTR header
	GOTOXY #5, #2
	PRINTSTR line
	GOTOXY #1, #4
	PRINTSTR first_ok
	GOTOXY #1, #6
	PRINTSTR find_banks
	jsr detectbanks
	sta numbanks
	jsr byte2hex
	PRINTSTR num

test_start:
	ldx #26             ; The bank number being tested is printed
	stx num_x           ; at X coordinate 26
	lda #8              ; First line of text is at 1, 8
	sta y_cord
	lda #1
	sta x_cord

	; Test of banked memory
	sta testnum
	lda #%00000000      ; Test pattern
	jsr testpattern
	inc y_cord          ; Extra line between each test pattern
	inc y_cord

	inc testnum
	lda #%01010101      ; Test pattern
	jsr testpattern
	inc y_cord          ; Extra line between each test pattern
	inc y_cord

	inc testnum
	lda #%00110011      ; Test pattern
	jsr testpattern
	inc y_cord          ; Extra line between each test pattern
	inc y_cord

	inc testnum
	lda #%00001111      ; Test pattern
	jsr testpattern

	lda #5
	jsr kbdwrite
	inc y_cord
	inc y_cord
	lda #%00000000
	sta currpattern
	; Test of base memory
btest:
	GOTOXY x_cord, y_cord
	PRINTSTR low_ram
	lda currpattern
	jsr printpat
	lda #$2F            ; /
	sta VERA_DATA0
	inc VERA_ADDR_L
	lda currpattern
	eor #$FF
	jsr printpat
	lda currpattern
	jsr testbase
	inc y_cord
	lda currpattern
	cmp #$00
	bne :+
	lda #$55
	sta currpattern
	bra btest
:	cmp #$55
	bne :+
	lda #$33
	sta currpattern
	bra btest
:	cmp #$33
	bne :+
	lda #$0F
	sta currpattern
	bra btest

:	jsr write_nmi_handler

	lda #7              ; Show that tests are done
	jsr kbdwrite
	jsr show_pass_done

	inc pass_num        ; Update number of passes
	bne :+
	inc pass_num+1
:	GOTOXY #58, #4
	lda pass_num+1
	jsr byte2hex
	PRINTSTR num
	lda pass_num
	jsr byte2hex
	PRINTSTR num

	; Clear test pattern information from screen
	stz VERA_ADDR_L
	lda #$B7
	sta VERA_ADDR_M
	ldx #65
	ldy #33
	jsr clrscr

	; Switch between VGA and Composite/S-Video output
	lda VERA_DC_VIDEO
	eor #$03
	sta VERA_DC_VIDEO

	jmp test_start

write_nmi_handler:
	lda nmi_handler,y
	sta nmi,y
	iny
	cpy #7
	bne write_nmi_handler
	rts
nmi_handler:
	lda #BANK_DIAG
	sta rom_bank
	jmp diag_start

; Print the pattern currently in .A register
printpat:
	cmp #$00
	bne :+
	jmp print1stpat	;00000000
:	cmp #$FF
	bne :+
	jmp print1stinv	;11111111
:	cmp #$55
	bne :+
	jmp print2ndpat	;01010101
:	cmp #$AA
	bne :+
	jmp print2ndinv	;10101010
:	cmp #$33
	bne :+
	jmp print3rdpat	;00110011
:	cmp #$CC
	bne :+
	jmp print3rdinv	;11001100
:	cmp #$0F
	bne :+
	jmp print4thpat	;00001111
:	jmp print4thinv	;11110000
print1stpat:
	PRINTSTR first_pattern
	rts
print1stinv:
	PRINTSTR first_invert
	rts
print2ndpat:
	PRINTSTR second_pattern
	rts
print2ndinv:
	PRINTSTR second_invert
	rts
print3rdpat:
	PRINTSTR third_pattern
	rts
print3rdinv:
	PRINTSTR third_invert
	rts
print4thpat:
	PRINTSTR fourth_pattern
	rts
print4thinv:
	PRINTSTR fourth_invert
	rts

; Test all memory banks with a specific pattern
testpattern:
	sta currpattern       ; Save the pattern for later use
	lda testnum           ; Show the test number on keyboard LEDs
	jsr kbdwrite
	GOTOXY x_cord, y_cord
	PRINTSTR fill_pattern ; Print that banks are being filled
	lda currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr fillbanks         ; Fill banks with current pattern

	inc y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up      ; Print that test is done ascending
	lda currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr up_test           ; Test&invert the banks ascending

	inc y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_up      ; Print that test is done ascending
	lda currpattern
	eor #$FF              ; Invert pattern
	sta currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr up_test           ; Test&invert the banks ascending

	inc y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn      ; Print that test is done descending
	lda currpattern
	eor #$FF              ; Invert pattern
	sta currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr down_test         ; Test&invert the banks descending

	inc y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_dn      ; Print that test is done descending
	lda currpattern
	eor #$FF              ; Invert pattern
	sta currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr down_test         ; Test&invert the banks descending

	inc y_cord
	GOTOXY x_cord, y_cord
	PRINTSTR test_final   ; Print that this is final test
	lda currpattern
	eor #$FF              ; Invert pattern
	sta currpattern
	jsr printpat          ; Print the current pattern
	lda currpattern
	jsr testbanks         ; Test the banks
	jmp show_pattern_done


; .A = code to show on LEDs in binary
kbdwrite:
	pha ; Store binary code on stack
	; Tell SMC that we are sending a command to the keyboard
	; and that we want to set the keyboard LEDs
	I2C_WRITE_FIRST_BYTE KBD_SET_LEDS_CMD, I2C_SMC, KBD_2BYTE_CMD
	plx ; Retrieve binary code from stack
	; The LEDs on the keyboard do not line up with a binary number
	; kbd_bin_tbl ensures that the number in .X is shown correctly
	lda kbd_bin_tbl,x
	jsr i2c_write
	jsr i2c_stop
	rts

show_pattern_done:
	lda #$FF
	jsr activity_set
	jsr delayone
	lda #$00
	jmp activity_set

activity_set:
	phx
	phy
	ldx #I2C_SMC
	ldy #SMC_activity_led
	jsr i2c_write_b
	ply
	plx
	rts

; Blink the activity light 3 times to show that a pass is completed
show_pass_done:
	ldx #5
	lda #$FF
:	phx
	pha
	jsr activity_set
;	ldx #I2C_SMC
;	ldy #SMC_activity_led
;	jsr i2c_write_b
	jsr delayone
	pla
	eor #$FF
	plx
	dex
	bne :-
	; Turn Activity light off
	lda #$00
	jsr activity_set
;	ldx #I2C_SMC
;	ldy #SMC_activity_led
;	jsr i2c_write_b
	rts

; Delay for approximately 1 second
delayone:
	DELAY ONESEC
	rts

; .Y = low order address
; mem_ptr+1 = high order address
; .A = pattern
; .X = test type - 0=up, 1=down, 2=testonly
; RAM_BANK = current RAM bank
handle_error:
	sta err_pattern      ;  Save Registers
	sty err_low_addr
	stx err_test_type

	lda err_y            ; Set VERA address (GOTOXY)
	sta VERA_ADDR_M
	lda err_x
	sta VERA_ADDR_L
	PRINTSTR err_str, ((BLACK<<4)|WHITE); Print the beginning of Error string
	lda mem_ptr+1
	cmp #>RAM_BANK_START ; Is address >= RAM_BANK_START
	bcs @rambank
	; Here the address is not in BANKED memory
	PRINTSTR err_no_bank, ((BLACK<<4)|WHITE)
	bra @do_address
@rambank:
	lda ram_bank
	jsr byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
@do_address:
	lda #$24             ; $
	sta VERA_DATA0
	stx VERA_DATA0
	lda mem_ptr+1
	jsr byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
	lda err_low_addr
	jsr byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)

	lda err_test_type    ; switch (err_test_type)
@up:
	bne @down        ; case UP
	PRINTSTR err_up, ((BLACK<<4)|WHITE)
	bra @endswitch
@down:
	cmp #TESTDOWN    ; case DOWN
	bne @test
	PRINTSTR err_dn, ((BLACK<<4)|WHITE)
	bra @endswitch
@test:
	PRINTSTR err_to, ((BLACK<<4)|WHITE); case TESTONLY
@endswitch:
	lda err_pattern
	jsr byte2hex
	PRINTSTR num, ((BLACK<<4)|WHITE)
	lda #$20         ; space
	sta VERA_DATA0
	stx VERA_DATA0

	; Error has been written, now we need to figure out if the maximum
	; number of errors have been displayed.
	lda VERA_ADDR_L
	sta err_x
	cmp #MAX_ERR_X         ; If we have reached max X coordinate 
	bne @end               ; we need to go to next line

	stz err_x              ; Reset X coordinate
	lda err_y
	cmp #MAX_ERR_Y         ; If we have reached max Y coordinate
	bne :+                 ; we inform about max reached and
	jsr print_test_stop
	jmp catastrophic_error ; Show error in activity LED as well
:	inc                    ; Go to next line
	sta err_y
@end:
	lda err_pattern        ; Restore Registers
	ldy err_low_addr       ; X register restored by caller
	rts

; Write on screen that tests have stopped
print_test_stop:
	GOTOXY #12, #49
	PRINTSTR test_stop, ((BLACK<<4)|RED)
	rts

; Fill basememory pages above stack page with a specific pattern
fillpages:
	ldx #<$0200            ; Store initial base address to ZP
	stx mem_ptr
	ldx #>$0200
	stx mem_ptr+1
@memloop:
	pha                    ; Save pattern
	txa                    ; Write current page to screen
	jsr printnum
	pla                    ; Restore pattern
	ldx mem_ptr+1          ; Restore bank in .X
	ldy #0
@pageloop:
	sta (mem_ptr),y        ; Write pattern to an entire page
	iny
	bne @pageloop
	inx                    ; Go to next page
	cpx #$9F               ; If we have reached page $9F, we are done
	beq :+
	stx mem_ptr+1          ; Save new page
	bra @memloop
:	rts

; Do ascending test&invert of basemem pages above stack page 
page_up:
	ldx #<$0200            ; Store initial base address to ZP
	stx mem_ptr
	ldx #>$0200
	stx mem_ptr+1
@memloop:
	pha                    ; Save pattern
	txa                    ; Write current page to screen
	jsr printnum
	pla                    ; Restore pattern
	ldx mem_ptr+1          ; Restore bank in .X
	ldy #0
@pageloop:
	cmp (mem_ptr),y        ; Write pattern to an entire page
	beq :+
	ldx #TESTUP
	jsr handle_error
	ldx mem_ptr+1
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	iny
	bne @pageloop
	inx                    ; Go to next page
	cpx #$9F               ; If we have reached page $9F, we are done
	beq :+
	stx mem_ptr+1          ; Save new page
	bra @memloop
:	rts

; Do descending test&invert of basemem pages above stack page
page_down:
	ldx #<$9E00
	stx mem_ptr
	ldx #>$9E00
	stx mem_ptr+1
@memloop:
	pha                    ; Save pattern
	txa                    ; Write current page to screen
	jsr printnum
	pla
	ldx mem_ptr+1
	ldy #0
@pageloop:
	dey                    ; Write pattern to entire page
	cmp (mem_ptr),y
	beq :+
	ldx #TESTDOWN
	jsr handle_error
	ldx mem_ptr+1
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	dey
	bne @pageloop
	dex
	cpx #$01
	beq :+
	stx mem_ptr+1
	bra @memloop
:	rts

; Test pattern of base memory pages above stack page
testpages:
	ldx #<$0200            ; Store initial base address to ZP
	stx mem_ptr
	ldx #>$0200
	stx mem_ptr+1
@memloop:
	pha                    ; Save pattern
	txa                    ; Write current page to screen
	jsr printnum
	pla                    ; Restore pattern
	ldx mem_ptr+1          ; Restore bank in .X
	ldy #0
@pageloop:
	cmp (mem_ptr),y        ; Write pattern to an entire page
	beq :+
	ldx #TESTONLY
	jsr handle_error
	ldx mem_ptr+1
:	iny
	bne @pageloop
	inx                    ; Go to next page
	cpx #$9F               ; If we have reached page $9F, we are done
	beq :+
	stx mem_ptr+1          ; Save new page
	bra @memloop
:	rts

; Do a complete test of base memory
testbase:
	jsr fillpages
	jsr page_up
	eor #$FF
	jsr page_up
	eor #$FF
	jsr page_down
	eor #$FF
	jsr page_down
	eor #$FF
	jsr testpages
	rts

; Fill all available memory banks with a specific testpattern
fillbanks:
	stz ram_bank
	ldx #<RAM_BANK_START
	stx mem_ptr
@memloop:
	ldx #>RAM_BANK_START
	stx mem_ptr+1
	ldy #0
@pageloop:
	sta (mem_ptr),y
	iny
	bne @pageloop
	inx
	stx mem_ptr+1
	cpx #>(RAM_BANK_START+RAM_BANK_SIZE)
	bne @pageloop
	ldy ram_bank
	cpy numbanks
	beq :+
	iny
	sty ram_bank
	pha
	tya
	jsr printnum
	pla
	bra @memloop
:	rts

; Do an ascending test&invert of all available memory banks
up_test:
	stz ram_bank
	ldx #<RAM_BANK_START
	stx mem_ptr
@memloop:
	ldx #>RAM_BANK_START
	stx mem_ptr+1
	ldy #0
@pageloop:
	cmp (mem_ptr),y
	beq :+
	ldx #TESTUP
	jsr handle_error
	ldx mem_ptr+1
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	iny
	bne @pageloop
	inx
	stx mem_ptr+1
	cpx #>(RAM_BANK_START+RAM_BANK_SIZE)
	bne @pageloop
	ldy ram_bank
	cpy numbanks
	beq :+
	iny
	sty ram_bank
	pha
	tya
	jsr printnum
	pla
	bra @memloop
:	rts

; Do a descending test&invert of all available memory banks
down_test:
	pha
	lda numbanks
	sta ram_bank
	jsr printnum
	pla
	ldx #<(RAM_BANK_START+RAM_BANK_SIZE)
	stx mem_ptr
@memloop:
	ldx #>(RAM_BANK_START+RAM_BANK_SIZE)-1
	stx mem_ptr+1
	ldy #0
@pageloop:
	dey
	cmp (mem_ptr),y
	beq :+
	ldx #TESTDOWN
	jsr handle_error
	ldx mem_ptr+1
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	cpy #0
	bne @pageloop
	dex
	stx mem_ptr+1
	cpx #>RAM_BANK_START-1
	bne @pageloop
	ldy ram_bank
	cpy #0
	beq :+
	dey
	sty ram_bank
	pha
	tya
	jsr printnum
	pla
	bra @memloop
:	rts

; Test all available memory banks with specific pattern
testbanks:
	stz ram_bank
	ldx #<RAM_BANK_START
	stx mem_ptr
@memloop:
	ldx #>RAM_BANK_START
	stx mem_ptr+1
	ldy #0
@pageloop:
	cmp (mem_ptr),y
	beq :+
	ldx #TESTONLY
	jsr handle_error
	ldx mem_ptr+1
:	iny
	bne @pageloop
	inx
	stx mem_ptr+1
	cpx #>(RAM_BANK_START+RAM_BANK_SIZE)
	bne @pageloop
	ldy ram_bank
	cpy numbanks
	beq :+
	iny
	sty ram_bank
	pha
	tya
	jsr printnum
	pla
	bra @memloop
:	rts

; Convert the byte in .A into a hex in the num string
byte2hex:
	ldy #0
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda hex_table,x
	jsr @add_hex
	pla
	and #$0F
	tax
	lda hex_table,x
@add_hex:
	sta num,y
	iny
	lda #0
	sta num,y
	rts

; Print the number in .A as a hexadecimal number at num_x, y_cord coordinates
printnum:
	jsr byte2hex
	GOTOXY num_x, y_cord
	PRINTSTR num
	rts

; "Borrowed" from official ROM
detectbanks:
;
; detect number of RAM banks
; 
	stz ram_bank
	lda RAM_BANK_START     ;get value from 00:a000
	eor #$FF               ;use inverted value as test value for other banks
	tax

	ldy #1                 ;bank to test
:	sty ram_bank
	lda RAM_BANK_START     ;save current value
	stx RAM_BANK_START     ;write test value
	stz ram_bank
	cpx RAM_BANK_START     ;check if 00:a000 is affected = wrap-around
	beq @memtest2
	sty ram_bank
	sta RAM_BANK_START     ;restore value
	iny                    ;next bank
	bne :-

@memtest2:
	stz ram_bank           ;restore value in 00:a000
	txa
	eor #$FF
	sta RAM_BANK_START

	ldx #1                 ;start testing from bank 1
	stx ram_bank
:	ldx #8                 ;test 8 addresses in each bank
:	lda RAM_BANK_START,x   ;read, xor, write, compare
	eor #$FF
	sta RAM_BANK_START,x
	cmp RAM_BANK_START,x
	bne @test_done         ;test failed, we are done
	eor #$FF               ;restore value
	sta RAM_BANK_START,x
	dex                    ;test next address
	bne :-
	inc ram_bank           ;select next ank
	cpy ram_bank           ;stop at last bank that does not wrap-around to bank0
	bne :--
@test_done:
	lda ram_bank           ;number of RAM banks
	dec
	rts

; Convert X, Y coordinates to VERA address
gotoxy:
	txa
	asl
	sta VERA_ADDR_L
	tya
	clc
	adc #$B0
	sta VERA_ADDR_M
	rts

; Print a string, pointed to by str_ptr
printstr:
	ldy #0                 ; Use .Y as index into string
@loop:
	lda (str_ptr),y
	beq @end               ; If it is 0, jump to end
	sta VERA_DATA0         ; Write character to VERA memory, VERA
	stx VERA_DATA0         ; Write color information
	iny                    ; Increment .Y
	bra @loop              ; Jump back to get next character
@end:
	rts

;---------------------------------------------------------------
; Wait for VERA to be ready
;
; VERA's FPGA needs some time to configure itself. This function
; will see if the configuration is done by writing a VERA
; register and checking if the value is correctly written.
;---------------------------------------------------------------
vera_wait_ready:
	lda #42
	sta VERA_ADDR_L
	lda VERA_ADDR_L
	cmp #42
	bne vera_wait_ready
	rts

; Copy character set to VERA
screen_set_charset:
	lda #<charset_addr
	sta VERA_ADDR_L
	lda #>charset_addr
	sta VERA_ADDR_M
	lda #$10 | ^charset_addr
	sta VERA_ADDR_H

	lda #<charset
	sta mem_ptr
	lda #>charset
	sta mem_ptr+1
	ldx #2                 ; 64 charactes * 8 bytes = 512 bytes
	ldy #0                 ; = 2 * 256
:	lda (mem_ptr),y
	sta VERA_DATA0
	iny
	bne :-
	inc mem_ptr+1
	dex
	bne :-
	rts

; Initialize VERA
vera_init:
	jsr vera_wait_ready
	lda #1
	sta VERA_IEN
	stz VERA_CTRL
	jsr screen_set_charset

	; Layer 1 configuration
	lda #%01100000         ; Map Height = 01b = 64 tiles
	sta VERA_L1_CONFIG     ; Map Width  = 10b = 128 tiles
	lda #(screen_addr>>9)
	sta VERA_L1_MAPBASE
	lda #((charset_addr>>11)<<2)
	sta VERA_L1_TILEBASE
	stz VERA_L1_HSCROLL_L
	stz VERA_L1_HSCROLL_H
	stz VERA_L1_VSCROLL_L
	stz VERA_L1_VSCROLL_H
	; Display composer configuration 64x50
	lda #2
	sta VERA_CTRL
	; Set Mode 8 = 64x50
	lda #$14
	sta VERA_DC_VSTART
	lda #$DC
	sta VERA_DC_VSTOP
	lda #$10
	sta VERA_DC_HSTART
	lda #$90
	sta VERA_DC_HSTOP

	stz VERA_CTRL
	lda #$21               ; Layer1 enabled, VGA output
	sta VERA_DC_VIDEO
	lda #128
	sta VERA_DC_HSCALE
	sta VERA_DC_VSCALE
	stz VERA_DC_BORDER

	lda #$11               ; Increment=1, Bank=1
	sta VERA_ADDR_H
	lda #$B0               ; Address of top left corner
	sta VERA_ADDR_M
	stz VERA_ADDR_L
	; Clear the screen with black background
	ldx #64
	ldy #51

clrscr:
	phx
@loop:
	lda #$20               ; Space character
	sta VERA_DATA0
	lda #((BLUE<<4)|WHITE) ; White on BLUE
	sta VERA_DATA0
	dex
	bne @loop
	plx
	inc VERA_ADDR_M
	stz VERA_ADDR_L
	dey
	bne clrscr
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
;            a    value  (preserved)
;            c    1 on error (NAK)
;---------------------------------------------------------------
i2c_write_b:
.scope
	phx            ; Save register on stack
	phy
	pha
	pha            ; Store value on stack
	phy            ; Store offset on stack
	phx            ; Store device address on stack
	I2C_INIT
	I2C_START
	pla            ; address from stack 
	asl
	jsr i2c_write
	bcc :+
	jmp error
:	pla            ; offset from stack
	jsr i2c_write
	pla            ; value from stack
	jsr i2c_write
	jsr i2c_stop
	clc
	bra end
error:
	sec            ; Ensure stack is cleared on error
	pla
	pla
end:
	pla            ; Restore registers from stack
	ply
	plx
	rts
.endscope

i2c_write:
	I2C_WRITE
	rts

i2c_stop:
	I2C_STOP
	rts

; !!!!!!!!!!!!!!!! NO STACK USAGE IN BELOW CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
basemem_test:
	; Turn Activity light on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	; Test zero-page
	lda #$00
@zptest:
	FILL_ZP
	TEST_ZP_UP catastrophic_error
	eor #$FF
	TEST_ZP_UP catastrophic_error
	eor #$FF
	TEST_ZP_DN catastrophic_error
	eor #$FF
	TEST_ZP_DN catastrophic_error
	eor #$FF
	TEST_ZP catastrophic_error
	cmp #$00
	beq @set55
	cmp #$55
	beq @set33
	cmp #$33
	beq @set0f
	bra @continue
@set55:
	lda #$55
	jmp @zptest
@set33:
	lda #$33
	jmp @zptest
@set0f:
	lda #$0F
	jmp @zptest
@continue:
	; zero-page seems to be alright in it self

	; Turn Activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led

	; Test base memory
	lda #%00000000
basetest:
	ldx #$01       ; Store address $0100 to ZP
	ldy #$00
	sty mem_ptr
	stx mem_ptr+1
	TESTMEM
	cmp #$00
	beq base55
	cmp #$55
	bne :+
	jmp base33
:	cmp #$33
	bne :+
	jmp base0f
:	jmp done
base55:
	;   Turn activity LED on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	lda #$55
	jmp basetest
base33:
	;   Turn activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	lda #$33
	jmp basetest
base0f:
	;   Turn activity LED on
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	lda #$0F
	jmp basetest

done:;  Turn activity LED off
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	;   Base memory seems to be good now we can start using
	;   stack and zero page for real
	jmp basemem_ret

catastrophic_error:
.scope
	lda #24        ; 24 loops is approximately 60 seconds
	sta ram_bank   ; RAM_BANK is just used as storage here...
loop:
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY ONESEC/2
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY ONESEC/2
	I2C_WRITE_BYTE $FF, I2C_SMC, SMC_activity_led
	DELAY ONESEC/2
	I2C_WRITE_BYTE $00, I2C_SMC, SMC_activity_led
	DELAY ONESEC
	dec ram_bank
	beq :+
	jmp loop
	; Switch between VGA & Composit/S-Video output approximately
	; once a minute
:	lda VERA_DC_VIDEO
	eor #$03
	sta VERA_DC_VIDEO
.endscope
	jmp catastrophic_error
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

; Critical fault handler - used when via, zp, or stack is not usable
; Fault ID in Y register
diag_fault_critical:
	ldx #0
diag_fault_wait_vera:
	POST POST_FAULT_WAIT_VERA
	lda #42
	sta VERA_ADDR_L
	lda VERA_ADDR_L
	cmp #42
	beq vera_init_ramless

	; Burn some cycles
	lda #0
:
	nop
	nop
	inc
	bne :-

	inx
	bne diag_fault_wait_vera

	; Catastrophic error - VERA not responding
	POST POST_FAULT_VERA_NOT_READY
	jmp catastrophic_error

; VERA ready
vera_init_ramless:
	POST POST_FAULT_INIT_VERA

	stz VERA_IEN
	stz VERA_CTRL
	lda #$21               ; Layer1 enabled, VGA output
	sta VERA_DC_VIDEO

	; Layer 1 configuration
	lda #%01100000         ; Map Height = 01b = 64 tiles
	sta VERA_L1_CONFIG     ; Map Width  = 10b = 128 tiles
	lda #(screen_addr>>9)
	sta VERA_L1_MAPBASE
	lda #((charset_addr>>11)<<2)
	sta VERA_L1_TILEBASE
	stz VERA_L1_HSCROLL_L
	stz VERA_L1_HSCROLL_H
	stz VERA_L1_VSCROLL_L
	stz VERA_L1_VSCROLL_H
	; Display composer configuration 64x50
	lda #2
	sta VERA_CTRL
	; Set Mode 8 = 64x50
	lda #$14
	sta VERA_DC_VSTART
	lda #$DC
	sta VERA_DC_VSTOP
	lda #$10
	sta VERA_DC_HSTART
	lda #$90
	sta VERA_DC_HSTOP

	stz VERA_CTRL
	lda #$21               ; Layer1 enabled, VGA output
	sta VERA_DC_VIDEO
	lda #128
	sta VERA_DC_HSCALE
	sta VERA_DC_VSCALE
	stz VERA_DC_BORDER

	lda #$11               ; Increment=1, Bank=1
	sta VERA_ADDR_H
	lda #$B0               ; Address of top left corner
	sta VERA_ADDR_M
	stz VERA_ADDR_L

	; Clear the screen with red background
	ldx #128               ; Save a couple bytes by writing 128 instead of 64

veraclr_ramless:
	; Y contains the error code and RAM is not safe to use,
	; thus using repeat here for clearing the screen
.repeat 50
	lda #' '               ; Space character
	sta VERA_DATA0
	lda #((RED<<4)|WHITE)  ; White on Red
	sta VERA_DATA0
.endrepeat
	dex
	beq :+
	jmp veraclr_ramless

; Copy character set to VERA
:	lda #<(charset_addr)
	sta VERA_ADDR_L
	lda #>(charset_addr)
	sta VERA_ADDR_M
	lda #$10 | ^(charset_addr) ; address increment mode +1
	sta VERA_ADDR_H

	ldx #0                     ; 64 charactes * 8 bytes = 512 bytes

:	lda charset,x
	sta VERA_DATA0
	inx
	bne :-

:	lda charset+256,x
	sta VERA_DATA0
	inx
	bne :-

; print fault ID, in hex, at position 1,1
; fault code in Y register
	ldx #((RED<<4)|WHITE)
	lda #<(screen_addr)
	sta VERA_ADDR_L
	lda #>(screen_addr)
	sta VERA_ADDR_M
	lda #$11                 ; Increment=1, Bank=1
	sta VERA_ADDR_H

	lda #'H'-'@'             ; '@' is the char before 'A' in ASCII and PETSCII
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'W'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #' '
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'F'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'A'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'U'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'L'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #'T'-'@'
	sta VERA_DATA0
	stx VERA_DATA0
	lda #' '
	sta VERA_DATA0
	stx VERA_DATA0

	sty POST_IO_PORT         ; Write fault code for external visibility
	tya
	lsr
	lsr
	lsr
	lsr
	tax
	lda hex_table,x
	sta VERA_DATA0
	lda #((RED<<4)|WHITE)
	sta VERA_DATA0
	tya
	and #$0F
	tay
	lda hex_table,y
	sta VERA_DATA0
	lda #((RED<<4)|WHITE)
	sta VERA_DATA0

	jmp catastrophic_error

kbd_bin_tbl:
	.byte 0,1,4,5,2,3,6,7
; convert ASCII codes to VERA screen codes
.repeat $20, i
	.charmap i+$40, i
.endrepeat
;header:	.asciiz "MEMORY DIAGNOSTIC V0.4 2024 - HTTPS://JNZ.DK?MDIAG"
header:
	.asciiz "MEMORY DIAGNOSTIC V0.41 - HTTPS://COMMANDERX16.COM"
line:
	.asciiz "===================================================="
first_ok:
	.asciiz "LOW RAM $0000-$9EFF INITIAL TEST OK!              PASS#:$0000"
find_banks:
	.asciiz "TESTING HIGHEST MEMORY BANK AVAILABLE... $"
fill_pattern:
	.asciiz "FILLING BANK            $00 WITH BINARY PATTERN "
test_up:
	.asciiz "ASCENDING TEST OF BANK  $00 WITH PATTERN "
test_dn:
	.asciiz "DESCENDING TEST OF BANK $00 WITH PATTERN "
test_final:
	.asciiz "FINAL TEST OF BANK      $00 WITH PATTERN "
low_ram:
	.asciiz "TESTING LOW RAM PAGE    $02 WITH PATTERN "
first_pattern:
	.asciiz "00000000"
first_invert:
	.asciiz "11111111"
second_pattern:
	.asciiz "01010101"
second_invert:
	.asciiz "10101010"
third_pattern:
	.asciiz "00110011"
third_invert:
	.asciiz "11001100"
fourth_pattern:
	.asciiz "00001111"
fourth_invert:
	.asciiz "11110000"
;err_str:
;	.asciiz "E$XX$0000:TO$00 ",0
err_str:
	.asciiz "E$"
err_no_bank:
	.asciiz "XX"
err_up:
	.asciiz ":UP$"
err_dn:
	.asciiz ":DN$"
err_to:
	.asciiz ":TO$"
test_stop:
	.asciiz " !!! TOO MANY ERRORS, TEST STOPPED !!! "
hex_table:
	.byte "0123456789ABCDEF"
; convert ASCII codes back to normal ASCII
.repeat $20, i
	.charmap i+$40, i+$40
.endrepeat

.include "charset.inc"

.segment "VECTORS"
	.word diag_start  ;nmi - This will not work as it seems SMC sets ROMBANK to 0 on NMI
	.word diag_start  ;start
	.word $0000       ;irq
