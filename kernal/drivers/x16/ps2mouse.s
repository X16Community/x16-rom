;----------------------------------------------------------------------
; PS/2 Mouse Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.macpack longbranch

.include "banks.inc"
.include "io.inc"
.include "regs.inc"
.include "mac.inc"

; code
.import i2c_write_byte, i2c_read_byte, i2c_read_first_byte, i2c_direct_read, i2c_read_next_byte, i2c_read_stop
.import screen_save_state
.import screen_restore_state
.import sprite_set_image, sprite_set_position
.import ps2data_keyboard_and_mouse, ps2data_keyboard_only, ps2data_mouse, ps2data_mouse_count

.export mouse_config, mouse_scan, mouse_get, wheel

.segment "KVARSB0"

msepar:	.res 1           ;    $80: mouse on; 1/2: scale
mousemx:
	.res 2           ;    max x coordinate
mousemy:
	.res 2           ;    max y coordinate
mousex:	.res 2           ;    cur x coordinate
mousey:	.res 2           ;    cur y coordinate
mousebt:
	.res 1           ;    cur buttons (1: left, 2: right, 4: third)
wheel:	.res 1           ;    Intellimouse wheel buffer
idat:	.res 1           ;    Intellimouse data packet
mouse_id:
	.res 1           ;    mouse device ID

I2C_ADDRESS = $42
I2C_GET_MOUSE_DEVICE_ID = $22
BAT_FAIL = $fc

.segment "PS2MOUSE"

; "MOUSE" KERNAL call
; A: $00 hide mouse
;    n   show mouse, set mouse cursor #n
;    $FF show mouse, don't configure mouse cursor
; X: width in 8px
; Y: height in 8px
;    X==0 && Y==0: leave as-is
mouse_config:
	KVARS_START
	jsr _mouse_config
	KVARS_END
	rts
_mouse_config:
	pha
	phx
	phy

	; clear mouse wheel buffer
	stz wheel

	; fetch mouse device ID
	ldx #I2C_ADDRESS
	ldy #I2C_GET_MOUSE_DEVICE_ID
	jsr i2c_read_byte
	sta mouse_id
	cmp #BAT_FAIL ; return if SMC reports mouse init failed
	bne :+
	ply
	plx
	pla
	rts

:	ply
	plx
	cpx #0
	jeq @skip

	; scale
 	lda #0
	cpx #41
	bcs :+
	ora #2
:	cpy #31
	bcs :+
	ora #1
:	sta msepar ;  set scale
	pha

	; width * x
	txa
	stz mousemx+1
	asl
	asl
	rol mousemx+1
	asl
	rol mousemx+1
	sta mousemx
	; height * x
	tya
	stz mousemy+1
	asl
	asl
	asl
	rol mousemy+1
	sta mousemy

	; 320w and less: double the width
	; 240h and less: double the height
	pla
	and #2
	beq :+
	asl mousemx
	rol mousemx+1
:	lda msepar
	and #1
	beq @skip2
	asl mousemy
	rol mousemy+1
@skip2:
	DecW mousemx
	DecW mousemy
	; center the pointer
	lda mousemx+1
	lsr
	sta mousex+1
	lda mousemx
	ror
	sta mousex

	lda mousemy+1
	lsr
	sta mousey+1
	lda mousemy
	ror
	sta mousey

@skip:
	pla
	cmp #0
	bne mous2
; hide mouse, disable sprite #0
	lda msepar
	and #$7f
	sta msepar

	PushW r0H
	lda #$ff
	sta r0H
	inc
	jsr sprite_set_position
	PopW r0H

	; set SMC default read operation to fetch only key codes
	jmp ps2data_keyboard_only

; show mouse
mous2:	cmp #$ff
	beq mous3

	; we ignore the cursor #, always set std pointer
	PushW r0
	PushW r1
	LoadW r0, mouse_sprite_col
	LoadW r1, mouse_sprite_mask
	LoadB r2L, 1 ; 1 bpp
	ldx #16      ; width
	ldy #16      ; height
	lda #0       ; sprite 0
	sec          ; apply mask
	jsr sprite_set_image
	PopW r1
	PopW r0

mous3:	lda msepar
	ora #$80 ; flag: mouse on
	sta msepar

	; set SMC default read operation to return key code and mouse packet
	lda #3
	ldx mouse_id
	beq :+
	lda #4
:	jsr ps2data_keyboard_and_mouse
	jmp mouse_update_position

mouse_scan:
	KVARS_START
	jsr _mouse_scan
	KVARS_END
	rts

_mouse_scan:
	bit msepar ; do nothing if mouse is off
	bpl @a
	lda ps2data_mouse_count
	bne @b ; 0 = no data
@a:	rts

@b:
.if 0
	; heuristic to test we're not out
	; of sync:
	; * overflow needs to be 0
	; * bit #3 needs to be 1
	; The following codes sent by
	; the mouse will also be skipped
	; by this logic:
	; * $aa: self-test passed
	; * $fa: command acknowledged
	tax
	and #$c8
	cmp #$08
	bne @a
	txa
.endif
	; Store status byte
	lda ps2data_mouse
	sta mousebt

	; Add delta X
	lda ps2data_mouse+1
	clc
	adc mousex
	sta mousex

	lda mousebt
	and #$10
	beq :+
	lda #$ff
:	adc mousex+1
	sta mousex+1

	; Add delta Y
	lda ps2data_mouse+2
	eor #$ff
	sec
	adc mousey
	sta mousey
	lda mousebt
	and #$20
	beq :+
	lda #$ff
:	eor #$ff
	adc mousey+1
	sta mousey+1

	; Add wheel movement
	lda ps2data_mouse+3
	and #15			; Convert 4 bit signed value to 8 bit signed value
	cmp #8
	bcc :+
	ora #240

:	clc			; Add movement to buffer
	adc wheel
	bvs :+			; Ignore if overflow
	sta wheel

	; Clean up status byte, show only button state
:	lda mousebt
	and #7
	sta mousebt

	; Check bounds

	lda mousex+1		; x < 0?
	bpl :+			; No
	stz mousex		; Yes, x < 0, set x = 0
	stz mousex+1
	bra :++

:	sec			; x > max?
	lda mousemx
	sbc mousex
	lda mousemx+1
	sbc mousex+1
	bcs :+			; No

	lda mousemx		; Yes, x > max, set x = max
	sta mousex
	lda mousemx+1
	sta mousex+1

:	lda mousey+1		; y < 0?
	bpl :+			; No
	stz mousey		; Yes, y < 0, set y = 0
	stz mousey+1
	bra :++

:	sec			; y > max?
	lda mousemy
	sbc mousey
	lda mousemy+1
	sbc mousey+1
	bcs :+			; No

	lda mousemy		; Yes, y > max, set y = max
	sta mousey
	lda mousemy+1
	sta mousey+1
:

; set the mouse sprite position
mouse_update_position:
	jsr screen_save_state

	PushW r0
	PushW r1

	lda wheel
	pha

	ldx #r0
	jsr mouse_get
	lda #0
	jsr sprite_set_position

	pla
	sta wheel

	PopW r1
	PopW r0

	jsr screen_restore_state
	rts ; NB: call above does not support tail call optimization

mouse_get:
	KVARS_START
	php
	sei
	jsr _mouse_get
	plp
	KVARS_END
	rts

_mouse_get:
	lda msepar
	and #2
	; x scale
	bne @x1
	lda mousex
	sta 0,x
	lda mousex+1
	sta 1,x
@cy:
	lda msepar
	and #1
	; y scale
	bne @y1
	lda mousey
	sta 2,x
	lda mousey+1
	sta 3,x
	lda mousebt
	bra @exit
@x1:
	lda mousex+1
	lsr
	sta 1,x
	lda mousex
	ror
	sta 0,x
	bra @cy
@y1:
	lda mousey+1
	lsr
	sta 3,x
	lda mousey
	ror
	sta 2,x

@exit:	lda #0		; Return mouse button flags
	ldx mouse_id
	cpx #4
	bne :+
	lda idat	; Add Intellimouse buttons, if device ID is 4
	and #48
:	ora mousebt

	ldx wheel
	stz wheel
	rts

; This is the Susan Kare mouse pointer
mouse_sprite_col: ; 0: black, 1: white
.byte %11000000,%00000000
.byte %10100000,%00000000
.byte %10010000,%00000000
.byte %10001000,%00000000
.byte %10000100,%00000000
.byte %10000010,%00000000
.byte %10000001,%00000000
.byte %10000000,%10000000
.byte %10000000,%01000000
.byte %10000011,%11100000
.byte %10010010,%00000000
.byte %10101001,%00000000
.byte %11001001,%00000000
.byte %10000100,%10000000
.byte %00000100,%10000000
.byte %00000011,%10000000
mouse_sprite_mask: ; 0: transparent, 1: opaque
.byte %11000000,%00000000
.byte %11100000,%00000000
.byte %11110000,%00000000
.byte %11111000,%00000000
.byte %11111100,%00000000
.byte %11111110,%00000000
.byte %11111111,%00000000
.byte %11111111,%10000000
.byte %11111111,%11000000
.byte %11111111,%11100000
.byte %11111110,%00000000
.byte %11101111,%00000000
.byte %11001111,%00000000
.byte %10000111,%10000000
.byte %00000111,%10000000
.byte %00000011,%10000000

