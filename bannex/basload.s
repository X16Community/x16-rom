.include "kernal.inc"
.include "banks.inc"

.export basload
.import bajsrfar, frmevl, valtyp, fcerr, frefac, index1, basic_fa

.segment "ANNEX"

.proc basload
	; Check input
	beq error
	
	jsr frmevl ; Evaluate input
	bit valtyp
	bmi prepare; Input is a string, try to open file with BASLOAD

error:
	jmp fcerr ; Input was not a string => error

prepare:
	jsr frefac ; Get string
	beq error ; String is empty
	
	; Store len
	sta $02 ; R0L = file name length
	
	; Copy file name
	lda #BANK_KERNAL
	sta $00

	ldy #0
:	lda ($a9),y
	sta $bf00,y
	cpy $02
	beq :+
	iny
	bra :-

	; Set current device, if basic_fa < 8 then use default device 8
:	lda basic_fa
	cmp #8
	bcs :+
	lda #8
:  	sta $03

	; Print "LOADING..."
	ldx #0
:  	lda msg_loading,x
	beq :+
	jsr bsout
	inx
	bra :-

	; Launch BASLOAD
:  	jsr bajsrfar
	.word $c000
	.byte BANK_BASLOAD
	
response:
	; Check if response value != 0
	lda $04
	beq exit

	; Response value != 0 => Error
	ldx #0
:	lda msg_error,x
	beq :+
	jsr bsout
	inx
	bra :-

:  	ldx #0
	stz $00
:  	lda $bf00,x
	beq exit
	jsr bsout
	inx
	bra :-

exit:
	rts

msg_loading:
	.byt "LOADING...",0

msg_error:
	.byt 13, "ERROR: ",0
.endproc
