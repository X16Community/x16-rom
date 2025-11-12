.ifndef MACROS_INC
MACROS_INC=1

.macro GOTOXY xcord, ycord
.scope
	.if (.match (.left (1, {xcord}), #))
	    coord = (.right (.tcount ({xcord})-1, {xcord}))
	    ldx #coord
	    stx x_cord
	.else
	    ldx xcord
	.endif
.endscope
.scope
	.if (.match (.left (1, {ycord}), #))
	    coord = (.right (.tcount ({ycord})-1, {ycord}))
	    ldy #coord
	    sty y_cord
	.else
	    ldy ycord
	.endif
.endscope
	jsr gotoxy
.endmacro

.macro PRINTSTR str, col
	lda #<str
	sta str_ptr
	lda #>str
	sta str_ptr+1
	.ifnblank col
	    ldx #col
	.else
	    ldx color
	.endif
	jsr printstr
.endmacro

; Create a delay by using busy loops for .val times
; .val is a 16bit value, $1900 is roughly one second on X16 @ 8MHz
.macro DELAY val
	ldx #>val
:	ldy #<val
:	lda #0
:	dec
	bne :-
	dey
	bne :--
	dex
	bne :---
.endmacro

; Pattern must be loaded into .A before call
.macro FILL_ZP
	ldx #2
:	sta $0000,x
	inx
	bne :-
.endmacro

; Pattern must be loaded into .A before call
.macro TEST_ZP erraddr
	ldx #2
:	cmp $0000,x
	beq :+
	jmp erraddr
:	inx
	bne :--
.endmacro

; Pattern must be loaded into .A before call
.macro TEST_ZP_UP erraddr
	ldx #2
:	cmp $0000,x
	beq :+
	jmp erraddr
:	eor #$FF
	sta $0000,x
	eor #$FF
	inx
	bne :--
.endmacro

.macro TEST_ZP_DN erraddr
	ldx #$FF
:	cmp $0000,x
	beq :+
	jmp erraddr
:	eor #$FF
	sta $0000,x
	eor #$FF
	dex
	cpx #$01
	bne :--
.endmacro

; Pattern must be loaded into .A before call
.macro CHECK_INV_UP
.scope
loop:
	cmp (mem_ptr),y
	beq :+
	jmp catastrophic_error
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	cpx mem_ptr+1
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr+1
	iny
	bne loop
	inx
	stx mem_ptr+1
	cpx #$9F
	bne loop
.endscope
.endmacro

; Pattern must be loaded into.A before call
.macro CHECK_INV_DOWN
.scope
loop:
	dey
	cmp (mem_ptr),y
	beq :+
	jmp catastrophic_error
:	eor #$FF
	sta (mem_ptr),y
	eor #$FF
	cpx mem_ptr+1
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr+1
	cpy #0
	bne loop
	dex
	stx mem_ptr+1
	cpx #$00
	bne loop
.endscope
.endmacro

; Pattern must be loaded into .A before call
.macro TESTMEM
.scope
	; Fill memory with test pattern
fill:
	sta (mem_ptr),y
	; Ensure that writing to another page has not affected address on zeropage
	cpx mem_ptr+1          ; $01-$9F in this loop
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr            ; Should be $00
	beq :+
	jmp catastrophic_error
:	ldx mem_ptr+1          ; Restore .X register for next time
	iny
	bne fill
	inx
	stx mem_ptr+1
	cpx #$9F
	bne fill

	; Reset zero-page pointer to $0100
	ldx #$01
	stx mem_ptr+1
	; Check memory and invert pattern
	CHECK_INV_UP

	; Reset zero-page pointer to $0100
	ldx #$01
	stx mem_ptr+1
	; Check memory and invert pattern
	eor #$FF
	CHECK_INV_UP

	; Set zero-page pointer to $9E00
	ldx #$9E
	stx mem_ptr+1
	; Check memory and invert pattern - descending
	eor #$FF
	CHECK_INV_DOWN

	; Set zero-page pointer to $9E00
	ldx #$9E
	stx mem_ptr+1
	; Check memory and invert pattern - descending
	eor #$FF
	CHECK_INV_DOWN

	; Reset zero-page pointer to $0100
	ldx #$01
	stx mem_ptr+1

	eor #$FF               ; Test pattern
check:
	cmp (mem_ptr),y
	beq :+
	jmp catastrophic_error
:	iny
	bne check
	inx
	stx mem_ptr+1
	cpx #$9F
	bne check
.endscope
.endmacro

.macro POST code
.local @1
	lda POST_IO_PORT
	cmp #>POST_IO_PORT ; open bus read
	bne @1
	lda #code
	sta POST_IO_PORT
@1:
.endmacro

.endif
