; Code by Barry Yost (a.k.a. ZXeroByte)
; - 2022

; This file is for code dealing with the VERA PSG

.include "io.inc" ; for YM2151 addresses

.importzp azp0, azp0L, azp0H

; BRAM storage
.import ymshadow, returnbank, _PMD
.import ymtmp1, ymtmp2, ym_atten
.import audio_bank_refcnt, audio_prev_bank

; Pointer to FM patch data indexes
.import patches_lo, patches_hi

; Import subroutines
.import notecon_bas2fm

; Import LUTs
.import fm_op_alg_carrier

.export ym_write
.export ym_read
.export ym_loadpatch
.export ym_playnote
.export ym_setnote
.export ym_trigger
.export ym_release
.export ym_init
.export ym_set_atten

YM_TIMEOUT = 64 ; max value is 128.

.macro PRESERVE_AND_SET_BANK
.scope
	ldy ram_bank
	stz ram_bank
	beq skip_preserve
	sty audio_prev_bank
skip_preserve:
	inc audio_bank_refcnt
.endscope
.endmacro

.macro RESTORE_BANK
.scope
	dec audio_bank_refcnt
	bne skip_restore
	ldy audio_prev_bank
	stz audio_prev_bank
	sty ram_bank
skip_restore:
.endscope
.endmacro

.segment  "CODE"

; inputs    : .A = value, .X = YM register
; preserves : .A .X
; affects   : .Y
; returns   : .C clear=success, set=timeout
.proc ym_write: near
	ldy #YM_TIMEOUT
wait:
	dey
	bmi fail
	bit YM_DATA
	bmi wait

	PRESERVE_AND_SET_BANK
	phx
	pha

	stx YM_REG

	; write the value into the YM shadow first, so that if we cook the value 
	; later before writing to the chip, we have the original values here
	; but if it's an RLFBCON write, branch elsewhere to handle writing
	; all of the affected TL values if necessary
	cpx #$20
	bcc storeit
	cpx #$28
	bcc is_rlfbcon
	cpx #$19   ; PMD/AMD register is a special case. Shadow PMD writes into $1A.
	bne storeit
	cmp #$80   ; If value >= $80 then PMD. Store in $1A
	bcc storeit
	sta _PMD
	bra chk_tl_register
is_rlfbcon:
	; go ahead and write it out to the chip now
	sta YM_DATA
	; check to see if we need to reapply the TLs from the shadow
	; then store this value into the shadow
	jmp ym_chk_alg_change
storeit:
	sta ymshadow,X
chk_tl_register:
	; we need to cook the value if we're writing to a TL and we have an attenuation
	; level set for this channel
	cpx #$60
	bcc write
	cpx #$80
	bcs write
	
	; We're about to write a TL, let's find out what channel this write is for
	; If the write is meant for a TL that is not a carrier, bail out
	; If the write is meant for a TL that is a carrier, but there is no attenuation
	;  then bail out also
	; Otherwise, apply the attenuation value
	pha
	jsr ym_get_channel_from_register
	bcc pla_then_write
	lda ym_atten, x
	beq pla_then_write
	pla

	clc
	adc ym_atten, x
	bpl :+
	lda #$7F
:
	bra write
pla_then_write:
	pla
write:
	; plenty of clocks have passed in between the write to YM_REG
	; so there's definitely no need for NOPs
	sta YM_DATA
done:
	pla
	plx
	RESTORE_BANK
	clc
	rts
latefail:
	pla
	plx
	RESTORE_BANK
fail:
	sec
	rts
ym_chk_alg_change:
	sta ymtmp1 ; RLFBCON
	and #$07
	sta ymtmp2 ; just the CON portion
	lda ymshadow,x
	and #$07
	tay
	lda ymtmp1
	sta ymshadow,x ; we've finally shadowed this write

	; Is the old ALG the same as the new one? If so, we're done
	cpy ymtmp2
	beq done

	; Put the channel number into X
	txa
	and #$07
	tax

	; If no attenuation is set, we're done
	lda ym_atten,x
	beq done

	; get the register number for the TL into X
	txa
	clc
	adc #$60
	tax

	; reapply M1	
	lda ymshadow,x
	jsr ym_write
	bcs latefail

	; reapply M2
	txa
	adc #$08
	tax
	lda ymshadow,x
	jsr ym_write
	bcs latefail

	; reapply C1
	txa
	adc #$08
	tax
	lda ymshadow,x
	jsr ym_write
	bcs latefail

	bra done
.endproc

; inputs    : .X = YM register  *note that the PMD parameter is shadowed as $1A
; affects   : .A, .Y
; preserves : .X
; returns   : .A = retreived value
.proc ym_read: near
	ldy ram_bank
	stz ram_bank
	lda ymshadow,X
	sty ram_bank
	rts
.endproc


; inputs    : .A = attenuation amount (0 is native volume)  .X = YM channel
; affects   : .A, .X, .Y
; preserves : none
; returns   : .C clear if success, set if failed
.proc ym_set_atten: near
	PRESERVE_AND_SET_BANK

	; if unchanged, return
	cmp ym_atten,x
	beq end

	sta ym_atten,x
	
	; get the register number for the TL into X
	txa
	clc
	adc #$60
	tax

	; reapply M1	
	lda ymshadow,x
	jsr ym_write
	bcs fail

	; reapply M2
	txa
	adc #$08
	tax
	lda ymshadow,x
	jsr ym_write
	bcs fail

	; reapply C1
	txa
	adc #$08
	tax
	lda ymshadow,x
	jsr ym_write
	bcs fail

	; reapply C2
	txa
	adc #$08
	tax
	lda ymshadow,x
	jsr ym_write
	bcs fail
end:
	RESTORE_BANK
	clc
	rts
fail:
	RESTORE_BANK
	sec
	rts
.endproc



; inputs:
;   .C clear: .A = voice # .XY = address of patch (little-endian)
;   .C set:   .A = voice # .X = index of ROM patch 0..31
;
; affects: .A, .X, .Y
; returns: .C: clear=success, set=failed
;
; Note that this routine is not BankRAM-aware. If the patch is in BRAM, then
; it must be entirely contained in a single bank, and that bank must be active
; when the routine is called.
;
.proc ym_loadpatch: near
	bcc _loadpatch
	pha
	txa
	and #$1F ; mask instrument number to range 0..31
	tax
	lda patches_hi,x
	tay
	lda patches_lo,x
	tax
	pla
_loadpatch:
	and #$07 ; mask voice to range 0..7
	stx azp0L  ; TODO: use the Kernal's tmp1 ZP variable and not ABI
	sty azp0H
	clc
	adc #$20 ; first byte of patch goes to YM:$20+voice
	tax
	lda (azp0)
	jsr ym_write
	bcs fail
	ldy #0
	txa      ; ym_write preserves X (YM register)
	; Now skip over $28 and $30 by adding $10 to the register address.
	; C guaranteed clear by successful ym_write
	adc #$10
	tax      ; set up for loop
next:
	txa
	; C guaranteed clear by successful ym_write
	adc #$08
	bcs success
	iny
	tax
	lda (azp0),y
	phy      ; ym_write clobbers .Y
	jsr ym_write
	ply
	bcc next
fail:
	rts      ; return C set as failed patch write.
success:
	clc
	rts
.endproc

; inputs: .A = voice, .X = KC (note)  .Y = KF (key fraction (pitch bend))
; affects: .A .X .Y
; returns: C set on error
.proc ym_setnote: near
	and #$07 ; mask to voice range 0..7
	phx
	phy
	ora #$30 ; select KF register + voice
	tax
	pla
	jsr ym_write
	bcs fail
	txa
	eor #$18 ; switch to register $28+voice (KC - note)
	tax
	pla
	jmp ym_write
fail:
	pla
	sec
	rts
.endproc

; inputs: .A: voice  .C: set=no retrigger
; affects: .X .Y
; returns: C set if error
.proc ym_trigger: near
	and #$07      ; mask to voice range 0..7
	ldx #8        ; YM KeyON/OFF control register
	bcs no_retrigger
	jsr ym_write  ; release the voice before retriggering
	bcs fail
no_retrigger:
	ora #$78 ; key-on bits for all 4 operators.
	jsr ym_write
fail:
	rts
.endproc

; inputs: .A: voice
; affects: .X .Y
; returns: C set if error
.proc ym_release: near
	and #$07      ; mask to voice range 0..7
	ldx #8        ; YM KeyON/OFF control register
	jmp ym_write
.endproc

; inputs: .A = voice, .X = note (KC) .Y = note fraction (KF)
;         .C: set=no retrigger, clear=retrigger
; affects: .A .X .Y
; masks voice to range 0-7
.proc ym_playnote: near
	php
	pha
	jsr ym_setnote
	bcs fail
	pla
	plp
	jmp ym_trigger
fail:
	pla ; clear the stack.
	plp
	sec
	rts
.endproc

;---------------------------------------------------------------
; Re-initialize the YM-2151 to default state (everything off)
;---------------------------------------------------------------
; inputs: none
; affects: .A .X .Y
; returns: C set on failure
;
.proc ym_init: near
	; explicit initial PRESERVE_AND_SET_BANK
	lda rambank
	stz rambank
	sta audio_prev_bank
	lda #1
	sta audio_bank_refcnt

	; zero out the channel attenuation
	ldx #8
att:
	stz ym_atten-1,x
	dex
	bne att
	RESTORE_BANK

	; set release=max ($0F) for all operators on all voices ($E0..$FF)
	lda #$0f
	ldx #$e0
i1:
	jsr ym_write
	bcs abort       ; YM didn't respond correctly, abort
	inx
	bne i1

	; Release all 8 voices (write values 0..7 into YM register $08)
	lda #7
	ldx #$08
i2:
	jsr ym_write
	dec
	bpl i2

	; reset lfo
	lda #$02
	ldx #$01
	jsr ym_write    ; disable LFO
	lda #$80
	ldx #$19
	jsr ym_write	  ; clear pmd  (amd will be cleared when all regs are zeroed)

	; write 0 into all registers $0F .. $FF
	lda #0
	ldx #$0f
i3:
	jsr ym_write    ; clear everything else $0f..$ff
	inx
	bne i3

	; re-enable LFO
	lda #$00
	ldx #$01
	jsr ym_write
abort:
	rts
.endproc

.proc ym_get_channel_from_register: near
	; inputs: .X = YM2151 register
	;   assumes YMSHADOW/AUDIOBSS is banked in
	; affects: .A .Y
	; outputs: .X = channel 0-7, or $FF if error (register < $20)
	; returns with .C set if operator is a carrier in this alg
	txa
	tay
	cmp #$20
	bcc fail
	and #$07 
	tax ; channel number is safely in .X
	cpy #$40
	bcc end ; carry is clear
	tya
	and #$18
	sta ymtmp1

	lda ymshadow+$20,x ; get the alg (con) out of the shadow
	and #$07
	ora ymtmp1 ; combine it with 8*op
	tay
	lda fm_op_alg_carrier,y ; lookup whether operator is a carrier
	ror ; set carry if true
end:
	rts
fail:
	clc
	ldx #$FF
	rts
.endproc