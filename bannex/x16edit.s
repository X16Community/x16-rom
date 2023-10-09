.include "banks.inc"

.export x16edit
.import bajsrfar, frmevl, valtyp, fcerr, frefac, index1, basic_fa

.segment "ANNEX"

.proc x16edit
	beq new ; No input param, open editor with a new empty buffer
	jsr frmevl ; Evaluate input
	bit valtyp
	bmi set_file ; Input is a string, try to open file in the editor

error:
	jmp fcerr ; Input was not a string => error

set_file:
	jsr frefac ; Get string
	beq new ; String is empty, open new empty buffer
	
	sta $04 ; R1L = file name length
	lda index1
	sta $02 ; R0L = file name address low
	lda index1+1
	sta $03 ; R0H = file name address high
	bra launch

new:
	stz $04 ; R1L = file name length, 0 => no file

launch:
	ldx #10 ; First RAM bank used by the editor
	ldy #255 ; Last RAM bank used by the editor
	stz $05 ; Default value: Auto-indent and word
	stz $06 ; Default value: Tab stop width
	stz $07 ; Default value: Word wrap position
	lda basic_fa 
	sta $08 ; Set current active device number
	stz $09 ; Default value: text/background
	stz $0a ; Default value: header
	stz $0b ; Default value: status bar

	jsr bajsrfar
	.word $C006
	.byte BANK_X16EDIT
	rts


.endproc
