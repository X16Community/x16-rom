;----------------------------------------------------------------------
; Commander X16 KERNAL: Graphics library
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD
; (Bresenham code based on GEOS by Berkeley Softworks)

.include "mac.inc"
.include "regs.inc"
.include "banks.inc"

ram_bank = 0

.import leftMargin, windowTop, rightMargin, windowBottom
.import FB_VERA

.import font_init

.export GRAPH_init
.export GRAPH_clear
.export GRAPH_set_window
.export GRAPH_set_colors
.export GRAPH_draw_line
.export GRAPH_draw_rect
.export GRAPH_draw_image
.export GRAPH_move_rect
.export GRAPH_draw_oval
.export set_window_fullscreen

.import I_FB_BASE
.import I_FB_END

.import FB_init
.import FB_get_info
.import FB_set_palette
.import FB_cursor_position
.import FB_cursor_next_line
.import FB_get_pixel
.import FB_get_pixels
.import FB_set_pixel
.import FB_set_pixels
.import FB_set_8_pixels
.import FB_set_8_pixels_opaque
.import FB_fill_pixels
.import FB_filter_pixels
.import FB_move_pixels

.import square_16, mult_16x32, mult_8x8_fast

.export col1, col2, col_bg

.segment "GRAPHVAR"
col1: .res 1
col2: .res 1
col_bg: .res 1

;.import col1, col2, col_bg			;Set during link stage, read from Kernal.sym

.import grjsrfar

.segment "GRAPH"

;---------------------------------------------------------------
; GRAPH_init
;
; Function:  Enable a given low-level graphics mode driver,
;            and switch to this mode.
;
; Pass:      r0     pointer to FB_* driver vectors
;                   If 0, this enables the default driver
;                   (320x240@256c).
;---------------------------------------------------------------
GRAPH_init:
	lda r0L
	ora r0H
	bne :+
	LoadW r0, FB_VERA
:
	; copy VERA driver vectors
	ldy #<(I_FB_END - I_FB_BASE - 1)
:	lda (r0),y
	sta I_FB_BASE,y
	dey
	bpl :-

	jsr FB_init

	jsr set_window_fullscreen

	lda #0  ; primary:    black
	ldx #10 ; secondary:  gray
	ldy #1  ; background: white

	jsr GRAPH_set_colors

    jsr GRAPH_clear

    jmp font_init

;---------------------------------------------------------------
; GRAPH_clear
;
;---------------------------------------------------------------
GRAPH_clear:
	KVARS_START_TRASH_A_NZ
	PushB col1
	PushB col2
	lda col_bg
	sta col1
	sta col2
	MoveW leftMargin, r0
	MoveB windowTop, r1L
	stz r1H
	MoveW rightMargin, r2
	SubW r0, r2
	IncW r2
	MoveB windowBottom, r3L
	stz r3H
	SubW r1, r3
	IncW r3
	sec
	jsr GRAPH_draw_rect
	PopB col2
	PopB col1
	KVARS_END_TRASH_A_NZ
	rts

set_window_fullscreen:
	jsr FB_get_info
	MoveW r0, r2
	MoveW r1, r3
	lda #0
	sta r0L
	sta r0H
	sta r1L
	sta r1H
; fallthrough

;---------------------------------------------------------------
; GRAPH_set_window
;
; Pass:      r0     x
;            r1     y
;            r2     width
;            r3     height
;
; Note: 0/0/0/0 will set the window to full screen.
;---------------------------------------------------------------
GRAPH_set_window:
	lda r0L
	ora r0H
	ora r1L
	ora r1H
	ora r2L
	ora r2H
	ora r3L
	ora r3H
	beq set_window_fullscreen

	KVARS_START_TRASH_A_NZ
	MoveW r0, leftMargin
	MoveW r1, windowTop

	lda r0L
	clc
	adc r2L
	sta rightMargin
	lda r0H
	adc r2H
	sta rightMargin+1
	lda rightMargin
	bne :+
	dec rightMargin+1
:	dec rightMargin

	lda r1L
	clc
	adc r3L
	sta windowBottom
	lda r1H
	adc r3H
	sta windowBottom+1
	lda windowBottom
	bne :+
	dec windowBottom+1
:	dec windowBottom
	KVARS_END_TRASH_A_NZ
	rts

;---------------------------------------------------------------
; GRAPH_set_colors
;
; Pass:      a primary color
;            x secondary color
;            y background color
;---------------------------------------------------------------
GRAPH_set_colors:
	sta col1   ; primary color
	stx col2   ; secondary color
	sty col_bg ; background color
	rts

;---------------------------------------------------------------
; GRAPH_draw_line
;
; Pass:      r0       x1
;            r1       y2
;            r2       x1
;            r3       y2
;---------------------------------------------------------------
GRAPH_draw_line:
	CmpW r1, r3        ; horizontal?
	bne @0a            ; no
	jmp HorizontalLine

@0a:	CmpW r0, r2        ; vertical?
	bne @0             ; no
	jmp VerticalLine

; Bresenham
@0:	php
	LoadB r7H, 0
	lda r3L
	sub r1L
	sta r7L
	bcs @1
	lda #0
	sub r7L
	sta r7L
@1:	lda r2L
	sub r0L
	sta r12L
	lda r2H
	sbc r0H
	sta r12H
	ldx #r12
	jsr abs
	CmpW r12, r7
	bcs @2
	jmp @9
@2:
	lda r7L
	asl
	sta r9L
	lda r7H
	rol
	sta r9H
	lda r9L
	sub r12L
	sta r8L
	lda r9H
	sbc r12H
	sta r8H
	lda r7L
	sub r12L
	sta r10L
	lda r7H
	sbc r12H
	sta r10H
	asl r10L
	rol r10H
	LoadB r13L, $ff
	CmpW r0, r2
	bcc @4
	CmpB r1L, r3L
	bcc @3
	LoadB r13L, 1
@3:	ldy r0H
	ldx r0L
	MoveW r2, r0
	sty r2H
	stx r2L
	MoveB r3L, r1L
	bra @5
@4:	ldy r3L
	cpy r1L
	bcc @5
	LoadB r13L, 1
@5:	lda col1
	plp
	php
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	CmpW r0, r2
	bcs @8
	inc r0L
	bne @6
	inc r0H
@6:	bbrf 7, r8H, @7
	AddW r9, r8
	bra @5
@7:	AddB r13L, r1L
	AddW r10, r8
	bra @5
@8:	plp
	rts
@9:	lda r12L
	asl
	sta r9L
	lda r12H
	rol
	sta r9H
	lda r9L
	sub r7L
	sta r8L
	lda r9H
	sbc r7H
	sta r8H
	lda r12L
	sub r7L
	sta r10L
	lda r12H
	sbc r7H
	sta r10H
	asl r10L
	rol r10H
	LoadW r13, $ffff
	CmpB r1L, r3L
	bcc @B
	CmpW r0, r2
	bcc @A
	LoadW r13, 1
@A:	MoveW r2, r0
	ldx r1L
	lda r3L
	sta r1L
	stx r3L
	bra @C
@B:	CmpW r0, r2
	bcs @C
	LoadW r13, 1
@C:	lda col1
	plp
	php
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	CmpB r1L, r3L
	bcs @E
	inc r1L
	bbrf 7, r8H, @D
	AddW r9, r8
	bra @C
@D:	AddW r13, r0
	AddW r10, r8
	bra @C
@E:	plp
	rts

; calc abs of word in zp at location .x
abs:
	lda 1,x
	bmi @0
	rts
@0:	lda 1,x
	eor #$FF
	sta 1,x
	lda 0,x
	eor #$FF
	sta 0,x
	inc 0,x
	bne @1
	inc 1,x
@1:	rts

;---------------------------------------------------------------
; HorizontalLine (internal)
;
; Pass:      r0   x position of first pixel
;            r1   y position
;            r2   x position of last pixel
;---------------------------------------------------------------
HorizontalLine:
	; make sure x2 > x1
	lda r2L
	sec
	sbc r0L
	lda r2H
	sbc r0H
	bcs @2
	lda r0L
	ldx r2L
	stx r0L
	sta r2L
	lda r0H
	ldx r2H
	stx r0H
	sta r2H

@2:	jsr FB_cursor_position

	MoveW r2, r15
	SubW r0, r15
	IncW r15

	PushW r0
	PushW r1
	MoveW r15, r0
	LoadW r1, 0
	lda col1
	jsr FB_fill_pixels
	PopW r1
	PopW r0
	rts

;---------------------------------------------------------------
; VerticalLine (internal)
;
; Pass:      r0   x
;            r1   y1
;            r2   (unused)
;            r3   y2
;            a    color
;---------------------------------------------------------------
VerticalLine:
	; make sure y2 >= y1
	lda r3L
	cmp r1L
	bcs @0
	ldx r1L
	stx r3L
	sta r1L

@0:	lda r3L
	sec
	sbc r1L
	tax
	inx
	beq @2 ; .x = number of pixels to draw

	jsr FB_cursor_position

	PushW r0
	PushW r1
	LoadW r1, 320
	stx r0L
	stz r0H
	lda col1
	jsr FB_fill_pixels
	PopW r1
	PopW r0
@2:	rts

;---------------------------------------------------------------
; GRAPH_draw_rect
;
; Pass:      r0   x
;            r1   y
;            r2   width
;            r3   height
;            r4   corner radius [TODO]
;            c    1: fill
;---------------------------------------------------------------
GRAPH_draw_rect:
; check for empty
	php
	lda r2L
	ora r2H
	bne @0
@4:	plp
	rts
@0:	lda r3L
	ora r3H
	beq @4
	plp

	bcc @3

; fill
	PushW r1
	PushW r3
	jsr FB_cursor_position

@1:	PushW r0
	PushW r1
	MoveW r2, r0
	LoadW r1, 0
	lda col2
	jsr FB_fill_pixels
	PopW r1
	PopW r0

	jsr FB_cursor_next_line

	lda r3L
	bne @2
	dec r3H
@2:	dec r3L
	lda r3L
	ora r3H
	bne @1

	PopW r3
	PopW r1

; frame
@3:
	PushW r2
	PushW r3
	AddW r0, r2
	lda r2L
	bne :+
	dec r2H
:	dec r2L
	AddW r1, r3
	lda r3L
	bne :+
	dec r3H
:	dec r3L

	jsr HorizontalLine
	PushB r1L
	MoveB r3L, r1L
	jsr HorizontalLine
	PopB r1L
	PushW r0
	jsr VerticalLine
	MoveW r2, r0
	jsr VerticalLine
	PopW r0

	PopW r3
	PopW r2
	rts

;---------------------------------------------------------------
; GRAPH_draw_image
;
; Pass:      r0   x
;            r1   y
;            r2   image pointer
;            r3   width
;            r4   height
;---------------------------------------------------------------
GRAPH_draw_image:
	PushB ram_bank
	PushW r0
	PushW r1
	PushW r4
	jsr FB_cursor_position

	MoveW r2, r0
	MoveW r3, r1
@1:	jsr FB_set_pixels

	lda r4L
	bne :+
	dec r4H
:	dec r4L

	ldy r0H
	AddW r3, r0 ; update pointer
	tya
	sec
	sbc r0H
	beq @2
	lda r0H
	cmp #$c0
	bcc @2     ; we could go from $bf->$c1
	sbc #$20
	sta r0H
	inc ram_bank
@2:
	jsr FB_cursor_next_line

	lda r4L
	ora r4H
	bne @1

	PopW r4
	PopW r1
	PopW r0
	PopB ram_bank
	rts

;---------------------------------------------------------------
; GRAPH_move_rect
;
; Pass:      r0   source x
;            r1   source y
;            r2   target x
;            r3   target y
;            r4   width
;            r5   height
;---------------------------------------------------------------
GRAPH_move_rect:
	CmpW r3, r1
	bcc @2

	AddW r5, r1
	AddW r5, r3
	IncW r5
@1:	jsr FB_move_pixels
	DecW_ r1
	DecW_ r3
	DecW_ r5
	lda r5L
	ora r5H
	bne @1
	rts

@2:	jsr FB_move_pixels
	IncW r1 ; sy
	IncW r3 ; ty
	DecW_ r5
	lda r5L
	ora r5H
	bne @2
	rts

;---------------------------------------------------------------
; GRAPH_draw_oval
;
; Pass:      r0   x
;            r1   y
;            r2   width
;            r3   height
;            c    1: fill
;---------------------------------------------------------------
; Internal mappings

; r4 = x2
; r5 = y2
; r6-r7 = dx
; r8-r9 = dy
; r10-r11 = e2
; r12L high byte of squared width
; r12H high byte of squared height
; r13-r15 = scratch

GRAPH_draw_oval:
	; push callee-saved r-regs
	PushW r0
	PushW r1
	PushW r2
	PushW r3
	PushW r4
	PushW r5
	PushW r6
	PushW r7
	PushW r8
	PushW r9
	PushW r10

	php ; store fill flag in Y
	ply

	; are we asking for a line?

	lda r2H
	bne @chkh
	lda r2L
	cmp #1
	beq @isline
@chkh:
	lda r3H
	bne @cont
	lda r3L
	cmp #1
	bne @cont
@isline:
	DecW r2
	DecW r3
	AddW r0, r2
	AddW r1, r3

	jsr GRAPH_draw_line
	jmp @end
@cont:
	DecW r2
	DecW r3

	PushW r3 ; preserve original (decremented) height
	phy ; store fill flag on stack
	AddW3 r0, r2, r4 ; calculate X2

	; --- dx ---
	; find height squared
	MoveW r3, r15
	jsr square_16 ; in: r15, out: r12-r13
	; multiply by 2

	asl r12L
	rol r12H
	rol r13L
	rol r13H

	; take one less than the width
	lda r2L
	sec
	sbc #1
	sta r11L
	lda r2H
	sbc #0
	sta r11H

	; and multiply it by the previous result
	jsr mult_16x32 ; in: r11 and r12-13, out: r14-15

	; Make negative and store as dx
	lda #0
	sec
	sbc r14L
	sta r6L
	lda #0
	sbc r14H
	sta r6H
	lda #0
	sbc r15L
	sta r7L
	lda #0
	sbc r15H
	sta r7H

	; --- dy ---
	; find width squared

	MoveW r2, r15
	jsr square_16 ; in: r15, out: r12-r13

	; multiply by (2*(height parity+1))

	lda r3L
	and #1
	inc
	tay
@dyshift:
	asl r12L
	rol r12H
	rol r13L
	rol r13H
	dey
	bne @dyshift

	; store as dy
	MoveW r12, r8
	MoveW r13, r9

	; --- e2 ---
	; initialize e2
	stz r10L
	stz r10H
	stz r11L
	stz r11H

	; if parity is odd, start with the square of the width
	lda r3L
	and #1
	beq @noparity

	MoveW r2, r15
	; we'd normally need to preserve r11 here, but we haven't
	; set it up yet, so skip that
	jsr square_16 ; in: r15, out: r12-r13

	MoveW r12, r10
	MoveW r13, r11
@noparity:
	; add dx
	lda r10L
	clc
	adc r6L
	sta r10L
	lda r10H
	adc r6H
	sta r10H
	lda r11L
	adc r7L
	sta r11L
	lda r11H
	adc r7H
	sta r11H

	; add dy
	lda r10L
	clc
	adc r8L
	sta r10L
	lda r10H
	adc r8H
	sta r10H
	lda r11L
	adc r9L
	sta r11L
	lda r11H
	adc r9H
	sta r11H

	; finished setting e2

	; set y/y2 to starting pixels
	; y += (height+1)/2
	lda r3L
	clc
	adc #1
	sta r15L
	lda r3H
	adc #0
	lsr
	sta r15H
	ror r15L

	lda r1L
	clc
	adc r15L
	sta r1L
	lda r1H
	adc r15H
	sta r1H

	; y2 = y - (height parity)
	lda r3L
	dec
	and #1
	lsr
	lda r1L
	sbc #0
	sta r5L
	lda r1H
	sbc #0
	sta r5H

	; width = 4*width^2
	MoveW r2, r15
	PushW r11
	jsr square_16 ; in: r15, out: r12-r13, clobbered: r11
	PopW r11

.repeat 2
	asl r12L
	rol r12H
	rol r13L
.endrepeat
	MoveW r12, r2
	MoveB r13L, r12L

	; height = 4*height^2

	MoveW r3, r15
	PushB r12L
	PushW r11
	jsr square_16
	PopW r11

.repeat 2
	asl r12L
	rol r12H
	rol r13L
.endrepeat

	MoveW r12, r3
	PopB r12L
	MoveB r13L, r12H

@mainloop:
	plp
	php
	bcc @nofill

	jsr FB_cursor_position
	PushW r1
	PushW r0
	lda r4L
	sec
	sbc r0L
	sta r0L
	sta r15L
	lda r4H
	sbc r0H
	sta r0H
	sta r15H
	LoadW r1, 1
	lda col2
	jsr FB_fill_pixels
	PopW r0
	MoveW r5, r1
	jsr FB_cursor_position
	PushW r0
	MoveW r15, r0
	LoadW r1, 1
	lda col2
	jsr FB_fill_pixels
	PopW r0
	PopW r1

@nofill:
	PushW r0
	MoveW r4, r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PopW r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PushW r1
	MoveW r5, r1
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PushW r0
	MoveW r4, r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PopW r0
	PopW r1

@after_plot:
	; copy e2 to scratch
	MoveW r10, r14
	MoveW r11, r15

	; if e2 <= dy (signed)

	lda r9H
	sec
	sbc r11H
	bvc :+
	eor #$80
:	bmi @c1_no
	bne @c1_yes
	lda r9L
	cmp r11L
	bcc @c1_no
	bne @c1_yes
	lda r8H
	cmp r10H
	bcc @c1_no
	bne @c1_yes
	lda r8L
	cmp r10L
	bcc @c1_no
@c1_yes:
	; y++
	inc r1L
	bne :+
	inc r1H
:	; y2--
	lda r5L
	bne :+
	dec r5H
:	dec r5L
	; dy += 4*width^2
	lda r8L
	clc
	adc r2L
	sta r8L
	lda r8H
	adc r2H
	sta r8H
	lda r9L
	adc r12L
	sta r9L
	lda r9H
	adc #0
	sta r9H
	; e2 += dy
	lda r10L
	adc r8L
	sta r10L
	lda r10H
	adc r8H
	sta r10H
	lda r11L
	adc r9L
	sta r11L
	lda r11H
	adc r9H
	sta r11H
@c1_no:
	; if (old) e2 >= dx
	lda r15H
	sec
	sbc r7H
	bvc :+
	eor #$80
:	bmi @c2_maybe
	bne @c2_yes
	lda r15L
	cmp r7L
	bcc @c2_maybe
	bne @c2_yes
	lda r14H
	cmp r6H
	bcc @c2_maybe
	bne @c2_yes
	lda r14L
	cmp r6L
	bcs @c2_yes
@c2_maybe:
	; if e2 > dy
	lda r9H
	sec
	sbc r11H
	bvc :+
	eor #$80
:	bmi @c2_yes
	bne @c2_no
	lda r9L
	cmp r11L
	bcc @c2_yes
	bne @c2_no
	lda r8H
	cmp r10H
	bcc @c2_yes
	bne @c2_no
	lda r8L
	cmp r10L
	bcs @c2_no
@c2_yes:
	; x++
	inc r0L
	bne :+
	inc r0H
:	; x2--
	lda r4L
	bne :+
	dec r4H
:	dec r4L
	; dx += 4*height^2
	lda r6L
	clc
	adc r3L
	sta r6L
	lda r6H
	adc r3H
	sta r6H
	lda r7L
	adc r12H
	sta r7L
	lda r7H
	adc #0
	sta r7H
	; e2 += dx
	lda r10L
	adc r6L
	sta r10L
	lda r10H
	adc r6H
	sta r10H
	lda r11L
	adc r7L
	sta r11L
	lda r11H
	adc r7H
	sta r11H
@c2_no:
	; do while x <= x2
	lda r4H
	cmp r0H
	bcc @no_mainloop
	bne @yes_mainloop
	lda r4L
	cmp r0L
	bcc @no_mainloop
@yes_mainloop:
	jmp @mainloop
@no_mainloop:

	plp
	PopW r3

@secondloop:
	lda r1L
	sec
	sbc r5L
	sta r15L
	lda r1H
	sbc r5H
	cmp r3H
	beq @maybe_secondloop
	bcc @yes_secondloop
	jmp @end
@maybe_secondloop:
	lda r15L
	cmp r3L
	bcc @yes_secondloop
	jmp @end
@yes_secondloop:
	PushW r0
	DecW r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	MoveW r4, r0
	IncW r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PopW r0
	IncW r1

	PushW r0
	DecW r0
	PushW r1
	MoveW r5, r1
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	MoveW r4, r0
	IncW r0
	jsr FB_cursor_position
	lda col1
	jsr FB_set_pixel
	PopW r1
	PopW r0
	DecW r5

	jmp @secondloop
@end:
	; restore callee-saved r-regs
	PopW r10
	PopW r9
	PopW r8
	PopW r7
	PopW r6
	PopW r5
	PopW r4
	PopW r3
	PopW r2
	PopW r1
	PopW r0
	clc
	rts
