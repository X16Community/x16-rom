.export stack_init
.export stack_push
.export stack_pop
.export stack_enter_kernal_stack
.export stack_leave_kernal_stack
.export stack_ptr

.setcpu "65816"

.segment "KRAM816S"
stack_counter: .res 1
stack_ptr: .res 1
stack_one: .res 1

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
; stack_push
;
; Function: 
; Flags:    M = 0
; Output:   
;--------------------------------------------------------------
.proc stack_push
	.A16
	.I16
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

.proc stack_pop
	.A16
	.I16
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

.proc stack_enter_kernal_stack
	.A16
	.I16
	lda stack_ptr
	jmp stack_push
.endproc

.proc stack_leave_kernal_stack
	.A16
	.I16
	jmp stack_pop
.endproc
