.include "banks.inc"
.include "regs.inc"
.include "io.inc"

.segment "PS2KBD"

I2C_ADDR = $42
CMD_SET_DFLT_READ_OP = $40
CMD_GET_KEYCODE_FAST = $41
CMD_GET_PS2DATA_FAST = $43

.import i2c_direct_read, i2c_read_next_byte, i2c_read_stop, i2c_write_byte
.export ps2data_fetch, ps2data_kbd, ps2data_kbd_count, ps2data_mouse, ps2data_mouse_count
.export ps2data_keyboard_and_mouse, ps2data_keyboard_only


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
	lda ram_bank
	pha
	stz ram_bank
	stz ps2data_mouse_size
	pla
	sta ram_bank

	; Send command
	ldx #I2C_ADDR
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
	ldx ram_bank
	phx
	stz ram_bank
	sta ps2data_mouse_size
	plx
	stx ram_bank
	
	; Send command
	ldx #I2C_ADDR
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

	; Fetch data from SMC
	ldx #I2C_ADDR
	jsr i2c_direct_read
	bcs exit
	
	; Store keycode
	sta ps2data_kbd
	inc ps2data_kbd_count

	; Check if to read mouse packet
	lda ps2data_mouse_size
	beq done

	; Mouse packet byte 0
	jsr i2c_read_next_byte
	sta ps2data_mouse
	beq done ; Abort if first byte is a zero
	
	; Mouse packet byte 1
	jsr i2c_read_next_byte
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

.segment "KVARSB0"
	ps2data_kbd: .res 1
	ps2data_kbd_count: .res 1
	ps2data_mouse: .res 4
	ps2data_mouse_count: .res 1
	ps2data_mouse_size: .res 1