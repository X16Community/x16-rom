.include "banks.inc"

.export x16edit
.import bajsrfar, frmevl, valtyp, fcerr, frefac, index1

.segment "ANNEX"

.proc x16edit
	beq new ; No input param, open editor with a new empty buffer
	jsr frmevl ; Evaluate input
	bit valtyp
	bmi file ; Input is a string, try to open file in the editor

error:
	jmp fcerr ; Input was not a string => error

file:
	jsr frefac ; Get string
	beq new ; String is empty, open new empty buffer
	
	sta $04 ; R1L = file name length
	lda index1
	sta $02 ; R0L = file name address low
	lda index1+1
	sta $03 ; R0H = file name address high
	ldx #10 ; First RAM bank used by the editor
	ldy #255 ; Last RAM bank used by the editor
	
	jsr bajsrfar
	.word $C003
	.byte BANK_X16EDIT
	rts

new:
	ldx #10 ; First RAM bank used by the editor
	ldy #255 ; Last RAM bank used by the editor
	stz $04 ; R1L = file name length, 0 => no file
	jsr bajsrfar
	.word $C003
	.byte BANK_X16EDIT
	rts
.endproc
