
.include "regs.inc"
.include "machine.inc"

.import has_machine_property

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

; HBLOAD
; inputs
;   .X=0, LOAD; .X=1, VERIFY
;   r0L-r1L: target address
;   fnadr+fnlen: filename pointer (via setnam)
;   fa: device (via setlfs)
; outputs
;   returns m=0, x=0
;   if error, c=1 and .A has error type
;   normal load, c=0, .A=0, r0L-r1L=next address
;   r1H is zeroed
hbload:
	sep #$30 ; 8 bit mem/idx
.A8
.I8
	stx verck
	ldx #MACHINE_PROPERTY_FAR
	jsr has_machine_property
	bcs @1
	lda #ERROR_MACHINE_PROPERTY
	sec
	rep #$30 ; affects only the return
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
	lda verck
	jsr nload
	stx r0L
	sty r0H
	rep #$30        ;mx=0 to exit extapi16
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
	bne hbl_byteloop
hbl_blockloop:
	jsr stop
	bne @1
	jmp break
@1:
	rep #$30
.A16
.I16
	stz r2            ;load as much as possible
	lda #5            ;EXTAPI16_XMACPTR
	jsr extapi16      ;we're using extapi16 here so that the emulator can intercept the call
	bcs hbl_enter_byteloop
	lda r2
	bne @2
	inc r1
@2:
	adc r0            ;carry is already clear
	sta r0
	bcc @3
	inc r1
@3:
	sep #$30
.A8
.I8
	bit status
	bvc hbl_blockloop ;not EOI yet
	bra hbl_end

hbl_enter_byteloop:
	sep #$30
.A8
.I8
hbl_byteloop:         ;this is the bytewise read or verify loop
	lda #3
	trb status
	jsr stop
	bne @1
	jmp break
@1:
	jsr acptr
	tax
	lda status
	lsr
	lsr
	bcc @2            ;no timeout
	asl tmp2
	bcc hbl_byteloop
	jmp error4        ;file not found
@2:
	txa
	ldy verck
	bne hbl_verify_byte
	sta [r0]
hbl_inc_ptr:
	inc r0L
	bne @1
	inc r0H
	bne @1
	inc r1L
@1:
	bit status
	bvc hbl_byteloop
hbl_end:
	jsr untlk
	jsr clsei
	jsr prnto24

	lda #0
	rep #$31          ;mx=0, clc, affects only the return
	rts

hbl_verify_byte:      ;verify
	cmp [r0]
	beq hbl_inc_ptr
	lda #16           ;verify error status bit
	jsr udst
	bra hbl_end

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
