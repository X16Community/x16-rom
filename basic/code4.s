newstt	jsr iscntc
	lda txtptr
	ldy txtptr+1
	cpy #bufpag
	beq dircon
	sta oldtxt
	sty oldtxt+1
dircon	ldy #0
	lda (txtptr),y
	bne morsts
	ldy #2
	lda (txtptr),y
	clc
	bne dircn1
	jmp endcon
dircn1	iny
	lda (txtptr),y
	sta curlin
	iny
	lda (txtptr),y
	sta curlin+1
	tya
	adc txtptr
	sta txtptr
	bcc gone
	inc txtptr+1
gone	jmp (igone)
ngone	jsr chrget
ngone1	jsr gone3
	jmp newstt
gone3	beq iscrts
gone2
;**************************************
; new statement execution
;**************************************
	cmp #$ce ; escape token
	bne nesct2
	jsr chrget
	sbc #$80
	bcc snerrx
	cmp #num_esc_statements
	bcs snerrx
	asl a
	tay
	lda stmdsp2+1,y
	pha
	lda stmdsp2,y
	jmp gone4
nesct2:
	sec
;**************************************
	sbc #endtk
	bcc glet
	cmp #scratk-endtk+1
	bcs snerrx
	asl a
	tay
	lda stmdsp+1,y
	pha
	lda stmdsp,y
gone4	pha
	jmp chrget
glet	jmp let
morsts	cmp #':'
	beq gone
snerr1	jmp snerr
snerrx	cmp #gotk-endtk
	bne snerr1
	jsr chrget
	lda #totk
	jsr synchr
	jmp goto
restor	beq restor2 ; no argument, do BASIC 2 behavior
	jsr linget ; otherwise get line number argument
	jsr fndlin ; search for its address (slow, always from the beginning)
	bcc resterr ; couldn't find?
	lda lowtr ; set the data ptr to the byte before the found line
	sbc #1
	sta datptr
	lda lowtr+1
	sbc #0
	sta datptr+1
	rts
resterr
	ldx #errus
	jmp error
restor2
	sec
	lda txttab
	sbc #1
	ldy txttab+1
	bcs resfin
	dey
resfin	sta datptr
	sty datptr+1
iscrts	rts
iscntc	jsr $ffe1
cstop	bcs stopc
end	clc
stopc	bne contrt
	lda txtptr
	ldy txtptr+1
	ldx curlin+1
	inx
	beq diris
	sta oldtxt
	sty oldtxt+1
stpend	lda curlin
	ldy curlin+1
	sta oldlin
	sty oldlin+1
diris	pla
	pla
endcon	lda #<brktxt
	ldy #>brktxt
	bcc gordy
	jmp errfin
gordy	jmp ready
cont	bne contrt
	ldx #errcn
	ldy oldtxt+1
	bne *+5
	jmp error
	lda oldtxt
	sta txtptr
	sty txtptr+1
	lda oldlin
	ldy oldlin+1
	sta curlin
	sty curlin+1
contrt	rts
run	php
	lda #0          ;no kernal messages
	jsr setmsg
	plp
	bne *+5
	jmp runc
	jsr clearc
	jmp runc2
gosub	lda #3
	jsr getstk
	lda txtptr+1
	pha
	lda txtptr
	pha
	lda curlin+1
	pha
	lda curlin
	pha
	lda #gosutk
	pha
runc2	jsr chrgot
	jsr goto
	jmp newstt
goto	jsr linget
	jsr remn
	sec
	lda curlin
	sbc linnum
	lda curlin+1
	sbc linnum+1
	bcs luk4it
	tya
	sec
	adc txtptr
	ldx txtptr+1
	bcc lukall
	inx
	bcs lukall
luk4it	lda txttab
	ldx txttab+1
lukall	jsr fndlnc
	bcc userr
	lda lowtr
	sbc #1

