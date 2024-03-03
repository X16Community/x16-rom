.import stack_push, stack_pop
.import stack_enter_kernal_stack, stack_leave_kernal_stack

.export extapi16

.include "65c816.inc"

.segment "UTIL"

.setcpu "65816"

.A16
.I16

; This API call expects and requires m=0, x=0, e=0
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
    .word secrts-1 ; slot 0 is reserved
    .word stack_push-1                 ; API 1
    .word stack_pop-1                  ; API 2
    .word stack_enter_kernal_stack-1   ; API 3
    .word stack_leave_kernal_stack-1   ; API 4


