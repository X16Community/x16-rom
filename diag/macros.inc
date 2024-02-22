.ifndef MACROS_INC
MACROS_INC=1

.macro GOTOXY xcord, ycord
.scope
	.if (.match (.left (1, {xcord}), #))
		coord = (.right (.tcount ({xcord})-1, {xcord}))
		ldx	#coord
		stx	x_cord
	.else
		ldx	xcord
	.endif
.endscope
.scope
	.if (.match (.left (1, {ycord}), #))
		coord = (.right (.tcount ({ycord})-1, {ycord}))
		ldy	#coord
		sty	y_cord
	.else
		ldy	ycord
	.endif
.endscope
	jsr	gotoxy
.endmacro

.macro PRINTSTR str, color
	lda	#<str
	sta	str_ptr
	lda	#>str
	sta	str_ptr+1
	.ifnblank color
		ldx	#color
	.else
		ldx	col
	.endif
	jsr	printstr
.endmacro

; Create a delay by using busy loops for .val times
; .val is a 16bit value, $1900 is roughly one second on X16 @ 8MHz
.macro DELAY val
	ldx	#>val
:	ldy	#<val
:	lda	#0
:	dec
	bne	:-
	dey
	bne	:--
	dex
	bne	:---
.endmacro

.macro FILLPAGE addr, pattern, start
	lda	#pattern
	.ifnblank start
		ldx	#start
	.else
		ldx	#0
	.endif
:	sta	addr,x
	inx
	bne	:-
.endmacro

.macro TEST_PAGE addr, pattern, start, erraddr
	ldx	#start
	lda	#pattern
:	cmp	addr,x
	beq	:+
	jmp	erraddr
:	inx
	bne	:--
.endmacro

.macro TEST_PAGE_UP addr, pattern, start, erraddr
	ldx	#start
:	lda	#pattern
	cmp	addr,x
	beq	:+
	jmp	erraddr
:	eor	#$FF
	sta	addr,x
	inx
	bne	:--
.endmacro

.macro TEST_PAGE_DN addr, pattern, start, end, erraddr
	ldx	#start
:	lda	#pattern
	cmp	addr,x
	beq	:+
	jmp	erraddr
:	eor	#$FF
	sta	addr,x
	dex
	cpx	#end-1
	bne	:--
.endmacro

.macro CHECK_INV pattern
.scope
loop:	lda	#pattern
	cmp	(mem_ptr),y
	beq	:+
	jmp	catastrophic_error
:	eor	#$FF
	sta	(mem_ptr),y
	cpx	mem_ptr+1
	beq	:+
	jmp	catastrophic_error
:	lda	mem_ptr
	beq	:+
	jmp	catastrophic_error
:	iny
	bne	loop
	inx
	stx	mem_ptr+1
	cpx	#$9F
	bne	loop
.endscope
.endmacro

.macro TESTMEM pattern
.scope
	; Fill memory with test pattern
fill:
	lda	#pattern		; Test pattern
	sta	(mem_ptr),y
	cpx	mem_ptr+1
	beq	:+
	jmp	catastrophic_error
:	lda	mem_ptr
	beq	:+
	jmp	catastrophic_error
:	iny
	bne	fill
	inx
	stx	mem_ptr+1
	cpx	#$9F
	bne	fill

	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1

	; Check memory and invert pattern
	CHECK_INV pattern

	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1

	; Check memory and invert pattern
	CHECK_INV $FF^pattern

	; Set zero-page pointer to $9E00
	ldx	#$9E
	stx	mem_ptr+1

	; Check memory and invert pattern - descending
	CHECK_INV pattern

	; Set zero-page pointer to $9E00
	ldx	#$9E
	stx	mem_ptr+1

	; Check memory and invert pattern - descending
	CHECK_INV $FF^pattern

	; Reset zero-page pointer to $0100
	ldx	#$01
	stx	mem_ptr+1

	lda	#pattern		; Test pattern
check:	cmp	(mem_ptr),y
	beq	:+
	jmp	catastrophic_error
:	iny
	bne	check
	inx
	stx	mem_ptr+1
	cpx	#$9F
	bne	check
.endscope
.endmacro
.endif