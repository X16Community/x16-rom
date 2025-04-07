
.include "regs.inc"
.include "machine.inc"

.import xmacptr
.import get_machine_type

clear_status:
	stz status
	rts

extapi_getlfs:
	lda la
	ldx fa
	ldy sa
	rts

.pushcpu
.setcpu "65816"

; XLOAD


; HBLOAD
; inputs
;   .X=0, LOAD; .X=1, VERIFY
;   r0L-r1L: target address
;   fnadr+fnlen: filename pointer (via setnam)
;   fa: device (via setlfs)
; outputs
;   returns m=1, x=1
;   if error, c=1 and .A has error type
;   normal load, c=0, .A=0, r0L-r1L=next address
;   r1H is zeroed
hbload:
	sep #$30 ; 8 bit mem/idx
.A8
.I8
	stx verck
	jsr get_machine_type
	bit #MACHINE_TYPE_FLAT24
	bne @1
	lda #ERROR_MACHINE_TYPE
	sec
	rts
@1:
	stz r1H
	lda r1L
	bne @2
	; fall back to original load routine
	; if caller requests databank 0
	lda #2
	sta sa
	ldx r0L
	ldy r0H
	lda #0
	jsr nload
	stx r0L
	sty r0H
	rts
@2:
	jsr luking      ;tell user looking
	lda #$60        ;special load command
	sta sa
	jsr openi       ;open the file

	lda fa
	jsr talk        ;establish the channel
	lda sa
	jsr tksa        ;tell it to load

	jsr loding24    ;say loading

	lda #$80        ;indicate first block
	sta tmp2

	ldy verck
	bne hbl61
hbl10:
	jsr stop
	bne @0
	jmp break
@0:
	rep #$30
.A16
.I16
	stz r2          ;load as much as possible
	jsr xmacptr
	bcs hbl60
	lda r2
	bne @1
	inc r1
@1:
	adc r0
	sta r0
	bcc @2
	inc r1
@2:
	sep #$30
.A8
.I8
	bit status
	bvc hbl10      ;not EOI yet
	bra hbl80

hbl60:
	sep #$30
.A8
.I8
hbl61:
	lda #3
	trb status
	jsr stop
	bne hbl65
	jmp break
hbl65:
	jsr acptr
	tax
	lda status
	lsr
	lsr
	bcc hbl70      ;no timeout
	asl tmp2
	bcc hbl61
	jmp error4     ;file not found
hbl70:
	txa
	ldy verck
	bne hbl90
	sta [r0]
hbl75:
	inc r0L
	bne @1
	inc r0H
	bne @1
	inc r1L
@1:
	bit status
	bvc hbl61
hbl80:
	jsr untlk
	jsr clsei
	jsr prnto24

	lda #0
	clc
	rts

hbl90:            ;verify
	cmp [r0]
	beq hbl75
	lda #16
	jsr udst
	bra hbl80

.popcpu


;subroutine to print:
;
;loading/verifing (24 bit address version)
;
loding24:
	ldy #ms10-ms1   ;assume 'loading'
	lda verck       ;check flag
	beq ld2410      ;are doing load
	ldy #ms21-ms1   ;are 'verifying'
ld2410:
	jsr spmsg
	bit msgflg      ;printing messages?
	bpl l24rts      ;no...
	lda verck       ;check flag
	bne l24rts      ;skip if verify
	ldy #ms7-ms1    ;"from $"
msghex24:
	jsr msg
	lda r1L
	jsr hex8
	lda r0H
	jsr hex8
	lda r0L
	jmp hex8
l24rts:
	rts
prnto24:
	bit msgflg      ;printing messages?
	bpl l24rts      ;no...
	lda verck       ;check flag
	bne l24rts      ;skip if verify
	ldy #ms8-ms1    ;"to $"
	bra msghex24
