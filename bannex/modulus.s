
.import chkcom
.import chkopn
.import chkcls
.import chrget
.import givayf0
.import frmnum
.import ayint

.importzp fac

.export mod

dividend = fac
divisor = fac+2
divsign = fac+4

.proc mod: near
	jsr chrget
	jsr chkopn
	; Get dividend and save on stack
	jsr frmnum
	jsr ayint
	lda fac+3
	pha
	lda fac+4
	pha
	jsr chkcom
	; Get Divisor and save it in the floating point accumulator
	jsr frmnum
	jsr ayint
	lda fac+3
	ldy fac+4
	; Borrow floating point accumulator for calculations
	sty divisor
	sta divisor+1
	pla
	sta dividend
	pla
	sta dividend+1

	jsr chkcls
	; Calculate remainder by simple subtraction loop
	jsr mod_calculate

	; Load result into A and Y to be returned
	lda dividend+1
	ldy dividend
	jmp givayf0
.endproc

.proc mod_calculate: near
	lda divisor+1		; Check if Divisor is positive
	bpl check_zero
	eor #$FF		; Negate if negative
	sta divisor+1
	lda divisor
	eor #$FF
	sta divisor
	inc divisor
	bne check_zero
	inc divisor+1
check_zero:			; Check if Divisor is 0
	lda divisor
	ora divisor+1
	beq div_by_zero		; Handle division by zero

	lda dividend+1		; Check and save sign of Dividend
	sta divsign
	bpl subloop
	eor #$FF		; Negate Dividend if it is negative
	sta dividend+1
	lda dividend
	eor #$FF
	sta dividend
	inc dividend
	bne subloop
	inc dividend+1

subloop:
	lda dividend+1		; Compare high bytes
	cmp divisor+1
	bcc restore_sign	; If Dividend+1 is less than Divisor+1 then remainder is less than dividend
	bne perform_sub		; If Dividend+1 is more thatn Divisor+1 then remainder >= dividend, subtract
	lda dividend
	cmp divisor
	bcc restore_sign	; If Dividend is less than Divisor then remainder is less than dividend
perform_sub:
	sec
	lda dividend
	sbc divisor
	sta dividend
	lda dividend+1
	sbc divisor+1
	sta dividend+1
	bra subloop

restore_sign:
	lda divsign
	bpl end
	lda dividend
	eor #$FF
	sta dividend
	lda dividend+1
	eor #$FF
	sta dividend+1
	inc dividend
	bne end
	inc dividend+1
end:	rts
div_by_zero:
	stz dividend
	stz dividend+1
	rts
.endproc