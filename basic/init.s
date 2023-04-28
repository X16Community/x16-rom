.macro bannex_call addr
    jsr bjsrfar
    .word addr
    .byte BANK_BANNEX
.endmacro

.include "bannex.inc"

panic	jsr clschn      ;warm start basic...
	lda #0          ;clear channels
	sta channl
	jsr stkini      ;restore stack
	cli             ;enable irq's

ready	ldx #$80
	jmp (ierror)
nerror	txa             ;get  high bit
	bmi nready
	jmp nerrox
nready	jmp readyx

init	jsr initv       ;go init vectors
	jsr initcz      ;go init charget & z-page
	jsr initms      ;go print initilization messages
	stz ram_bank
	stz crombank     ;set default value for BANK statement (ROM)
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
	lda #<btrfly
	ldy #>btrfly
	jsr strout
	bannex_call bannex_screen_default_color_from_nvram
	; position for ram count
	ldy #8
	ldx #3
	clc
	jsr plot
	sec
	jsr $ff99       ;read num ram banks
	tax
	bne initm2
	ldx #<2048
	lda #>2048
	bne initm3
initm2	sta facho
	lda #0
	asl facho
	rol
	asl facho
	rol
	asl facho
	rol
	ldx facho
initm3	jsr linprt
	jsr screen
	cpx #40
	bcc inib40

	lda #<l4msg40
	ldy #>l4msg40
	jsr strout

	ldy #8
	ldx #1
	clc
	jsr plot

	lda #<l2msg40
	ldy #>l2msg40
	jsr strout

	ldy #8
	ldx #5
	clc
	jsr plot

	lda memsiz
	sec
	sbc txttab
	tax
	lda memsiz+1
	sbc txttab+1
	jsr linprt

	lda #<l6msg40
	ldy #>l6msg40
	jsr strout

	bra iniend
inib40 ; screen is smaller than 40, use compact banner
	lda #<l4msg20
	ldy #>l4msg20
	jsr strout

	ldy #8
	ldx #1
	clc
	jsr plot

	lda #<l2msg20
	ldy #>l2msg20
	jsr strout

	ldy #8
	ldx #2
	clc
	jsr plot

	lda #<l3msg20
	ldy #>l3msg20
	jsr strout

	ldy #8
	ldx #4
	clc
	jsr plot

	lda #<l5msg20
	ldy #>l5msg20
	jsr strout

	ldy #8
	ldx #5
	clc
	jsr plot

	lda memsiz
	sec
	sbc txttab
	tax
	lda memsiz+1
	sbc txttab+1
	jsr linprt

	lda #<l6msg20
	ldy #>l6msg20
	jsr strout

	ldy #8
	ldx #6
	clc
	jsr plot

	lda #<l7msg20
	ldy #>l7msg20
	jsr strout
iniend
	ldy #0
	ldx #7
	clc
	jsr plot

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

btrfly
	.byt $8f, $93
	; line 0
	.byt $9c, $12, $df, $92, "     ", $12, $a9
	.byt $0d
	; line 1
	.byt $9a, $12, $b4, $df, $92, "   ", $12, $a9, $a7, $92
	.byt $0d
	; line 2
	.byt $9f, $12, $b5, " ", $df, $92, " ", $12, $a9, " ", $b6
	.byt $0d
	; line 3
	.byt $1e, " ", $b7, $12, $bb, $92, " ", $12, $ac, $92, $b7
	.byt $0d
	; line 4
	.byt $9e, " ", $af, $12, $be, $92, " ", $12, $bc, $92, $af
	.byt $0d
	; line 5
	.byt $81, $a7, $12, " ", $92, $a9, " ", $df, $12, " ", $92, $b4
	.byt $0d
	; line 6
	.byt $1c, $b6, $a9, "   ", $df, $b5
	.byt $0d
	.byt 5
	.byt 0


l2msg40
	.byte "**** COMMANDER X16 BASIC V2 ****",0
l2msg20
	.byte "COMMANDER",0
l3msg20
	.byte "X16 BASIC V2",0

l4msg40
	.byte "K HIGH RAM"
.ifdef PRERELEASE_VERSION
	.byte " - ROM VER R"
.if PRERELEASE_VERSION >= 100
	.byte (PRERELEASE_VERSION / 100) + '0'
.endif
.if PRERELEASE_VERSION >= 10
	.byte ((PRERELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (PRERELEASE_VERSION .mod 10) + '0'
.else
	.byte " - GIT "
	.incbin "../build/signature.bin"
.endif
	.byte 0

l4msg20
	.byte "K HI RAM",0
l5msg20
.ifdef PRERELEASE_VERSION
	.byte "ROM VER R"
.if PRERELEASE_VERSION >= 100
	.byte (PRERELEASE_VERSION / 100) + '0'
.endif
.if PRERELEASE_VERSION >= 10
	.byte ((PRERELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (PRERELEASE_VERSION .mod 10) + '0'
.else
	.incbin "../build/signature.bin"
.endif
	.byte 0

l6msg40
	.byte " BASIC BYTES FREE",0
l6msg20
	.byte " BASIC",0
l7msg20
	.byte "BYTES FREE",0

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
