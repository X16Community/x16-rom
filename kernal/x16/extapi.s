.import clear_status
.import extapi_getlfs
.import mouse_sprite_offset
.import joystick_ps2_keycodes
.import iso_cursor_char
.import ps2kbd_typematic
.import pfkey
.import ps2data_fetch
.import ps2data_mouse_raw
.import cursor_blink
.import led_update
.import mouse_set_position

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
    .word clear_status-1          ; API 1
    .word extapi_getlfs-1         ; API 2
    .word mouse_sprite_offset-1   ; API 3
    .word joystick_ps2_keycodes-1 ; API 4
    .word iso_cursor_char-1       ; API 5
    .word ps2kbd_typematic-1      ; API 6
    .word pfkey-1                 ; API 7
    .word ps2data_fetch-1         ; API 8
    .word ps2data_mouse_raw-1     ; API 9
    .word cursor_blink-1          ; API 10
    .word led_update-1            ; API 11
    .word mouse_set_position-1    ; API 12
