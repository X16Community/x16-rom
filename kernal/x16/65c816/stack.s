.export stack_init
.export stack_push
.export stack_pop
.export stack_enter_kernal_stack
.export stack_leave_kernal_stack
.export stack_ptr

.setcpu "65816"

.segment "KRAM816S"
stack_counter: .res 1 ; depth of the stack chain
stack_ptr: .res 1     ; low byte of the preserved $01xx stack
stack_one: .res 1     ; holds the value #$01 to speed up 16-bit
                      ; stack restore operations

.segment "MACHINE"

.proc stack_init
	.A8
	.I8
	lda #$01
	sta stack_one
	rts
.endproc

.A16
.I16

;--------------------------------------------------------------
; stack_enter_kernal_stack
;
; Function: change SP to KERNAL (page $01) SP
; Flags:    m = 0, x = 0, e = 0
; Input:    SP = old stack pointer
; Output:   SP = KERNAL stack pointer (after rts)
;--------------------------------------------------------------
.proc stack_enter_kernal_stack
	.A16
	.I16
	ldx stack_ptr
	; fall through
.endproc

;--------------------------------------------------------------
; stack_push
;
; Function: change SP to new pointer, preserving the old one
;           at the top of the new stack
; Flags:    m = 0, x = 0, e = 0
; Input:    X = new stack pointer, SP = old stack pointer
; Output:   SP = X - 2 (after rts)
;--------------------------------------------------------------
.proc stack_push
	.A16
	.I16
	sei
	ply                ; hold the return address
	lda stack_counter  ; is the stack chain empty
	beq @counter_zero  ; if so, don't push the old stack
	                   ; instead, treat the old stack
	                   ; as $01xx page, and preserve its location
	inc
	sta stack_counter  ; otherwise, increment the stack_counter

	tsc                ; preserve old SP
	txs                ; bring new SP into effect
	pha                ; save old SP on new stack
	phy                ; restore the return address

	cli
	rts

@counter_zero:
	tsc                ; This is inferred to be $01xx
	xba                ; Swap bytes, $xx01
	sta stack_counter  ; Store $01 to stack_counter
	                   ; and $xx to stack_ptr (stack_counter+1)
	txs                ; bring new SP into effect
	phy                ; restore return address
	cli
	rts
.endproc

;--------------------------------------------------------------
; stack_leave_kernal_stack
;
; Function: restore old SP, which is assumed to be in page $01
; Flags:    m = 0, x = 0, e = 0
; Input:    (SP+2) = old stack pointer if stack_counter > 1
; Output:   SP = old stack pointer (after rts)
;--------------------------------------------------------------
.proc stack_leave_kernal_stack
	.A16
	.I16
	; fall through
.endproc

;--------------------------------------------------------------
; stack_pop
;
; Function: change SP to old pointer
; Flags:    m = 0, x = 0, e = 0
; Input:    (SP+2) = old stack pointer if stack_counter > 1
; Output:   SP = old stack pointer (after rts)
;--------------------------------------------------------------
.proc stack_pop
	.A16
	.I16
	sei
	ply                ; hold the return address
	lda stack_counter  ; C = $xxyy where $yy = stack_counter
	                   ; and $xx = stack_ptr, the KERNAL
	                   ; stack pointer
	dec                ; decrement $xxyy
	bit #$00FF         ; if $yy = 0
	beq @counter_one   ; then restore SP to $01xx

	sta stack_counter  ; store decremented stack_counter
	pla                ; pop old SP off existing stack
	tcs                ; bring old SP into effect
	phy                ; restore return address
	cli
	rts

@counter_one:
	stz stack_counter  ; reset stack_counter to zero
	                   ; this is the end of the stack popping chain
	inc                ; C = $xx00 -> $xx01
	xba                ; C = $01xx (valid KERNAL SP)
	tcs                ; bring KERNAL SP into effect
	phy                ; restore return address
	cli
	rts
.endproc

