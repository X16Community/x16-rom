;----------------------------------------------------------------------
; SNES Controller Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "banks.inc"
.include "io.inc"
.include "keycode.inc"

; KERNAL API
.export joystick_scan
.export joystick_get
; called by ps2 keyboard driver
.export joystick_from_ps2_init, joystick_from_ps2

nes_data = d1pra
nes_ddr  = d1ddra

bit_latch = $04 ; PA2 LATCH (both controllers)
bit_jclk  = $08 ; PA3 CLK   (both controllers)
bit_data4 = $10 ; PA4 DATA  (controller #4)
bit_data3 = $20 ; PA5 DATA  (controller #3)
bit_data2 = $40 ; PA6 DATA  (controller #2)
bit_data1 = $80 ; PA7 DATA  (controller #1)

.segment "KVARSB0"

j0tmp:	.res 1           ;    keyboard joystick temp
joy0:	.res 3           ;    keyboard joystick status
joy1:	.res 3           ;    joystick 1 status
joy2:	.res 3           ;    joystick 2 status
joy3:	.res 3           ;    joystick 3 status
joy4:	.res 3           ;    joystick 4 status

.segment "JOYSTICK"

;---------------------------------------------------------------
; joystick_scan
;
; Function:  Scan all joysticks
;
; Duration before changes: 1,787 clock cycles => 223 us
; Duration after changes: 1,627 clock cycles => 203 us
; No loop: 1306 => 163,25 us
;---------------------------------------------------------------
joystick_scan:
	KVARS_START_TRASH_A_NZ

	; Set latch and clock as outputs, and data1..4 as inputs, leave I2C pins (0..1) unchanged
	lda nes_ddr
	and #$ff-bit_data1-bit_data2-bit_data3-bit_data4
	ora #bit_latch+bit_jclk
	sta nes_ddr

	; Set latch=low and clock=high
	lda #bit_jclk
	sta nes_data

	; pulse latch while clk=high
	lda #bit_latch+bit_jclk
	sta nes_data
	pha
	pla
	pha
	pla
	pha
	pla
	pha
	pla
	pha
	pla
	stz nes_data

	; read 3x 8 bits
	ldx #bit_jclk
	ldy #8
l1:	stz nes_data ; Drive NES clock low (NES controller doesn't change when low)
	nop          ; Delay for slow SNES controllers
	lda nes_data ; Read all controller bits
	stx nes_data ; Drive NES clock high

				; process while NES clock is high (bits change)
	rol        ; Move bit 7 into C
	rol joy1   ; Roll C into joy1
	rol        ; Move bit 6 into C
	rol joy2   ; Roll C into joy2
	rol        ; Roll bit 5 into C
	rol joy3   ; Roll C into joy3
	rol        ; Roll bit 4 into C
	rol joy4   ; Roll C into joy4

	dey
	bne l1

	ldy #8
l2:	stz nes_data ; Drive NES clock low (NES controller doesn't change when low)

	lda nes_data ; Read all controller bits
	stx nes_data ; Drive NES clock high

				; process while NES clock is high (bits change)
	rol        ; Move bit 7 into C
	rol joy1+1 ; Roll C into joy1
	rol        ; Move bit 6 into C
	rol joy2+1 ; Roll C into joy2
	rol        ; Roll bit 5 into C
	rol joy3+1 ; Roll C into joy3
	rol        ; Roll bit 4 into C
	rol joy4+1 ; Roll C into joy4

	dey
	bne l2

	ldy #8
l3:	stz nes_data ; Drive NES clock low (NES controller doesn't change when low)

	lda nes_data ; Read all controller bits
	stx nes_data ; Drive NES clock high

				; process while NES clock is high (bits change)
	rol        ; Move bit 7 into C
	rol joy1+2 ; Roll C into joy1
	rol        ; Move bit 6 into C
	rol joy2+2 ; Roll C into joy2
	rol        ; Roll bit 5 into C
	rol joy3+2 ; Roll C into joy3
	rol        ; Roll bit 4 into C
	rol joy4+2 ; Roll C into joy4

	dey
	bne l3

	; force present if controller ID (bits 8-11) is not 15
	
	lda joy1+1
	and #%00001111
	cmp #15
	beq :+
	stz joy1+2
:	lda joy2+1
	and #%00001111
	cmp #15
	beq :+
	stz joy2+2
:	lda joy3+1
	and #%00001111
	cmp #15
	beq :+
	stz joy3+2
:	lda joy4+1
	and #%00001111
	cmp #15
	beq :+
	stz joy4+2
:

	KVARS_END_TRASH_A_NZ
	rts

;---------------------------------------------------------------
; joystick_get
;
; Function:  Return the state of a given joystick.
;
; Pass:      a    number of joystick (0-3)
; Return:    a    byte 0:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;                         SNES | B | Y |SEL|STA|UP |DN |LT |RT |
;
;            x    byte 1:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;                         SNES | A | X | L | R | 1 | 1 | 1 | 1 |
;            y    byte 2:
;                         $00 = joystick present
;                         $FF = joystick not present
;
; Note:      * Presence can be detected by checking byte 2.
;---------------------------------------------------------------
joystick_get:
	KVARS_START_TRASH_X_NZ
	tax
	beq @0       ; -> joy0
	dex
	beq @1       ; -> joy1
	dex
	beq @2       ; -> joy2
	dex
	beq @3       ; -> joy3
	dex
	beq @4       ; -> joy4
	lda #$ff
	tax
	tay
	bra @5

@0:
	lda joy0
	ldx joy0+1
	ldy joy0+2
	bra @5

@1:
	lda joy1
	ldx joy1+1
	ldy joy1+2
	bra @5

@2:
	lda joy2
	ldx joy2+1
	ldy joy2+2
	bra @5

@3:
	lda joy3
	ldx joy3+1
	ldy joy3+2
	bra @5

@4:
	lda joy4
	ldx joy4+1
	ldy joy4+2

@5:	KVARS_END
	rts

;----------------------------------------------------------------------
; joystick_from_ps2:
;
;  init keyboard joystick state (internal)
;
; Note: This is called from the ps2kbd driver while bank 0 is active,
;       no bank switching is performed.
;
joystick_from_ps2_init:
	lda #$ff
	sta joy0
	sta joy0+1
	sta joy0+2 ; joy0 bot present
	rts

;----------------------------------------------------------------------
; joystick_from_ps2:
;
;  convert PS/2 scancode into SNES joystick state (internal)
;
; Note: This is called from the ps2kbd driver while bank 0 is active,
;       no bank switching is performed.
;
joystick_from_ps2:
	pha

	; Clear up/down bit
	and #$7f

	; Search key code table 0
	ldx #intab0_len
:	cmp intab0-1,x
	beq @match0
	dex
	bne :-

	; Search key code table 1
	ldx #intab1_len
:	cmp intab1-1,x
	beq @match1
	dex
	bne :-

	; Exit
@end:	stz joy0+2
	pla
	rts

@match0:
	pla
	pha
	bmi :+		; key up

	lda outtab0-1,x
	eor #$ff
	and joy0
	sta joy0
	bra @end

:	lda outtab0-1,x
	ora joy0
	sta joy0
	bra @end

@match1:
	pla
	pha
	bmi :+		; key up

	lda outtab1-1,x
	eor #$ff
	and joy0+1
	sta joy0+1
	bra @end

:	lda outtab1-1,x
	ora joy0+1
	sta joy0+1
	bra @end


C_RT = 1
C_LT = 2
C_DN = 4
C_UP = 8
C_ST = 16
C_SL = 32
C_Y  = 64
C_B  = 128

C_R  = 16
C_L  = 32
C_X  = 64
C_A  = 128

;     SNES |   A   |   B  | X | Y | L | R | START  | SELECT |
; keyboard |   X   |   Z  | S | A | D | C | RETURN | LShift |
;          | LCtrl | LAlt |

outtab0:
	.byte C_RT, C_LT, C_DN, C_UP
	.byte C_ST, C_SL, C_Y, C_B
	.byte C_B

outtab1:
	.byte C_R, C_L, C_X, C_A
	.byte C_A

intab0:
	.byte KEYCODE_RIGHTARROW, KEYCODE_LEFTARROW, KEYCODE_DOWNARROW, KEYCODE_UPARROW
	.byte KEYCODE_ENTER, KEYCODE_LSHIFT, KEYCODE_A, KEYCODE_Z
	.byte KEYCODE_LALT
intab0_len = *-intab0

intab1:
	.byte KEYCODE_C, KEYCODE_D, KEYCODE_S, KEYCODE_X
	.byte KEYCODE_LCTRL
intab1_len = *-intab1
