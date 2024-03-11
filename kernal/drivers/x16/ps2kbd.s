;----------------------------------------------------------------------
; PS/2 Keyboard Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.macpack longbranch
.include "banks.inc"
.include "regs.inc"
.include "io.inc"
.include "mac.inc"
.include "keycode.inc"

; code
.import i2c_read_byte, i2c_direct_read, i2c_read_stop
.import i2c_write_first_byte, i2c_write_next_byte, i2c_write_stop
.import joystick_from_ps2_init, joystick_from_ps2; [joystick]
.import ps2data_kbd, ps2data_kbd_count

; data
.import mode; [declare]
.import fetch, fetvec; [memory]
.importzp tmp2

.import kbdbuf_put
.import shflag
.import keyhdl
.import check_charset_switch

.import screen_mode

.import memory_decompress_internal ; [lzsa]

.export kbd_config, kbd_scan, receive_scancode_resume, keymap
.export MODIFIER_4080

I2C_ADDRESS = $42
I2C_KBD_ADDRESS = $43
I2C_GET_SCANCODE_OFFSET = $07
I2C_KBD_CMD2 = $1a

MODIFIER_SHIFT = 1 ; C64:  Shift
MODIFIER_ALT   = 2 ; C64:  Commodore
MODIFIER_CTRL  = 4 ; C64:  Ctrl
MODIFIER_WIN   = 8 ; C128: Alt
MODIFIER_CAPS  = 16; C128: Caps
MODIFIER_4080  = 32; 40/80 DISPLAY
MODIFIER_ALTGR = MODIFIER_ALT | MODIFIER_CTRL
; set of modifiers that are toggled on each key press
MODIFIER_TOGGLE_MASK = MODIFIER_CAPS | MODIFIER_4080

LED_SCROLL_LOCK = 1
LED_NUM_LOCK	= 2
LED_CAPS_LOCK	= 4

TABLE_COUNT = 11
KBDNAM_LEN = 14

.segment "ZPKERNAL" : zeropage
ckbtab:	.res 2           ;    used for keyboard lookup

.segment "ZPKBD": zeropage
kbtmp:  .res 1           ;    meant for exclusive use in kbd_scan
                         ;   The routine formerly used tmp2 which
                         ;   can conflict with usage outside of the ISR

.segment "KVARSB0"

prefix:	.res 1           ;    PS/2: prefix code (e0/e1)
brkflg:	.res 1           ;    PS/2: was key-up event
curkbd:	.res 1           ;    current keyboard layout index
dk_shift:
	.res 1
dk_scan:
	.res 1

.segment "KEYMAP"
keymap_data:
	.res TABLE_COUNT*128

caps:	.res 16 ; for which keys caps means shift
deadkeys:
	.res 224
kbdnam:
	.res KBDNAM_LEN ; zero-terminated
keymap_len = * - keymap_data

.segment "PS2KBD"

kbd_config:
	KVARS_START
	jsr _kbd_config
	KVARS_END
	rts

keymap:
	KVARS_START
	jsr _keymap
	KVARS_END
	rts

kbd_scan:
	KVARS_START
	jsr _kbd_scan
	KVARS_END
	rts

;
; set keyboard layout .a
;  $ff: reload current layout (PETSCII vs. ISO might have changed)
;
_kbd_config:
	stz dk_scan ; clear dead key

	cmp #$ff
	bne :+
	lda curkbd
:	pha

	lda #<$c000
	sta tmp2
	lda #(>$c000) >> 1
	sta tmp2+1
	lda #tmp2
	sta fetvec

; get keymap
	pla
	sta curkbd
	asl
	asl
	asl
	asl             ;*16
	rol tmp2+1
	tay
	ldx #BANK_KEYBD
	jsr fetch
	bne :+
	sec             ;end of list
	rts
:
; get name
	ldx #0
:	phx
	ldx #BANK_KEYBD
	jsr fetch
	plx
	sta kbdnam,x
	inx
	iny
	cpx #KBDNAM_LEN
	bne :-
; get address
	ldx #BANK_KEYBD
	jsr fetch
	pha
	iny
	ldx #BANK_KEYBD
	jsr fetch
	sta tmp2+1
	pla
	sta tmp2

; copy into banked RAM
	PushW r0
	PushW r1
	PushW r4
	lda tmp2
	sta r0
	lda tmp2+1
	sta r0+1
	lda #<keymap_data
	sta r1
	lda #>keymap_data
	sta r1+1
	LoadW r4, kbd_getsrc
	lda #r0
	sta fetvec
	jsr memory_decompress_internal
	PopW r4
	PopW r1
	PopW r0
	jsr joystick_from_ps2_init
	clc             ;ok
	rts

kbd_getsrc:
	php
	phx
	phy
	ldy #0
	ldx #BANK_KEYBD
	lda #r0
	jsr fetch
	inc r0L
	bne :+
	inc r0H
:	ply
	plx
	plp
	rts


;---------------------------------------------------------------
; Get/Set keyboard layout
;
;   In:   .c  =0: set, =1: get
; Set:
;   In:   .x/.y  pointer to layout string (e.g. "DE_CH")
;   Out:  .c  =0: success, =1: failure
; Get:
;   Out:  .x/.y  pointer to layout string
;         .a = current keyboard layout index
;---------------------------------------------------------------
_keymap:
	bcc @set
	ldx #<kbdnam
	ldy #>kbdnam
	lda curkbd
	rts

@set:	php
	sei             ;protect ckbtab
	stx ckbtab
	sty ckbtab+1
	lda curkbd
	pha
	lda #0
@l1:	pha
	ldx ckbtab
	ldy ckbtab+1
	phx
	phy
	jsr _kbd_config
	bne @nend
	pla             ;not found
	pla
	pla
	pla
	jsr _kbd_config ;restore original keymap
	plp
	sec
	rts
@nend:
	ply
	plx
	sty ckbtab+1
	stx ckbtab
	ldy #0
@l2:	lda (ckbtab),y
	cmp kbdnam,y
	beq @ok
	pla             ;next
	inc
	bra @l1
@ok:	iny
	cmp #0
	bne @l2
	pla             ;found
	pla
	plp
	clc
	rts

;---------------------------------------------------------------
; Scan keyboard and handle received key codes
;---------------------------------------------------------------
_kbd_scan:
	jsr fetch_key_code
	ora #0
	bne :+
	rts			; No key

:	jsr joystick_from_ps2

	; Is it a modifier key?
 	pha			; Save key code on stack
	and #%01111111		; Clear up/down bit
	ldx #0
:	cmp modifier_key_codes,x
	beq is_mod_key
	inx
	cpx #9			; Modifier key count = 9
	bne :-

	; Is it Caps Lock down?
	cmp #KEYCODE_CAPSLOCK
	bne is_reg_key
	pla			; Restore key code from stack
	bmi :+			; Ignore key up
	lda shflag
	eor #MODIFIER_CAPS
	sta shflag
	jmp set_caps_led
:	rts

is_mod_key:
	; Restore key code from stack
	pla
	bpl mod_key_down

mod_key_up:
	lda modifier_shift_states,x
	eor #$ff
	and shflag
	sta shflag
	rts

mod_key_down:
	lda modifier_shift_states,x
	ora shflag
	sta shflag
	and #((~MODIFIER_TOGGLE_MASK) & $ff)
	jmp check_charset_switch

is_reg_key:
	pla 

	; Ignore key up events
	bpl :+
	rts

	; Transfer key code to Y
:	tay

	; Pause/break key?
	cmp #KEYCODE_PAUSEBRK
	bne :+

	ldx #$03 * 2 ; stop (-> run)
	lda shflag
	lsr ; shift -> C
	txa
	ror
	jmp kbdbuf_put

	; Calculate shift state from mode and modifiers
:	lda mode
	asl
	asl ; bit 6 = ISO mode on off
	php
	lda shflag
	and #(255-MODIFIER_4080-MODIFIER_CAPS)
	asl
	plp
	ror

	; Is Caps Lock active?
	tax
	lda shflag
	and #MODIFIER_CAPS
	jne handle_caps		; Yes
	txa

	; Find keymap table
cont: 	jsr find_table
	bcs @notab		; C = 1 => table found

; For some encodings (e.g. US-Mac), Alt and AltGr is the same, so
; the tables use modifiers $C6 (Alt/AltGr) and $C7 (Shift+Alt/AltGr).
; If we don't find a table and the modifier is (Shift+)Alt/AltGr,
; try these modifier codes.
	lda kbtmp
	cmp #$82
	beq @again
	cmp #$83
	beq @again
	cmp #$86
	beq @again
	cmp #$87
	bne @skip
@again:	ora #$46
	jsr find_table
	bcc @skip

@notab:	lda (ckbtab),y
	beq @maybe_dead
	ldx dk_scan
	bne @combine_dead
	jmp kbdbuf_put

; unassigned key or dead key -> save it, on next keypress,
; scan dead key tables; if nothing found, it's unassigned
@maybe_dead:
	sty dk_scan
	lda kbtmp
	sta dk_shift
@skip:	rts

; combine a dead key and a second key,
; handling the special case of unsupported combinations
@combine_dead:
	pha
	jsr find_combination
	bne @found
; can't be combined -> two chars: "^" + "x" = "^x"
	lda #' '
	jsr find_combination
	beq :+
	jsr kbdbuf_put
:	pla
	bra @end
@found:	plx            ; clean up
@end:	stz dk_scan
	jmp kbdbuf_put

; use tables to combine a dead key and a second key
; In:  .A               second key
;      dk_shift/dk_scan dead key
; Out: .Z: =1 found
;          .A: ISO code
find_combination:
	pha
	lda #<deadkeys
	sta ckbtab
	lda #>deadkeys
	sta ckbtab+1
; find dead key's group
@loop1:	lda (ckbtab)
	cmp #$ff
	bne :+
	pla
	lda #0 ; end of groups
	rts
:	ldy #1
	cmp dk_shift
	bne :+
	lda (ckbtab),y
	cmp dk_scan
	beq @found1
:	iny
	lda (ckbtab),y ; skip
	clc
	adc ckbtab
	sta ckbtab
	bcc @loop1
	inc ckbtab+1
	bra @loop1
; find mapping in this group
@found1:
	iny
	lda (ckbtab),y  ; convert group length...
	sbc #3          ; (.C = 1)
	lsr
	tax             ; ...into count
	pla
@loop2:	iny
	cmp (ckbtab),y
	beq @found2
	iny
	dex
	bne @loop2
 ; not found in group
	rts             ; (.Z = 1)
@found2:
	iny
	lda (ckbtab),y  ; (.Z = 0)
	rts

; The caps table has one bit per scancode, indicating whether
; caps + the key should use the shifted or the unshifted table.
handle_caps:
	phx ; mode + shflag - caps lock - 40/80 key
	phy ; scancode

	tya
	and #7
	tay
	lda #$80
:	cpy #0
	beq :+
	lsr
	dey
	bra :-
:	tax

	pla ; scancode
	pha
	lsr
	lsr
	lsr
	tay
	txa
	and caps,y
	beq :+

	ply ; scancode
	pla ; mode + shflag - caps lock - 40/80 key
	pha
	eor #MODIFIER_SHIFT ; toggle shift bit
	lsr
	pla
	php
	lsr
	plp
	rol
	jmp cont

:	ply ; scancode
	pla
	jmp cont

find_table:
.assert keymap_data = $a000, error; so we can ORA instead of ADC and carry
	sta kbtmp
	lda #<keymap_data
	sta ckbtab
	lda #>keymap_data
	sta ckbtab+1
	ldx #TABLE_COUNT
@loop:	lda (ckbtab)
	cmp kbtmp
	beq @ret        ; .C = 1: found
	lda ckbtab
	eor #$80
	sta ckbtab
	bmi :+
	inc ckbtab+1
:	dex
	bne @loop
	clc             ; .C = 0: not found
@ret:	rts


;*****************************************
; FETCH KEY CODE:
; out: A: key code (0 = none)
;         bit 7=0 => key down, else key up
;         A = 127/255 => extended key code
;      X: Extended key code second byte
;      Z: 1 if no key
;*****************************************
fetch_key_code:
	lda ps2data_kbd_count
	beq receive_scancode_resume

	lda ps2data_kbd
	beq receive_scancode_resume

 	jmp (keyhdl) ;Jump to key event handler
receive_scancode_resume:
	rts

;*****************************************
; SET CAPS LOCK LED
;*****************************************
set_caps_led:
	ldx #I2C_ADDRESS
	ldy #I2C_KBD_CMD2
	lda #$ed
	jsr i2c_write_first_byte
	lda shflag
	and #MODIFIER_CAPS			; Caps Lock is bit 2
	lsr
	lsr
	ora #LED_NUM_LOCK			; Num Lock always on
	jsr i2c_write_next_byte
	jmp i2c_write_stop

modifier_key_codes:
	.byt KEYCODE_LSHIFT
	.byt KEYCODE_LALT
	.byt KEYCODE_LCTRL
	.byt KEYCODE_LGUI
	.byt KEYCODE_RSHIFT
	.byt KEYCODE_RALT
	.byt KEYCODE_RCTRL
	.byt KEYCODE_RGUI
	.byt KEYCODE_SCRLCK

modifier_shift_states:
	.byt MODIFIER_SHIFT
	.byt MODIFIER_ALT
	.byt MODIFIER_CTRL
	.byt MODIFIER_WIN
	.byt MODIFIER_SHIFT
	.byt MODIFIER_ALTGR
	.byt MODIFIER_CTRL
	.byt MODIFIER_WIN
	.byt MODIFIER_4080
