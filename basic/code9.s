	bmi docstr
	bcs chkerr
chkok	rts
docstr	bcs chkok
chkerr	ldx #errtm
errgo4	jmp error
frmevl	ldx txtptr
	bne frmev1
	dec txtptr+1
frmev1	dec txtptr
	ldx #0
	.byt $24
lpoper	pha
	txa
	pha
	lda #1
	jsr getstk
	jsr eval
	lda #0
	sta opmask
tstop	jsr chrgot
loprel	sec
	sbc #greatk
	bcc endrel
	cmp #lesstk-greatk+1
	bcs endrel
	cmp #1
	rol a
	eor #1
	eor opmask
	cmp opmask
	bcc snerr5
	sta opmask
	jsr chrget
	jmp loprel
endrel	ldx opmask
	bne finrel
	bcc nqop
	jmp qop
nqop	adc #greatk-plustk
	bcc qop
	adc valtyp
	bne *+5
	jmp cat
	adc #$ff
	sta index1
	asl a
	adc index1
	tay 
qprec	pla
	cmp optab,y
	bcs qchnum
	jsr chknum
doprec	pha
negprc	jsr dopre1
	pla
	ldy opptr
	bpl qprec1
	tax
	beq qopgo
	bne pulstk
finrel	lsr valtyp
	txa
	rol a
	ldx txtptr
	bne finre2
	dec txtptr+1
finre2	dec txtptr
	ldy #ptdorl-optab
	sta opmask
	bne qprec
qprec1	cmp optab,y
	bcs pulstk
	bcc doprec
dopre1	lda optab+2,y
	pha
	lda optab+1,y
	pha
	jsr pushf1
	lda opmask
	jmp lpoper
snerr5	jmp snerr
pushf1	lda facsgn
	ldx optab,y
pushf	tay
	pla
	sta index1
	inc index1
	pla
	sta index1+1
	tya
	pha
forpsh	jsr round
	lda faclo
	pha
	lda facmo
	pha
	lda facmoh
	pha
	lda facho
	pha
	lda facexp
	pha
	jmp (index1)
qop	ldy #255
	pla
qopgo	beq qoprts
qchnum	cmp #100
	beq unpstk
	jsr chknum
unpstk	sty opptr
pulstk	pla
	lsr a
	sta domask
	pla
	sta argexp
	pla
	sta argho
	pla
	sta argmoh
	pla
	sta argmo
	pla
	sta arglo
	pla
	sta argsgn
	eor facsgn
	sta arisgn
qoprts	lda facexp
unprts	rts

eval	jmp (ieval)
neval	lda #0
	sta valtyp
eval0	jsr chrget
	bcs eval2
eval1	jmp fin
eval2
;**************************************
; hex literal input
;**************************************
	cmp #'$'
	bne evalh0
	lda #16         ;base 16
	pha
	lda #4          ;shift 4
	bne evalhx
evalh0	cmp #'%'
	bne evalb0
	lda #2          ;base 2
	pha
	lda #1          ;shift 1
evalhx	ldy #$00        ;[same code as in "fin"]
	ldx #$09+addprc ;[same code as in "fin"]
evalh1	sty deccnt,x    ;[same code as in "fin"]
	dex             ;[same code as in "fin"]
	bpl evalh1      ;[same code as in "fin"]
	sta lowtr+1     ;shift
	pla
	sta lowtr       ;base
evalh2	jsr chrget
	bcc evalh3      ;digit? ok
	cmp #'A'
	bcc evalh6      ;non-alpha? done
	cmp #'Z'+1
	bcs evalh6      ;non-alpha? done
evalh7	sbc #7
evalh3	sbc #$2f        ;convert to value
	cmp lowtr       ;base
	bcc evalh9
	jmp snerr
evalh9	pha
	lda facexp
	beq evalh5
	adc lowtr+1     ;shift
	bcc evalh4
	jmp overr
evalh4	sta fac
evalh5	pla
	jsr finlog      ;add .a to fac
	jmp evalh2
evalh6	clc
	rts
evalb0
;**************************************
	jsr isletc
	bcc *+5
	jmp isvar
	cmp #pi
	bne qdot
	lda #<pival
	ldy #>pival
	jsr movfm
	jmp chrget
pival	.byt $82
	.byt $49
	.byt $0f
	.byt $da
	.byt $a2
qdot	cmp #'.'
	beq eval1
	cmp #minutk
	beq domin
	cmp #plustk
	beq eval0
	cmp #34
	bne eval3
strtxt	lda txtptr
	ldy txtptr+1
	adc #0
	bcc strtx2
	iny
strtx2	jsr strlit
	jmp st2txt
eval3	cmp #nottk
	bne eval4
	ldy #24
	bne gonprc
notop	jsr ayint
	lda faclo
	eor #255
	tay
	lda facmo
	eor #255
	jmp givayf0
eval4	cmp #fntk
	bne *+5
	jmp fndoer
	cmp #onefun
	bcc parchk
	jmp isfun
parchk	jsr chkopn
	jsr frmevl
chkcls	lda #41
	bra synchr
chkopn	lda #40
	bra synchr
chkcom	lda #44
synchr	ldy #0
	cmp (txtptr),y
	bne snerr
	jmp chrget
snerr	ldx #errsn
	jmp error
domin	ldy #21
gonprc	pla
	pla
	jmp negprc
