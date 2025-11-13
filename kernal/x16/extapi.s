.include "65c816.inc"

.import clear_status
.import extapi_getlfs
.import mouse_sprite_offset
.import joystick_ps2_keycodes
.import iso_cursor_char
.import ps2kbd_typematic
.import pfkey
.import ps2data_fetch
.import ps2data_raw
.import cursor_blink
.import led_update
.import mouse_set_position
.import scnsiz
.import kbd_leds
.import memory_decompress_internal
.import default_palette
.import has_machine_property
.import kbdbuf_get
.import kbdbuf_clear
.import extapi_blink_enable

.export extapi

.segment "UTIL"

; On the 65C816 This API call expects and requires m=1,x=1
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
	set_carry_if_65c816
	bcs @c816
	tsx
	sta $105,x     ; store API high byte on stack
	pla
	sta $104,x     ; store API low byte on stack
	plx            ; restore caller X
	plp            ; restore caller flags
	rts            ; jump to api
@c816:
.pushcpu
.setcpu "65816"
	sta $05,S
	pla
	sta $03,S
	plx
	plp
	rts
.popcpu

secrts:
	sec
	rts

apitbl:
	.word secrts-1                     ; API slot 0 is reserved
	.word clear_status-1               ; API 1
	.word extapi_getlfs-1              ; API 2
	.word mouse_sprite_offset-1        ; API 3
	.word joystick_ps2_keycodes-1      ; API 4
	.word iso_cursor_char-1            ; API 5
	.word ps2kbd_typematic-1           ; API 6
	.word pfkey-1                      ; API 7
	.word ps2data_fetch-1              ; API 8
	.word ps2data_raw-1                ; API 9
	.word cursor_blink-1               ; API 10
	.word led_update-1                 ; API 11
	.word mouse_set_position-1         ; API 12
	.word scnsiz-1                     ; API 13
	.word kbd_leds-1                   ; API 14
	.word memory_decompress_internal-1 ; API 15
	.word default_palette-1            ; API 16
	.word has_machine_property-1       ; API 17
	.word kbdbuf_get-1                 ; API 18
	.word kbdbuf_clear-1               ; API 19
	.word extapi_blink_enable-1        ; API 20
