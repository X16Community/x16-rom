.include "../geos/inc/geosmac.inc"
.include "../geos/inc/geossym.inc"
.include "../geos/inc/const.inc"
.include "../geos/inc/jumptab.inc"

.setcpu "65c02"

; from KERNAL
; XXX TODO these should go through the jump table
.import scrmod
.import GRAPH_draw_line, GRAPH_draw_rect, GRAPH_draw_frame, GRAPH_start_direct, GRAPH_set_pixel
.import k_UseSystemFont, GRAPH_put_char


; from GEOS
.import _ResetHandle, GRAPH_set_colors

x1L	=r0L
x1H	=r0H
y1L	=r1L
y1H	=r1H
x2L	=r2L
x2H	=r2H
y2L	=r3L
y2H	=r3H

;***************
geos	jsr bjsrfar
	.word _ResetHandle
	.byte BANK_GEOS

;***************
cscreen
	jsr getbyt
	txa
	sec
	jsr bjsrfar
	.word scrmod ; switch to 320x240@256c + 40x30 text
	.byte BANK_KERNAL
	bcc :+
	jmp fcerr
:	rts

;***************
pset:	jsr get_point
	jsr get_col
	pha
	sei
	jsr bjsrfar
	.word GRAPH_start_direct
	.byte BANK_KERNAL
	pla
	jsr bjsrfar
	.word GRAPH_set_pixel
	.byte BANK_KERNAL
	cli
	rts

;***************
line	jsr get_points_col
	lda #0 ; set
	sei
	jsr bjsrfar
	.word GRAPH_draw_line
	.byte BANK_KERNAL
	cli
	rts

;***************
frame	jsr get_points_col
	jsr normalize_rect
	sei
	jsr bjsrfar
	.word GRAPH_draw_frame
	.byte BANK_KERNAL
	cli
	rts

;***************
rect	jsr get_points_col
	jsr normalize_rect
	sei
	jsr bjsrfar
	.word GRAPH_draw_rect
	.byte BANK_KERNAL
	cli
	rts

;***************
char	jsr get_point

	jsr chkcom
	jsr getbyt
	txa
	jsr set_col

	jsr chkcom
	jsr frmevl
	jsr chkstr

	ldy #0
	lda (facmo),y
	sta r14L ; length
	iny
	lda (facmo),y
	sta r15L ; pointer lo
	iny
	lda (facmo),y
	sta r15H ; pointer hi

	sei
	lda #$92 ; Ctrl+0: clear attributes
	jsr bjsrfar
	.word GRAPH_put_char
	.byte BANK_KERNAL
	cli

	ldy #0
:	lda (r15),y
	phy
	jsr bjsrfar
	.word GRAPH_put_char
	.byte BANK_KERNAL
	ply
	iny
	cpy r14L
	bne :-

	jmp frefac

linfc	jmp fcerr

get_point:
	jsr frmadr
	lda poker
	sta x1L
	sec
	sbc #<320
	lda poker+1
	sta x1H
	sbc #>320
	bcs linfc
	jsr chkcom
	jsr frmadr
	lda poker
	sta y1L
	sec
	sbc #<200
	lda poker+1
	sta y1H
	sbc #>200
	bcs linfc
	rts

get_col:
	ldy #0
	lda (txtptr),y
	bne @1
	lda #0
	rts
@1:	jsr chkcom
	jsr getbyt
	txa
	rts

set_col:
	ldx #15 ; secondary color:  light gray
	ldy #1  ; background color: white
	sei
	jsr bjsrfar
	.word GRAPH_set_colors
	.byte BANK_KERNAL
	cli
	rts

get_points_col:
; get x1,y1,x2,y2 into r0,r1,r2,r3
	jsr get_point
	jsr chkcom
	jsr frmadr
	lda poker
	sta x2L
	sec
	sbc #<320
	lda poker+1
	sta x2H
	sbc #>320
	bcs linfc
	jsr chkcom
	jsr frmadr
	lda poker
	sta y2L
	sec
	sbc #<200
	lda poker+1
	sta y2H
	sbc #>200
	bcs linfc

	jsr get_col
	jmp set_col

@2	jmp snerr

normalize_rect:
; make sure y2 >= y1
	lda y2L
	cmp y1L
	bcs @1
	ldx y1L
	stx y2L
	sta y1L
; make sure x2 >= x1
@1:	lda x2L
	sec
	sbc x1L
	lda x2H
	sbc x1H
	bcs @2
	lda x1L
	ldx x2L
	stx x1L
	sta x2L
	lda x1H
	ldx x2H
	stx x1H
	sta x2H
@2:	rts
