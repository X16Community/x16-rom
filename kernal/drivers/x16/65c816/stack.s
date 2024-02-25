.export STACK_init
.export STACK_push
.export STACK_pop
.export STACK_enter_kernal_stack
.export STACK_leave_kernal_stack
.export stack_ptr

.setcpu "65816"

.segment "KRAM816S"
stack_counter: .res 1
stack_ptr: .res 1
stack_one: .res 1

.segment "MACHINE"

.proc STACK_init
	lda #$01
	sta stack_one
	rts
.endproc

.A16
.I16

;--------------------------------------------------------------
; STACK_push
;
; Function: 
; Flags:    M = 0
; Output:   
;--------------------------------------------------------------
.proc STACK_push
	ply
	lda stack_counter
	beq @counter_zero

	sei

	inc
	sta stack_counter

	tsc
	txs
	pha
	phy

	cli
	rts

@counter_zero:
	tsc
	xba
	sta stack_counter
	txs
	phy
	rts
.endproc

.proc STACK_pop
	ply
	lda stack_counter
	dec
	bit #$00FF
	beq @counter_one

	sei
	sta stack_counter
	pla
	tcs
	phy
	rts

@counter_one:
	stz stack_counter
	inc
	xba
	tcs
	phy
	rts
.endproc

.proc STACK_enter_kernal_stack
	lda stack_ptr
	jmp STACK_push
.endproc

.proc STACK_leave_kernal_stack
	jmp STACK_pop
.endproc