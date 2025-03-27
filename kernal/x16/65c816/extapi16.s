; Comments in this source file use this nomenclature
; For registers, a dot and capital letters, for example: .X .Y .A .P .C
; For processor flags, a lowercase letter, for example: x m c z n

.import stack_push, stack_pop
.import stack_enter_kernal_stack, stack_leave_kernal_stack
.import xmacptr

.export extapi16

.include "65c816.inc"

.segment "UTIL"

.setcpu "65816"

.A16
.I16

; This API call expects and requires m=0, e=0
; Some calls require x=0, some allow x=1
extapi16:
	php ; preserve flags
	set_carry_if_65c816
	bcc unsupported
	phx ; preserve X parameter
	asl ; translate API call number to jump table entry
	tax
	lda apitbl,x
	plx ; restore old X
	plp ; restore flags
	pha ; push api address-1 onto stack
	rts ; jump to api

unsupported:
	plp
secrts:
	sec
	rts

apitbl:
	.word addition_test-1              ; API 0 (x=0 or x=1)
	.word stack_push-1                 ; API 1 (x=0)
	.word stack_pop-1                  ; API 2 (x=0)
	.word stack_enter_kernal_stack-1   ; API 3 (x=0)
	.word stack_leave_kernal_stack-1   ; API 4 (x=0)
	.word xmacptr-1                    ; API 5 (x=0 or x=1, returns with x=0)


addition_test: ; add .X to .Y, no carry, return in .C, used in the jsrfar unit tests
	php
	rep #$31
	.A16
	.I16
	phx
	tya
	adc $01,S
	plx
	plp
	rts
