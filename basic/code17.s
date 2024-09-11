getbyt	jsr frmnum
conint	jsr posint
	ldx facmo
	bne gofuc
	ldx faclo
	jmp chrgot

; the "val" function takes a string and turns it into a number by interpreting
; the ascii digits etc. Except for the problem that a terminator must be
; supplied by replacing the character beyond the string, VAL is merely a call
; to floating point input ("finh").
val	jsr len1        ;get length
val_str	bne @1      ;return 0 if len=0
	jmp zerofc
@1:	ldx txtptr      ;save current txtptr
	ldy txtptr+1
	phy
	phx
	ldx index1      ;save current index1
	ldy index1+1
	phy
	phx
	pha
	inc
	beq val_strlong
	jsr strspa     ;allocate memory for string (this destroys index1, but we saved it to stack)
	plx            ;restore saved string length
	pla
	sta index1     ;restore saved index1
	pla
	sta index1+1
	lda dsctmp+1   ;fetch string space pointer
	sta txtptr     ;update txtptr with dsctmp
	lda dsctmp+2
	sta txtptr+1
	ldy #0         ;initalize Y to begin copying the string
@2:	lda (index1),y ;load current byte
	sta (txtptr),y ;store it in allocated memory
	iny
	dex
	bne @2         ;loop until string is copied
	lda #0         ;load null terminator byte
	sta (txtptr),y ;write it to the end of the string
	jsr chrgot
	jsr finh
	plx            ;restore saved txtptr
	ply
	stx txtptr
	sty txtptr+1
	rts            ;done!
st2txt	ldx strng2 ;restore text pointer
	ldy strng2+1
	stx txtptr
	sty txtptr+1
valrts	rts        ;done!
val_strlong	ldx #errls
	jmp error
getnum	jsr frmadr
combyt	jsr chkcom
	jmp getbyt
frmadr	jsr frmnum
getadr0	jsr getadr
	sty poker
	sta poker+1
	rts
peek	jsr getadr0
	lda poker+1
	cmp #$a0
	bcs peek1
	lda (poker)   ;Low RAM
	jmp peek2
peek3	stz ram_bank
	ldx crombank
	lda crambank
	sta ram_bank
	bra peek4
peek1	cmp #$c0
	bcs peek3
	ldx crambank
peek4	ldy #0
	lda #poker	;High RAM or ROM
	jsr fetch
peek2	tay
dosgfl	jmp sngflt
poke	jsr frmadr
	lda poker+1
	pha
	lda poker
	pha
	jsr combyt
	pla
	sta poker
	pla
	sta poker+1
	cmp #$a0
	bcs pokefr
	txa
	sta (poker)
	rts
pokefr2	stz ram_bank
	txa
	ldx crombank
	ldy crambank
	sty ram_bank
	bra pokefr3
pokefr	ldy #poker
	sty stavec
	cmp #$c0
	bcs pokefr2
	txa
	ldx crambank
pokefr3	ldy #0
	jmp stash
fnwait	jsr getnum
	stx andmsk
	ldx #0
	jsr chrgot
	beq stordo
	jsr combyt
stordo	stx eormsk
waiter	lda (poker)
	eor eormsk
	and andmsk
	beq waiter
	rts

;**************************
; routines moved from the
; floating point library
;**************************

inprt	lda #<intxt
	ldy #>intxt
	jsr strout
	lda curlin+1
	ldx curlin
linprt	sta facho
	stx facho+1
	ldx #$90	;exponent of 16.
	sec		;number is positive.
	jsr floatc
	jsr foutc
	jmp strout	;print and return.

movvf	ldx forpnt
	ldy forpnt+1
	jmp movmf

;**************************************
finh	bcc fin	; skip test for 0-9
	cmp #'$'
	beq finh2
	cmp #'%'
	sec	; restore carry flag from before the comparisons; fin uses it
	bne fin
finh2	jmp frmevl
;**************************************

; Floating point input routine.
;
; Number input is left in fac. at entry (txtptr) points to the first character
; in a text buffer. The first character is also in acca. Fin packs the digits
; into the fac as an integer and keeps track of where the decimal point is.
; (dptflg) tells whether a dp has been seen. (deccnt ) is the number of digits
; after the dp. At the end (deccnt) and the exponent are used to determine how
; many times to multiply or divide by ten to get the correct number.

fin
	ldy #0		;zero facsgn&sgnflg.
	ldx #$09+addprc	;zero exp and ho (and moh).

finzlp	sty deccnt,x	;zero mo and lo.
	dex		;zero tenexp and expsgn.
	bpl finzlp	;zero deccnt, dptflg.

	bcc findgq	;flags still set from chrget.
	cmp #'-'	;a negative sign?
	bne qplus	;no, try plus sign.
	stx sgnflg	;it's negative. (x=377).
	beq finc	;always branches.

qplus	cmp #'+'	;plus sign?
	bne fin1	;yes, skip it.

finc	jsr chrget

findgq	bcc findig

fin1	cmp #'.'	;the dp?
	beq findp	;no kidding.
	cmp #'E'	;exponent follows.
	bne fine	;no.
			;here is check for sign of exp.
	jsr chrget	;yes, get another.
	bcc fnedg1	;is it a digit. (easier than backing up pointer).
	cmp #minutk	;minus?
	beq finec1	;negate.
	cmp #'-'	;minus sign?
	beq finec1
	cmp #plustk	;plus?
	beq finec
	cmp #'+'	;plus sign?
	beq finec
	bne finec2

finec1	ror expsgn	;turn it on.

finec	jsr chrget	;get another.

fnedg1	bcc finedg	;it is a digit.
finec2	bit expsgn
	bpl fine
	lda #0
	sec
	sbc tenexp
	jmp fine1

findp	ror dptflg
	bit dptflg
	bvc finc
fine
	lda tenexp
fine1
	sec
	sbc deccnt	;get number of palces to shift.
	sta tenexp
	beq finqng	;negate?
	bpl finmul	;positive, so multiply.
findiv
	jsr div10
	inc tenexp	;done?
	bne findiv	;no.
	beq finqng	;yes.

finmul
	jsr mul10
	dec tenexp	;done?
	bne finmul	;no.
finqng
	lda sgnflg
	bmi negxqs	;if positive, return.
	rts

negxqs
	jmp negop	;oterwise, negate and return.


findig
	pha
	bit dptflg
	bpl findg1
	inc deccnt
findg1
	jsr mul10
	pla		;get it back.
	sec
	sbc #'0'
	jsr finlog	;add it in.
	jmp finc

finedg
	lda tenexp	;get exp so far.
	cmp #10		;will result be .ge. 100
	bcc mlex10
	lda #100
	bit expsgn
	bmi mlexmi	;if neg exp, no chk for overr.
overr	ldx #errov
	jmp error

mlex10
	asl a		;max is 120.
	asl a		;mult by 2 twice.
	clc		;possible shift out of high.
	adc tenexp	;like multiplying by five.
	asl a		;and now by ten.
	clc
	adc (txtptr)
	sec
	sbc #'0'
mlexmi
	sta tenexp	;save result.
	jmp finec


.export val_str
