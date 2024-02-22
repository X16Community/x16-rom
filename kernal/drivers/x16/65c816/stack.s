.export STACK_push
.export STACK_pop
.export STACK_enter_kernal_stack
.export STACK_leave_kernal_stack
.export stack_ptr

.setcpu "65816"

.segment "KRAM816S"
stack_ptr: .res 1
stack_counter: .res 1

.segment "MACHINE"
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
	lda stack_ptr
	cmp #$0100
	bcc @counter_zero

	xba
	inc
	xba

	sei
	sta stack_ptr
	tsc
	txs
	pha
	phy
	cli
	rts

@counter_zero:
	tsc
	sta stack_ptr
	txs
	phy
	rts
.endproc

.proc STACK_pop
	ply
	lda stack_ptr
	cmp #$0200
	bcc @counter_one

	xba
	dec
	xba

	sei
	sta stack_ptr
	pla
	tcs
	phy
	rts

@counter_one:
	stz stack_ptr
	tcs
	phy
	rts
.endproc

.proc STACK_enter_kernal_stack
	sep #$20
	.A8
	lda #$01
	xba
	lda stack_ptr
	rep #$20
	.A16
	jmp STACK_push
.endproc

.proc STACK_leave_kernal_stack
	jmp STACK_pop
.endproc