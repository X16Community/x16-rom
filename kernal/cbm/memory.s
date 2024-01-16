;----------------------------------------------------------------------
; Vectors, Memory
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

.feature labels_without_colons

.include "io.inc"

.import nsave, nload, nclall, ngetin, nstop, nbsout, nbasin, nclrch, nckout, nchkin, nclose, nopen, nnmi, timb, key, cinv, receive_scancode_resume
.import is_65c816, c816_cop_emulated
.importzp tmp2
.export iobase, membot, memtop, restor, vector

.segment "KVAR"

memstr	.res 2           ; start of memory
.assert * = $0259, error, "cc65 depends on MEMSIZ = $0259, change with caution"
memsiz	.res 2           ; top of memory
rambks	.res 1           ; X16: number of ram banks (0 means 256)

.segment "MEMORY"

; restor - set kernal indirects and vectors (system)
;
restor	ldx #<vectss
	ldy #>vectss
	clc
;
; vector - set kernal indirect and vectors (user)
;
vector	stx tmp2
	sty tmp2+1
	ldy #vectse-vectss-1
movos1	lda cinv,y      ;get from storage
	bcs movos2      ;c...want storage to user
	lda (tmp2),y    ;...want user to storage
movos2	sta (tmp2),y    ;put in user
	sta cinv,y      ;put in storage
	dey
	bpl movos1
	rts
;
vectss	.word key,timb,nnmi
	.word nopen,nclose,nchkin
	.word nckout,nclrch,nbasin
	.word nbsout,nstop,ngetin
	.word nclall
	.word receive_scancode_resume
	.word nload,nsave
vectse


memtop	bcc settop
;
;carry set--read top of memory
;
gettop	ldx memsiz
	ldy memsiz+1
	lda rambks
;
;carry clear--set top of memory
;
settop	sta rambks
	stx memsiz
	sty memsiz+1
	rts

;manage bottom of memory
;
membot	bcc setbot
;
;carry set--read bottom of memory
;
	ldx memstr
	ldy memstr+1
;
;carry clear--set bottom of memory
;
setbot	stx memstr
	sty memstr+1
	rts

;
;return address of first 6522
;
iobase
	pha
	php
	pla
	and #4 ; interrupt flag set?
	beq :+
	lda is_65c816
	beq :+
	pla
	jmp c816_cop_emulated
:   pla
	ldx #<via1
	ldy #>via1
	rts
