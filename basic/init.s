.macro bannex_call addr
	jsr bjsrfar
	.word addr
	.byte BANK_BANNEX
.endmacro

.include "bannex.inc"

panic	lda is_65c816
	beq pn65c816
	sec
	.byte $FB       ; xce
	clc
pn65c816	jsr clschn      ;warm start basic...
	lda #0          ;clear channels
	sta channl
	jsr stkini      ;restore stack
	lda ram_bank
	stz ram_bank
	stz exec_flag
	sta ram_bank
	cli             ;enable irq's

ready	ldx #$80
	jmp (ierror)
nerror	txa             ;get  high bit
	bmi nready
	jmp nerrox
nready	jmp readyx

init	lda is_65c816
	beq in65c816
	sec
	.byte $FB       ; xce
	clc
in65c816	jsr initv       ;go init vectors
	jsr initcz      ;go init charget & z-page
	jsr initms      ;go print initilization messages
	stz ram_bank
	stz crombank     ;set default value for BANK statement (ROM)
	stz exec_flag
	ldx #1
	stx crambank     ;set default value for BANK statement (RAM)
	stx ram_bank
init2	ldx #stkend-256 ;set up end of stack
	txs
boot	lda #0
	jsr setmsg
	ldx #bootfnlen-1
:	lda bootfn,x
	sta buf,x
	dex
	bpl :-
	ldx #<buf
	ldy #>buf
	lda #bootfnlen
	jsr setnam
	jsr getfa
	tax
	lda #1
	ldy #1
	jsr setlfs
	lda #0
	jsr load
	jsr readst
	and #$ff-$40 ; any error but EOI?
	beq :+       ; no
	jsr clear_disk_status
	jmp ready
:	stx vartab
	sty vartab+1    ;end load address
	jsr lnkprg
	jsr crdo
	jsr runc
	jmp newstt
bootfn:
	.byte "AUTOBOOT.X16"
bootfnlen=*-bootfn

initat	inc chrget+7
	bne chdgot
	inc chrget+8
chdgot	lda 60000
	cmp #':'
	bcs chdrts
	cmp #' '
	beq initat
	sec
	sbc #'0'
	sec
	sbc #$d0
chdrts	rts
inrndx	.byt 128,79,199,82,88

initcz	lda #76
	sta jmper
	sta usrpok
	lda #<fcerr
	ldy #>fcerr
	sta usrpok+1
	sty usrpok+2
	ldx #inrndx-initat-1
movchg	lda initat,x
	sta chrget,x
	dex
	bpl movchg
	ldx #initcz-inrndx-1
movch2	lda inrndx,x
	sta rndx,x
	dex
	bpl movch2
	lda #strsiz
	sta four6
	lda #0
	sta bits
	sta channl
	sta lastpt      ;fix for GC bug: https://c65gs.blogspot.com/2021/03/guest-post-from-bitshifter-fixing.html
	sta lastpt+1
	ldx #1
	stx buf-3
	stx buf-4
	ldx #tempst
	stx temppt
	sec             ;read bottom of memory
	jsr $ff9c
	stx txttab      ;now txtab has it
	sty txttab+1
	sec
	jsr $ff99       ;read top of memory
usedef	stx memsiz
	sty memsiz+1
	stx fretop
	sty fretop+1
	ldy #0
	tya
	sta (txttab),y
	inc txttab
	bne init20
	inc txttab+1
init20	rts

initms	lda txttab
	ldy txttab+1
	jsr reason

	bannex_call bannex_splash

	jmp scrtch

bvtrs	.word nerror,nmain,ncrnch,nqplop,ngone,neval
;
initv	ldx #initv-bvtrs-1 ;init vectors
initv1	lda bvtrs,x
	sta ierror,x
	dex
	bpl initv1
	rts
chke0	.byt $00



; ppach - print# patch to coout (save .a)
;
ppach	pha
	jsr $ffc9
	tax             ;save error code
	pla
	bcc ppach0      ;no error....
	txa             ;error code
ppach0	rts

;rsr 8/10/80 update panic :rem could use in error routine
;rsr 2/08/82 modify for vic-40 release
;rsr 4/15/82 add advertising sign-on
