.import clear_status
.import extapi_getlfs

.export extapi

.segment "UTIL"

; This API call expects and requires
; m=1,x=1,sp=$01xx (or e=1)
extapi:
    pha ; reserve two free spots on the stack
    pha
    php ; preserve caller flags
    phx ; preserve caller X parameter
    asl
    tax
    lda apitbl,x   ; low byte of jump table entry
    pha
    lda apitbl+1,x ; high byte of jump table entry
    tsx
    sta $105,x     ; store API high byte on stack
    pla
    sta $104,x     ; store API low byte on stack
    plx            ; restore caller X
    plp            ; restore caller flags
    rts            ; jump to api

secrts:
    sec
    rts

apitbl:
    .word secrts-1 ; slot 0 is reserved
    .word clear_status-1      ; API 1
    .word extapi_getlfs-1     ; API 2

