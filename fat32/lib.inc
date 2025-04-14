;-----------------------------------------------------------------------------
; lib.inc
;-----------------------------------------------------------------------------

.include "regs.inc"

;-----------------------------------------------------------------------------
; Set 8-bit variable
;-----------------------------------------------------------------------------
.macro set8 dst, src
.if .ASIZE = 16
.error "set8 called in 16 bit mode"
.endif
	lda src
	sta dst
.endmacro

.macro set8_val dst, val
.if .ASIZE = 16
.error "set8_val called in 16 bit mode"
.endif
.if .const(val) && val = 0
	stz dst
.else
	lda #val
	sta dst
.endif
.endmacro

.macro add8_val dst, src, val
.if .ASIZE = 16
.error "add8_val called in 16 bit mode"
.endif
	clc
	lda src + 0
	adc #val
	sta dst + 0
.endmacro

.macro sub8_val dst, src, val
.if .ASIZE = 16
.error "sub8_val called in 16 bit mode"
.endif
	sec
	lda src
	sbc #val
	sta dst
.endmacro

.macro cmp8_ne src_a, src_b, lbl
.if .ASIZE = 16
.error "cmp8_ne called in 16 bit mode"
.endif
	lda src_a
	cmp src_b
	bne lbl
.endmacro

.macro cmp8_eq src_a, src_b, lbl
.if .ASIZE = 16
.error "cmp8_eq called in 16 bit mode"
.endif
	lda src_a
	cmp src_b
	beq lbl
.endmacro

;-----------------------------------------------------------------------------
; Set 16-bit variable
;-----------------------------------------------------------------------------
.macro set16 dst, src
	lda src + 0
	sta dst + 0
.if .ASIZE = 8
	lda src + 1
	sta dst + 1
.endif
.endmacro

.macro set16_val dst, val
.if .ASIZE = 16
.if .const(val) && val = 0
	stz dst
.else
	lda #val
	sta dst
.endif
.else
.if .const(val) && <(val) = 0
	stz dst + 0
.else
	lda #<(val)
	sta dst + 0
.endif
.if .const(val) && >(val) = 0
	stz dst + 1
.else
	lda #>(val)
	sta dst + 1
.endif
.endif
.endmacro

;-----------------------------------------------------------------------------
; Add two 16-bit variables
;-----------------------------------------------------------------------------
.macro add16 dst, src_a, src_b
	clc
	lda src_a + 0
	adc src_b + 0
	sta dst + 0
.if .ASIZE = 8
	lda src_a + 1
	adc src_b + 1
	sta dst + 1
.endif
.endmacro

.macro add16_8 dst, src_a, src_b
	clc
.if .ASIZE = 16
	lda src_b
	and #$00FF
	adc src_a
	sta dst
.else
	lda src_a + 0
	adc src_b
	sta dst + 0
	lda src_a + 1
	adc #0
	sta dst + 1
.endif
.endmacro

.macro add16_a dst, src
	clc
	adc src
	sta dst + 0
.if .ASIZE = 8
	lda src + 1
	adc #0
	sta dst + 1
.endif
.endmacro

;-----------------------------------------------------------------------------
; Add value to 16-bit variable
;-----------------------------------------------------------------------------
.macro add16_val dst, src, val
	clc
	lda src + 0
.if .ASIZE = 16
	adc #val
	sta dst
.else
	adc #<(val)
	sta dst + 0
	lda src + 1
	adc #>(val)
	sta dst + 1
.endif
.endmacro

;-----------------------------------------------------------------------------
; Subtract two 16-bit variables
;-----------------------------------------------------------------------------
.macro sub16 dst, src_a, src_b
	sec
	lda src_a + 0
	sbc src_b + 0
	sta dst + 0

.if .ASIZE = 8
	lda src_a + 1
	sbc src_b + 1
	sta dst + 1
.endif
.endmacro

;-----------------------------------------------------------------------------
; Subtract value from 16-bit variable
;-----------------------------------------------------------------------------
.macro sub16_val dst, src, val
	sec
	lda src + 0
.if .ASIZE = 16
	sbc #val
	sta dst
.else
	sbc #<(val)
	sta dst + 0

	lda src + 1
	sbc #>(val)
	sta dst + 1
.endif
.endmacro

;-----------------------------------------------------------------------------
; Increment 16-bit variable
;-----------------------------------------------------------------------------
.macro inc16 dst
	.local @1
	inc dst
.if .ASIZE = 8
	bne @1
	inc dst + 1
.endif
@1:
.endmacro

;-----------------------------------------------------------------------------
; Decrement 16-bit variable
;-----------------------------------------------------------------------------
.macro dec16 dst
	.local @1
.if .ASIZE = 8
	lda dst
	bne @1
	dec dst + 1
@1:
.endif
	dec dst
.endmacro

;-----------------------------------------------------------------------------
; Compare two 16-bit variables
;-----------------------------------------------------------------------------
.macro cmp16_ne src_a, src_b, lbl
	lda src_a + 0
	cmp src_b + 0
	bne lbl
.if .ASIZE = 8
	lda src_a + 1
	cmp src_b + 1
	bne lbl
.endif
.endmacro

.macro cmp16_eq src_a, src_b, lbl
	.local @1
	lda src_a + 0
	cmp src_b + 0
.if .ASIZE = 8
	bne @1
	lda src_a + 1
	cmp src_b + 1
.endif
	beq lbl
@1:
.endmacro

.macro cmp16_lt src_a, src_b, lbl
	.local @1
	lda src_a + 1
	cmp src_b + 1
.if .ASIZE = 8
	bcc lbl
	bne @1
	lda src_a + 0
	cmp src_b + 0
.endif
	bcc lbl
@1:
.endmacro

.macro cmp16_ge src_a, src_b, lbl
	.local @1
	lda src_a + 1
	cmp src_b + 1
.if .ASIZE = 8
	bcc @1
	bne lbl
	lda src_a + 0
	cmp src_b + 0
.endif
	bcs lbl
@1:
.endmacro

.macro cmp16_z src, lbl
	lda src + 0
.if .ASIZE = 8
	ora src + 1
.endif
	beq lbl
.endmacro

.macro cmp16_nz src, lbl
	lda src + 0
.if .ASIZE = 8
	ora src + 1
.endif
	bne lbl
.endmacro

;-----------------------------------------------------------------------------
; Compare 16-bit variable with value
;-----------------------------------------------------------------------------
.macro cmp16_val_ne src, val, lbl_not_equal
	lda src + 0
.if .ASIZE = 16
.if !(.const(val) && (val) = 0)
	cmp #val
.endif
.else
.if !(.const(val) && <(val) = 0)
	cmp #<(val)
.endif
	bne lbl_not_equal
	lda src + 1
.if !(.const(val) && >(val) = 0)
	cmp #>(val)
.endif
.endif
	bne lbl_not_equal
.endmacro

.macro cmp16_val_eq src, val, lbl_equal
	.local @1
	lda src + 0
.if .ASIZE = 16
.if !(.const(val) && (val) = 0)
	cmp #val
.endif
.else
.if !(.const(val) && <(val) = 0)
	cmp #<(val)
.endif
	bne @1
	lda src + 1
.if !(.const(val) && >(val) = 0)
	cmp #>(val)
.endif
.endif
	beq lbl_equal
@1:
.endmacro

.macro cmp16_val_lt src, val, lbl
	.local @1
.if .ASIZE = 16
	lda src
	cmp #val
.else
	lda src + 1
	cmp #>(val)
	bcc lbl
	bne @1
	lda src + 0
	cmp #<(val)
.endif
	bcc lbl
@1:
.endmacro

.macro cmp16_val_ge src, val, lbl
	.local @1
.if .ASIZE = 16
	lda src
	cmp #val
.else
	lda src + 1
	cmp #>(val)
	bcc @1
	bne lbl
	lda src + 0
	cmp #<(val)
.endif
	bcs lbl
@1:
.endmacro


;-----------------------------------------------------------------------------
; Set 32-bit variable
;-----------------------------------------------------------------------------
.macro set32 dst, src
	lda src + 0
	sta dst + 0
.if .ASIZE = 8
	lda src + 1
	sta dst + 1
.endif
	lda src + 2
	sta dst + 2
.if .ASIZE = 8
	lda src + 3
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Set 32-bit variable
;-----------------------------------------------------------------------------
.macro set32_val dst, val
.if .ASIZE = 16
.if .const(val) && .loword(val) = 0
	stz dst + 0
.else
	lda #.loword(val)
	sta dst + 0
.endif
.if .const(val) && .hiword(val) = 0
	stz dst + 2
.else
	lda #.hiword(val)
	sta dst + 2
.endif
.else
.if .const(val) && <(val) = 0
	stz dst + 0
.else
	lda #<(val)
	sta dst + 0
.endif
.if .const(val) && >(val) = 0
	stz dst + 1
.else
	lda #>(val)
	sta dst + 1
.endif
.if .const(val) && ^(val) = 0
	stz dst + 2
.else
	lda #^(val)
	sta dst + 2
.endif
.if .const(val) && (.hibyte(.hiword(val))) = 0
	stz dst + 3
.else
	lda #(.hibyte(.hiword(val)))
	sta dst + 3
.endif
.endif
.endmacro

;-----------------------------------------------------------------------------
; Add two 32-bit variables
;-----------------------------------------------------------------------------
.macro add32 dst, src_a, src_b
	clc
	lda src_a + 0
	adc src_b + 0
	sta dst + 0
.if .ASIZE = 8
	lda src_a + 1
	adc src_b + 1
	sta dst + 1
.endif
	lda src_a + 2
	adc src_b + 2
	sta dst + 2
.if .ASIZE = 8
	lda src_a + 3
	adc src_b + 3
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Add immediate value to 32-bit variable
;-----------------------------------------------------------------------------
.macro add32_val dst, src, val
	clc
	lda src + 0
.if .ASIZE = 16
	adc #.loword(val)
	sta dst + 0
	lda src + 2
	adc #.hiword(val)
	sta dst + 2
.else
	adc #<(val)
	sta dst + 0

	lda src + 1
	adc #>(val)
	sta dst + 1

	lda src + 2
	adc #^(val)
	sta dst + 2

	lda src + 3
	adc #(.hibyte(.hiword(val)))
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Compare two 32-bit variables
;-----------------------------------------------------------------------------
.macro cmp32_ne src_a, src_b, lbl_not_equal
	lda src_a + 0
	cmp src_b + 0
	bne lbl_not_equal
.if .ASIZE = 8
	lda src_a + 1
	cmp src_b + 1
	bne lbl_not_equal
.endif
	lda src_a + 2
	cmp src_b + 2
	bne lbl_not_equal
.if .ASIZE = 8
	lda src_a + 3
	cmp src_b + 3
	bne lbl_not_equal
.endif
.endmacro

.macro cmp32_z src, lbl
	lda src + 0
.if .ASIZE = 8
	ora src + 1
.endif
	ora src + 2
.if .ASIZE = 8
	ora src + 3
.endif
	beq lbl
.endmacro

.macro cmp32_nz src, lbl
	lda src + 0
.if .ASIZE = 8
	ora src + 1
.endif
	ora src + 2
.if .ASIZE = 8
	ora src + 3
.endif
	bne lbl
.endmacro

;-----------------------------------------------------------------------------
; Add 32-bit and 16-bit variable
;-----------------------------------------------------------------------------
.macro add32_16 dst, src_a, src_b
	clc

	lda src_a + 0
	adc src_b + 0
	sta dst + 0

.if .ASIZE = 8
	lda src_a + 1
	adc src_b + 1
	sta dst + 1
.endif

	lda src_a + 2
	adc #0
	sta dst + 2

.if .ASIZE = 8
	lda src_a + 3
	adc #0
	sta dst + 3
.endif
.endmacro


;-----------------------------------------------------------------------------
; Add 32-bit and 16-bit variable
;-----------------------------------------------------------------------------
.macro add32_8 dst, src_a, src_b
	clc

	lda src_a + 0
	adc src_b + 0
	sta dst + 0

.if .ASIZE = 8
	lda src_a + 1
	adc #0
	sta dst + 1
.endif

	lda src_a + 2
	adc #0
	sta dst + 2

.if .ASIZE = 8
	lda src_a + 3
	adc #0
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Add 8-bit variable to 32-bit variable
;-----------------------------------------------------------------------------
.macro add2_32_8 dst, src
	.local @1
	clc
.if .ASIZE = 16
	lda src
	and #$00FF
	adc dst
.else
	lda dst
	adc src
	sta dst
	bcc @1
	inc dst + 1
	bne @1
.endif
	inc dst + 2
.if .ASIZE = 8
	bne @1
	inc dst + 3
.endif
@1:
.endmacro

;-----------------------------------------------------------------------------
; Increment 32-bit variable
;-----------------------------------------------------------------------------
.macro inc32 dst
	.local @1
	inc dst + 0
	bne @1
.if .ASIZE = 8
	inc dst + 1
	bne @1
.endif
	inc dst + 2
.if .ASIZE = 8
	bne @1
	inc dst + 3
.endif
@1:
.endmacro

;-----------------------------------------------------------------------------
; Decrement 32-bit variable
;-----------------------------------------------------------------------------
.macro dec32 dst
	.local @1, @2, @3
	lda dst + 0
	bne @3
.if .ASIZE = 8
	lda dst + 1
	bne @2
	lda dst + 2
	bne @1
	dec dst + 3
.endif
@1:	dec dst + 2
.if .ASIZE = 8
@2:	dec dst + 1
.endif
@3:	dec dst + 0
.endmacro

;-----------------------------------------------------------------------------
; Subtract immediate value from 32-bit variable
;-----------------------------------------------------------------------------
.macro sub32_val dst, src, val
	sec
	lda src + 0
.if .ASIZE = 16
	sbc #.loword(val)
	sta dst + 0
	lda src + 2
	sbc #.hiword(val)
	sta dst + 2
.else
	sbc #<(val)
	sta dst + 0

	lda src + 1
	sbc #>(val)
	sta dst + 1

	lda src + 2
	sbc #^(val)
	sta dst + 2

	lda src + 3
	sbc #(.hibyte(.hiword(val)))
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Subtract two 32-bit variables
;-----------------------------------------------------------------------------
.macro sub32 dst, src_a, src_b
	sec
	lda src_a + 0
	sbc src_b + 0
	sta dst + 0

.if .ASIZE = 8
	lda src_a + 1
	sbc src_b + 1
	sta dst + 1
.endif

	lda src_a + 2
	sbc src_b + 2
	sta dst + 2

.if .ASIZE = 8
	lda src_a + 3
	sbc src_b + 3
	sta dst + 3
.endif
.endmacro


;-----------------------------------------------------------------------------
; Subtract two 32-bit variables
;-----------------------------------------------------------------------------
.macro sub2_32_8 dst, src
.if .ASIZE = 16
	lda src
	and #$00FF
	eor #$FFFF
	inc
	clc
	adc dst + 0
	sta dst + 0
.else
	sec
	lda dst + 0
	sbc src
	sta dst + 0

	lda dst + 1
	sbc #0
	sta dst + 1
.endif
	lda dst + 2
	sbc #0
	sta dst + 2
.if .ASIZE = 8
	lda dst + 3
	sbc #0
	sta dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Perform 32-bit shift-right on variable
;-----------------------------------------------------------------------------
.macro shr32 dst
.if .ASIZE = 8
	lsr dst + 3
	ror dst + 2
.else
	lsr dst + 2
.endif
.if .ASIZE = 8
	ror dst + 1
.endif
	ror dst + 0
.endmacro

;-----------------------------------------------------------------------------
; Perform 32-bit shift-left on variable
;-----------------------------------------------------------------------------
.macro shl32 dst
	asl dst + 0
.if .ASIZE = 8
	rol dst + 1
.endif
	rol dst + 2
.if .ASIZE = 8
	rol dst + 3
.endif
.endmacro

;-----------------------------------------------------------------------------
; Copy bytes
;-----------------------------------------------------------------------------
.macro copy_bytes dst, src, count
	.local @1
.if .ASIZE = 16
.error "copy_bytes called in 16 bit mode"
.endif
	ldy #0
@1:	lda src, y
	sta dst, y
	iny
	cpy #count
	bne @1
.endmacro

;-----------------------------------------------------------------------------
; Clear bytes
;-----------------------------------------------------------------------------
.macro clear_bytes dst, count
	.local @1
.if .ASIZE = 16
.error "clear_bytes called in 16 bit mode"
.endif
	ldx #0
@1:	stz dst, x
	inx
	cpx #count
	bne @1
.endmacro

.macro set24_val dst, val
.if .ASIZE = 16
.error "set24_val called in 16 bit mode"
.endif
	lda #<(val)
	sta dst + 0
	lda #>(val)
	sta dst + 1
	lda #^(val)
	sta dst + 2
.endmacro
