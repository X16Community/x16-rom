;----------------------------------------------------------------------
; VERA 320x240@256c Graphics Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "mac.inc"
.include "regs.inc"
.include "io.inc"

.export FB_VERA

.import ptr_fg					;Imported from kernal.sym file during link stage

.segment "GRAPH"

FB_VERA:
	.word FB_init
	.word FB_get_info
	.word FB_set_palette
	.word FB_cursor_position
	.word FB_cursor_next_line
	.word FB_get_pixel
	.word FB_get_pixels
	.word FB_set_pixel
	.word FB_set_pixels
	.word FB_set_8_pixels
	.word FB_set_8_pixels_opaque
	.word FB_fill_pixels
	.word FB_filter_pixels
	.word FB_move_pixels

;---------------------------------------------------------------
; FB_init
;
; Pass:      -
;---------------------------------------------------------------
FB_init:
	; Layer 0, 256c bitmap
	lda #$07
	sta VERA_L0_CONFIG
	stz VERA_L0_HSCROLL_H  ; Clear palette offset
	lda #((fb_addr >> 9) & $FC)
	sta VERA_L0_TILEBASE

	; Enable layer 0
	lda VERA_DC_VIDEO
	ora #$10
	sta VERA_DC_VIDEO

	; Display composer: scale for 320x240
	stz VERA_CTRL
	lda #64
	sta VERA_DC_HSCALE
	sta VERA_DC_VSCALE
	rts


;---------------------------------------------------------------
; FB_get_info
;
; Return:    r0       width
;            r1       height
;            a        color depth
;---------------------------------------------------------------
FB_get_info:
	LoadW r0, 320
	LoadW r1, 240
	lda #8
	rts

;---------------------------------------------------------------
; FB_set_palette
;
; Function:  Set (a part of) the VERA's color palette
; Pass  :    r0       pointer to color palette data
;            a        VERA palette start color index
;            x        number of colors to set (0=256)
;---------------------------------------------------------------
FB_set_palette:
	stz  VERA_CTRL
	ldy  #%00010001
	sty  VERA_ADDR_H
	ldy  #$fa
	asl  a
	bcc  @1
	iny
@1:	sty  VERA_ADDR_M
	sta  VERA_ADDR_L
@loop:	lda  (r0)
	sta  VERA_DATA0
	inc  r0
	bne  @3
	inc  r0+1
@3:	lda  (r0)
	sta  VERA_DATA0
	inc  r0
	bne  @4
	inc  r0+1
@4:	dex
	bne  @loop
	rts

;---------------------------------------------------------------
; FB_cursor_position
;
; Function:  Sets up the VRAM ptr
; Pass:      r0     x pos
;            r1     y pos
;---------------------------------------------------------------
FB_cursor_position:
; ptr_fg = y * 320
	stz ptr_fg+1

	; y * 64
	lda r1L
.repeat 6
	asl
	rol ptr_fg+1
.endrepeat
	sta ptr_fg

	; + y * 256
	lda r1L
	clc
	adc ptr_fg+1
	sta ptr_fg+1
	lda #0
	rol
	sta ptr_fg+2

	; += x
	lda r0L
	clc
	adc ptr_fg
	sta ptr_fg
	sta VERA_ADDR_L
	lda r0H
	adc ptr_fg+1
	sta ptr_fg+1
	sta VERA_ADDR_M
	lda #$10 | ^fb_addr ; add base address top bit, plus increment setting
	adc ptr_fg+2
	sta ptr_fg+2
	sta VERA_ADDR_H

	rts

;---------------------------------------------------------------
; FB_cursor_next_line
;
; Function:  Advances VRAM ptr to next line
; Pass:      r0     additional x pos
;---------------------------------------------------------------
FB_cursor_next_line:
	lda #<320
	clc
	adc ptr_fg
	sta ptr_fg
	sta VERA_ADDR_L
	lda #>320
	adc ptr_fg+1
	sta ptr_fg+1
	sta VERA_ADDR_M
	lda #0
	adc ptr_fg+2
	sta ptr_fg+2
	sta VERA_ADDR_H
	rts

;---------------------------------------------------------------
; FB_set_pixel
;
; Function:  Stores a color in VRAM/BG and advances the pointer
; Pass:      a   color
;---------------------------------------------------------------
FB_set_pixel:
	sta VERA_DATA0
	rts

;---------------------------------------------------------------
; FB_get_pixel
;
; Pass:      r0   x pos
;            r1   y pos
; Return:    a    color of pixel
;---------------------------------------------------------------
FB_get_pixel:
	lda VERA_DATA0
	rts

;---------------------------------------------------------------
; FB_set_pixels
;
; Function:  Stores an array of color values in VRAM/BG and
;            advances the pointer
; Pass:      r0  pointer
;            r1  count
;---------------------------------------------------------------
FB_set_pixels:
	PushB r0H
	PushB r1H
	jsr set_pixels_FG
	PopB r1H
	PopB r0H
	rts

set_pixels_FG:
	lda r1H
	beq @a

	ldx #0
@c:	jsr @b
	inc r0H
	dec r1H
	bne @c
	lda r1L
	bne @a
	rts

@a:	ldx r1L
@b:	ldy #0
:	lda (r0),y
	sta VERA_DATA0
	iny
	dex
	bne :-
	rts

;---------------------------------------------------------------
; FB_get_pixels
;
; Function:  Fetches an array of color values from VRAM/BG and
;            advances the pointer
; Pass:      r0  pointer
;            r1  count
;---------------------------------------------------------------
FB_get_pixels:
	PushB r0H
	PushB r1H
	jsr get_pixels_FG
	PopB r1H
	PopB r0H
	rts

get_pixels_FG:
	lda r1H
	beq @a

	ldx #0
@c:	jsr @b
	inc r0H
	dec r1H
	bne @c
	lda r1L
	bne @a
	rts

@a:	ldx r1L
@b:	ldy #0
:	lda VERA_DATA0
	sta (r0),y
	iny
	dex
	bne :-
	rts

;---------------------------------------------------------------
; FB_set_8_pixels
;
; Note: Always advances the pointer by 8 pixels.
;
; Pass:      a        pattern
;            x        color
;---------------------------------------------------------------
FB_set_8_pixels:
; this takes about 120 cycles, independently of the pattern
	sec
	rol
	bcs @2
	inc VERA_ADDR_L
	bne @1
	inc VERA_ADDR_M
@1:	asl
	bcs @2
	inc VERA_ADDR_L
	bne @1
	inc VERA_ADDR_M
	bra @1
@2:	beq @3
	stx VERA_DATA0
	bra @1
@3:	rts

;---------------------------------------------------------------
; FB_set_8_pixels_opaque
;
; Note: Always advances the pointer by 8 pixels.
;
; Pass:      a        mask
;            r0L      pattern
;            x        color
;            y        color
;---------------------------------------------------------------
FB_set_8_pixels_opaque:
; opaque drawing with fg color .x and bg color .y
	sec
	rol
	bcc @3
	beq @4
	asl r0L
	bcs @2
	sty VERA_DATA0
@1:	asl
	bcc @3
	beq @4
	asl r0L
	bcs @2
	sty VERA_DATA0
	bra @1
@2:	stx VERA_DATA0
	bra @1
@3:	asl r0L
	inc VERA_ADDR_L
	bne @1
	inc VERA_ADDR_M
	bra @1
@4:	rts

;---------------------------------------------------------------
; FB_fill_pixels
;
; Pass:      r0   number of pixels
;            r1   step size
;            a    color
;---------------------------------------------------------------
FB_fill_pixels:
	ldx r1L
	ldy r1H
	bne fill_pixels_step_256_or_more_jmp
	cpx #2
	bcs fill_pixels_step_below_256

fill_pixels_hw_accelerated:

; step 1
	ldx r0H
	beq @2

; full blocks, 8 bytes at a time
@1:	ldy #$20
	jsr fill_y
	dex
	bne @1

; partial block, 8 bytes at a time
@2:	pha
	lda r0L
	lsr
	lsr
	lsr
	beq @6
	tay
	pla
	jsr fill_y

; remaining 0 to 7 bytes
	pha
@6:	lda r0L
	and #7
	beq @5
	tay
	pla
@3:	sta VERA_DATA0
	dey
	bne @3
@4:	rts

@5:	pla
	rts

fill_y:	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	sta VERA_DATA0
	dey
	bne fill_y
	rts

fill_pixels_step_256_or_more_jmp:
	jmp fill_pixels_step_256_or_more
fill_pixels_non_accelerated_jmp:
	jmp fill_pixels_non_accelerated

fill_pixels_step_below_256:
	; Binary search algorithm
	; Tradeoff between speed and code size
	; Look for these values: 2 4 8 16 32 40 64 80 128 160
	; 2 4   8 16 32 40 64 80 128 160
	; 2   4   8 16 32 40   64 80 128 160
	; 2   4   8 16   32 40   64 80   128 160

	tay
	; 2-4 or 8-16-32-40-64-80-128-160
	cpx #8
	bcs is8OrLarger
	; 2-4
	cpx #2
	beq is2
	cpx #4
	bne fill_pixels_non_accelerated_skip_tay

	; is4
	lda #((3 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step
is2:
	lda #((2 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step

is8OrLarger:
	; 8-16-32-40 or 64-80-128-160
	cpx #64
	bcs is64OrLarger
	; check 8-16 or 32-40
	cpx #32
	bcs is32OrLarger
	; 8-16
	cpx #8
	beq is8
	cpx #16
	bne fill_pixels_non_accelerated
	; is16
	lda #((5 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step
is8:
	lda #((4 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step

is32OrLarger:
	; 32-40
	; cpx #32 not necessary to repeat
	beq is32
	cpx #40
	bne fill_pixels_non_accelerated
	; is40
	lda #((11 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step
is32:
	lda #((6 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step

is64OrLarger:
	; 64-80-128-160
	cpx #128
	bcs is128OrLarger
	; 64-80
	cpx #64
	beq is64
	cpx #80
	bne fill_pixels_non_accelerated
	; is80
	lda #((12 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step
is64:
	lda #((7 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step

is128OrLarger:
	; 128-160
	; cpx #128 not necessary to repeat
	beq is128
	cpx #160
	bne fill_pixels_non_accelerated
	; is160
	lda #((13 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step
is128:
	lda #((8 << 4) ^ $10)
	bra fill_pixels_accelerated_custom_step

	; NB: This optimization assumes that increment is initially set to 1, and that decrement is set to 0
fill_pixels_accelerated_custom_step:
	eor VERA_ADDR_H
	sta VERA_ADDR_H
	tya
	jsr fill_pixels_hw_accelerated

fill_pixels_reset_increment_and_rts:
	; Restore ADDR_H to use increment 1
	lda VERA_ADDR_H
	and #$01
	ora #$10
	sta VERA_ADDR_H
	rts

fill_pixels_non_accelerated:
	tay
fill_pixels_non_accelerated_skip_tay:

	; temporarily set increment to 0
	lda #$FE
	trb VERA_ADDR_H

	ldx r0L
	beq @1
	; Increment r0H, as the outer loop terminates when decrementing it to 0.
	; Skip if r0L is 0, as the inner loop decrements until it becomes 0.
	inc r0H
@1:
	clc

	; increment larger than 255?
	lda r1H
	bne fill_pixels_non_accelerated_16bit

	lda VERA_ADDR_L

@loop8bit:

	sty VERA_DATA0

	; increment with r1 (step size)
	adc r1L
	sta VERA_ADDR_L
	bcs @incrementM

@resumeLoop8:
	dex
	bne @loop8bit
	dec r0H
	bne @loop8bit
	bra fill_pixels_reset_increment_and_rts

@incrementM:
	; carry, increment M and H addresses
	clc
	inc VERA_ADDR_M
	bne @resumeLoop8
	inc VERA_ADDR_H
	bra @resumeLoop8


fill_pixels_non_accelerated_16bit:

@loop16bit:

	sty VERA_DATA0

	lda VERA_ADDR_L
	adc r1L
	sta VERA_ADDR_L

	lda VERA_ADDR_M
	adc r1H
	sta VERA_ADDR_M

	bcs @incrementH

@resumeLoop16:
	dex
	bne @loop16bit
	dec r0H
	bne @loop16bit
	bra fill_pixels_reset_increment_and_rts

@incrementH:
	inc VERA_ADDR_H
	clc
	bra @resumeLoop16



fill_pixels_step_256_or_more:
	; Look for accelerated values: 256, 512, 320, 640 (0x0100 0x0200 0x0140 0x0280)
	dey
	beq isBelow512
	dey
	bne fill_pixels_non_accelerated
	; 512-767
	tay

	; is 640? (0x280)
	cpx #$80
	beq is640
	; is 512? (0x200)
	cpx #$00
	bne fill_pixels_non_accelerated_skip_tay
	; 512
	lda #((10 << 4) ^ $10)
	jmp fill_pixels_accelerated_custom_step
is640:
	lda #((15 << 4) ^ $10)
	jmp fill_pixels_accelerated_custom_step

isBelow512:
	; 256-511
	tay
	; is 320? (0x140)
	cpx #$40
	beq is320
	; is 256? (0x100)
	cpx #$00
	bne fill_pixels_non_accelerated_skip_tay
	; 256
	lda #((9 << 4) ^ $10)
	jmp fill_pixels_accelerated_custom_step
is320:
	; 320
	lda #((14 << 4) ^ $10)
	jmp fill_pixels_accelerated_custom_step


;---------------------------------------------------------------
; FB_filter_pixels
;
; Pass:      r0   number of pixels
;            r1   pointer to filter routine:
;                 Pass:    a  color
;                 Return:  a  color
;---------------------------------------------------------------
FB_filter_pixels:
	; build a JMP instruction
	LoadB r14H, $4c
	MoveW r1, r15

	lda VERA_ADDR_L
	ldx VERA_ADDR_M
	inc VERA_CTRL ; 1
	sta VERA_ADDR_L
	stx VERA_ADDR_M
	lda #$10 | ^fb_addr
	sta VERA_ADDR_H
	stz VERA_CTRL ; 0
	sta VERA_ADDR_H

	ldx r0H
	beq @2

; full blocks, 8 bytes at a time
	ldy #$20
@1:	jsr filter_y
	dex
	bne @1

; partial block, 8 bytes at a time
@2:	lda r0L
	lsr
	lsr
	lsr
	beq @6
	tay
	jsr filter_y

; remaining 0 to 7 bytes
@6:	lda r0L
	and #7
	beq @4
	tay
@3:	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	dey
	bne @3
@4:	rts

filter_y:
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	lda VERA_DATA0
	jsr r14H
	sta VERA_DATA1
	dey
	bne filter_y
	rts

;---------------------------------------------------------------
; FB_move_pixels
;
; Pass:      r0   source x
;            r1   source y
;            r2   target x
;            r3   target y
;            r4   number of pixels
;---------------------------------------------------------------
FB_move_pixels:
; XXX sy == ty && sx < tx && sx + c > tx -> backwards!

	lda #1
	sta VERA_CTRL
	jsr FB_cursor_position
	stz VERA_CTRL
	PushW r0
	PushW r1
	MoveW r2, r0
	MoveW r3, r1
	jsr FB_cursor_position
	PopW r1
	PopW r0

	ldx r4H
	beq @2

; full blocks, 8 bytes at a time
	ldy #$20
@1:	jsr copy_y
	dex
	bne @1

; partial block, 8 bytes at a time
@2:	lda r4L
	lsr
	lsr
	lsr
	beq @6
	tay
	jsr copy_y

; remaining 0 to 7 bytes
@6:	lda r4L
	and #7
	beq @4
	tay
@3:	lda VERA_DATA1
	sta VERA_DATA0
	dey
	bne @3
@4:	rts

copy_y:	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	lda VERA_DATA1
	sta VERA_DATA0
	dey
	bne copy_y
	rts
