omerr	ldx #errom
error	jmp (ierror)
nerrox	txa
	asl a
	tax
	lda errtab-2,x
	sta index1
	lda errtab-1,x
	sta index1+1
	jsr clschn
	lda #0
	sta channl
errcrd	jsr crdo
	jsr outqst
	ldy #0
geterr	lda (index1),y
	pha
	and #127
	jsr outdo
	iny
	pla
	bpl geterr
	jsr stkini
	lda #<err
	ldy #>err
errfin	jsr strout
	ldy curlin+1
	iny
	beq readyx
	jsr inprt

readyx	lda #<reddy
	ldy #>reddy
	jsr strout
	lda #$80        ;direct messages on
	jsr setmsg      ;from kernal

main	jsr clear_4080_flag
	jmp (imain)
nmain	stz ram_bank
	lda exec_flag
	beq @1
	lda exec_addr
	sta poker
	lda exec_addr+1
	sta poker+1
	lda exec_bank
	sta ram_bank
	ldy #1
	ldx #0
@e0	lda (poker)
	pha
	inc poker
	bne @eb
	lda poker+1
	inc
	cmp #$c0
	bcc @ea
	sbc #$20
	inc ram_bank
@ea	sta poker+1
@eb	pla
	beq @e1
	cmp #10
	beq @e2
	cmp #13
	beq @e2
	sta buf,x
	jsr bsout
	inx
	cpx #buflen
	bcc @e0
	bra @esl
@e1	ldy #0
@e2	lda #13
	jsr bsout
	stz buf,x
	lda ram_bank
	stz ram_bank
	sty exec_flag
	sta exec_bank
	lda poker
	sta exec_addr
	lda poker+1
	sta exec_addr+1
	jsr stop
	bne @e3
	ldx #erbrk
	bra @err
@e3	lda crambank
	sta ram_bank
	ldx #<zz5
	ldy #>zz5
	bra @2
@1	lda crambank
	sta ram_bank
	jsr inlin
@2	stx txtptr
	sty txtptr+1
	jsr chrget
	tax
	beq @3
	ldx #255
	stx curlin+1
	bcc main1
	jsr chkdosw
	jsr crunch
	jmp gone
@3	jmp main
@esl	ldx #errls
@err	stz ram_bank
	stz exec_flag
	lda crambank
	sta ram_bank
	jmp error
main1	jsr linget
	jsr crunch
	sty count
	jsr fndlin
	bcc nodel
	ldy #1
	lda (lowtr),y
	sta index1+1
	lda vartab
	sta index1
	lda lowtr+1
	sta index2+1
	lda lowtr
	dey
	sbc (lowtr),y 
	clc
	adc vartab
	sta vartab
	sta index2
	lda vartab+1
	adc #255
	sta vartab+1
	sbc lowtr+1
	tax
	sec
	lda lowtr
	sbc vartab
	tay
	bcs qdect1
	inx
	dec index2+1
qdect1	clc
	adc index1
	bcc mloop
	dec index1+1
	clc
mloop	lda (index1),y
	sta (index2),y
	iny 
	bne mloop
	inc index1+1
	inc index2+1
	dex
	bne mloop
nodel	jsr runc
	jsr lnkprg
	lda buf
	bne :+
	jmp main
:	clc
	lda vartab
	sta hightr 
	adc count
	sta highds
	ldy vartab+1
	sty hightr+1
	bcc nodelc
	iny
nodelc	sty highds+1
	jsr bltu
	lda linnum
	ldy linnum+1
	sta buf-2
	sty buf-1
	lda strend
	ldy strend+1
	sta vartab
	sty vartab+1
	ldy count
	dey
stolop	lda buf-4,y
	sta (lowtr),y
	dey
	bpl stolop
fini	jsr runc
	jsr lnkprg
	jmp main
lnkprg	lda txttab
	ldy txttab+1
	sta index
	sty index+1
	clc 
chead	ldy #1
	lda (index),y
	beq lnkrts
	ldy #4
czloop	iny
	lda (index),y
	bne czloop
	iny
	tya
	adc index
	tax
	ldy #0
	sta (index),y
	lda index+1
	adc #0
	iny
	sta (index),y
	stx index
	sta index+1
	bcc chead
lnkrts	rts

;function to get a line one character at
;a time from the input channel and
;build it in the input buffer.
;
inlin	ldx #0
;
inlinc	jsr inchr
	cmp #13         ;a carriage return?
	beq finin1      ;yes...done build
;
	sta buf,x       ;put it away
	inx
	cpx #buflen     ;max character line?
	bcc inlinc      ;no...o.k.
;
	ldx #errls      ;string too long error
	jmp error
;
finin1	jmp fininl

