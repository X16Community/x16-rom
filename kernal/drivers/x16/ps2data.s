.include "banks.inc"
.include "regs.inc"
.include "io.inc"

.segment "PS2KBD"

I2C_ADDR = $42
CMD_GET_KEYCODE = $07
CMD_GET_MOUSE_MOV = $21
CMD_GET_VER1 = $30
CMD_GET_VER2 = $31
CMD_GET_VER3 = $32
CMD_SET_DFLT_READ_OP = $40
CMD_GET_KEYCODE_FAST = $41
CMD_GET_PS2DATA_FAST = $43

PS2DATA_OLD_STYLE = $01
PS2DATA_NEW_STYLE = $02

.import i2c_read_byte, i2c_read_first_byte, i2c_direct_read, i2c_read_next_byte, i2c_read_stop, i2c_write_byte
.export ps2data_init, ps2data_fetch, ps2data_kbd, ps2data_kbd_count, ps2data_mouse, ps2data_mouse_count
.export ps2data_keyboard_and_mouse, ps2data_keyboard_only, ps2data_raw

;---------------------------------------------------------------
; Inits ps2data functions.
;
; (1) First determine if the SMC firmware version supports the
;     new faster method to fetch keyboard and mouse data,
;     requires version >= 46.0.0
;
; (2) Second set default SMC read operation to
;     fetch keycodes only, if SMC firmare version >= 46.0.0
;
; Input:
;         Nothing
;
; Output:
;         Data fecth method stored in ps2data_style
;         - SMC version < 46.0.0 => PS2DATA_OLD_STYLE
;         - SMC version >= 46.0.0 => PS2DATA_NEW_STYLE
;---------------------------------------------------------------
ps2data_init:
	KVARS_START

	; Compare SMC firmare version major
	ldx #I2C_ADDR
	ldy #CMD_GET_VER1
	jsr i2c_read_byte
	cmp #$ff
	beq oldstyle
	cmp #46
	bcc oldstyle

newstyle:
	lda #PS2DATA_NEW_STYLE
	bra :+

oldstyle:
	lda #PS2DATA_OLD_STYLE

:	sta ps2data_style

	KVARS_END

	jmp ps2data_keyboard_only

;---------------------------------------------------------------
; Set SMC default read operation to fetch key codes only
;
; Input:
;         Nothing
; Output:
;         Nothing
;---------------------------------------------------------------
ps2data_keyboard_only:
	; Clear mouse size
	KVARS_START
	stz ps2data_mouse_size
	ldx ps2data_style
	KVARS_END

	; Exit if old style
	cpx #PS2DATA_OLD_STYLE
	bne :+
	rts

	; Send command
:	ldx #I2C_ADDR
	ldy #CMD_SET_DFLT_READ_OP
	lda #CMD_GET_KEYCODE_FAST
	jmp i2c_write_byte

;---------------------------------------------------------------
; Set SMC default read operation to fetch both key codes
; and mouse packets
;
; Input:
;         A: Mouse packet size (3 or 4 bytes)
; Output:
;         Nothing
;---------------------------------------------------------------
ps2data_keyboard_and_mouse:
	; Set mouse size
	KVARS_START
	sta ps2data_mouse_size
	ldy ps2data_style
	KVARS_END

	; Exit if old style
	cpy #PS2DATA_OLD_STYLE
	bne :+
	rts

	; Send command
:	ldx #I2C_ADDR
	ldy #CMD_SET_DFLT_READ_OP
	lda #CMD_GET_PS2DATA_FAST
	jmp i2c_write_byte

;---------------------------------------------------------------
; Fetch keyboard and mouse data from the SMC
;
; Input:
;         Nothing
; Output:
;         ps2data_kbd: Key code
;         ps2data_kbd_count: Byte count
;         ps2data_mouse: Mouse packet (max 4 bytes)
;         ps2data_mouse_count: Byte count
;---------------------------------------------------------------
ps2data_fetch:
	KVARS_START

	; Clear
	stz ps2data_kbd_count
	stz ps2data_kbd

	stz ps2data_mouse_count
	stz ps2data_mouse
	stz ps2data_mouse+1
	stz ps2data_mouse+2
	stz ps2data_mouse+3

	; Check if old style
	lda ps2data_style
	cmp #PS2DATA_OLD_STYLE
	bne @1

	; Fetch data from SMC old style
	ldx #I2C_ADDR
	ldy #CMD_GET_KEYCODE
	jsr i2c_read_byte
	bcs @3
	cmp #0
	beq @3
	bra @2

	; Fetch data from SMC new style
@1:	ldx #I2C_ADDR
	jsr i2c_direct_read
	bcs exit

	; Store keycode
@2:	sta ps2data_kbd
	inc ps2data_kbd_count

	; Check if to read mouse packet
@3:	lda ps2data_mouse_size
	beq done

	; Check if old style
	lda ps2data_style
	cmp #PS2DATA_OLD_STYLE
	bne @4

	; Read mouse packet old style
	ldx #I2C_ADDR
	ldy #CMD_GET_MOUSE_MOV
	jsr i2c_read_first_byte
	bcs done ; Abort on error
	sta ps2data_mouse
	cmp #0
	beq done ; Abort if first byte is zero
	bra @5

	; Mouse packet byte 0
@4:	jsr i2c_read_next_byte
	bcs done
	sta ps2data_mouse
	cmp #0
	beq done ; Abort if first byte is zero

	; Mouse packet byte 1
@5:	jsr i2c_read_next_byte
	sta ps2data_mouse+1

	; Mouse packet byte 2
	jsr i2c_read_next_byte
	sta ps2data_mouse+2

	; Store packet size, and check if we are done
	lda ps2data_mouse_size
	sta ps2data_mouse_count
	cmp #4
	bcc done

	; Mouse packet byte 3
	jsr i2c_read_next_byte
	sta ps2data_mouse+3

done:
	jsr i2c_read_stop

exit:
	KVARS_END
	rts

;---------------------------------------------------------------
; Fetch mouse data from memory and store it in r0-r1
; Returns key code in .A, extended code in .Y (future)
; Useful immediately after calling ps2data_fetch
; These values will only be populated by ps2data_fetch
; if mouse_config was called to enable polling the mouse
;
; Input:
;         Nothing
; Output:
;         .A: keycode (0 if none)
;         .Y: extended keycode if .A=$7F or .A=$FF (NYI)
;         .X: number of mouse bytes returned
;         r0L: mouse byte 1
;         r0H: mouse byte 2
;         r1L: mouse byte 3
;         r1H: mouse byte 4 (for Intellimice)
;         z is set if there is no mouse data
;---------------------------------------------------------------
ps2data_raw:
	KVARS_START_TRASH_A_NZ
	ldx ps2data_mouse_count
	beq @2
@1:	lda ps2data_mouse-1,x
	sta r0-1,x
	dex
	bne @1
	ldx ps2data_mouse_count
@2:
	lda ps2data_kbd_count
	beq @3
	;ldy extended keyboard code (NYI) none are defined so no need yet
	lda ps2data_kbd
	bne @4
@3:
	cpx #0
@4:
	KVARS_END
	rts

.segment "KVARSB0"
	ps2data_kbd: .res 1
	ps2data_kbd_count: .res 1
	ps2data_mouse: .res 4
	ps2data_mouse_count: .res 1
	ps2data_mouse_size: .res 1
	ps2data_style: .res 1
