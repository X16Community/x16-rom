.ifndef I2C_INC
I2C_INC=1 

KBD_2BYTE_CMD=$1A	; Send a 2 byte command to the keyboard
KBD_SET_LEDS_CMD=$ED	; Set LEDs command

pr = VIA1+1
ddr = VIA1+3

SDA = (1 << 0)
SCL = (1 << 1)

;---------------------------------------------------------------
; scl_high
;
; Function: Release I2C clock signal and let pullups float it to
;           logic 1 level.
;
; I2C Exit:  SDA: unchanged
;            SCL: Z
;
; Uses: .A
;---------------------------------------------------------------
.macro SCL_HIGH
	lda	#SCL
	trb	ddr
:
	lda	pr
	and	#SCL
	beq	:-
.endmacro

;---------------------------------------------------------------
; scl_low
;
; Function: Actively drive I2C clock low
;
; I2C Exit:  SDA: unchanged
;            SCL: 0
;
; Uses: .A
;---------------------------------------------------------------
.macro SCL_LOW
	lda	#SCL
	tsb	ddr
.endmacro

;---------------------------------------------------------------
; sda_high
;
; Function: Release SDA signal and let pull up resistors return
;           it to logic 1 level
;
; I2C Exit:  SDA: Z
;            SCL: unchanged
;
; Uses: .A
;---------------------------------------------------------------
.macro SDA_HIGH
	lda	#SDA
	trb	ddr
.endmacro

;---------------------------------------------------------------
; sda_low
;
; Function: Actively drive the SDA signal low
;
; I2C Exit:  SDA: 0
;            SCL: unchanged
;
; Uses: .A
;---------------------------------------------------------------
.macro SDA_LOW
	lda	#SDA
	tsb	ddr
.endmacro

;---------------------------------------------------------------
; send_bit
;
; Function: Send a single bit over I2C.
; INPUT:	.C    bit value to send.
;
; I2C Exit: SDA: Z if C is set;
;                0 if C is clear
;           SCL: 0
;
; Uses: .A
;---------------------------------------------------------------
.macro SEND_BIT
.scope
	bcs	one
	SDA_LOW
	bra	two
one:	SDA_HIGH
two:	SCL_HIGH
	SCL_LOW
.endscope
.endmacro

;---------------------------------------------------------------
; rec_bit
;
; Function: Clock in a single bit from a device over I2C
;
; Return:    c    bit value received
;
; I2C Exit:  SDA: Z
;            SCL: 0
;
; Uses .A
;---------------------------------------------------------------
.macro REC_BIT
	SDA_HIGH
	SCL_HIGH
	lda	pr
	lsr
	SCL_LOW
.endmacro

;---------------------------------------------------------------
; i2c_init
;
; Function: Configure VIA for being an I2C controller.
;
; I2C Exit:  SDA: Z
;            SCL: Z
;
; Uses: .A
;---------------------------------------------------------------
.macro I2C_INIT
	lda	#(SDA | SCL)
	trb	pr
	SDA_HIGH
	SCL_HIGH
.endmacro

;---------------------------------------------------------------
; i2c_brief_delay
;
; Function: delay CPU execution to give I2C signals a chance to
;           settle and devices to respond.
;
; Uses: .A
;---------------------------------------------------------------
.macro I2C_BRIEF_DELAY
	lda	#3		; 2 clocks
:	nop			; 2 clocks
	dec			; 2 clocks
	bne	:-		; 3/2 clocks
.endmacro

;---------------------------------------------------------------
; i2c_start
;
; Function: Signal an I2C start condition. The start condition
;           drives the SDA signal low prior to driving SCL low.
;           Start/Stop is the only time when it is legal to for
;           SDA to change while SCL is high. Both SDA and SCL
;           will be in the LOW state at the end of this function.
;
; I2C Exit:  SDA: 0
;            SCL: 0
;
; Uses: .A
;---------------------------------------------------------------
.macro I2C_START
	SDA_LOW
	I2C_BRIEF_DELAY
	SCL_LOW
.endmacro

;---------------------------------------------------------------
; i2c_stop
;
; Function: Signal an I2C stop condition. This is done by driving
;           SDA high while SCL high.
;
; I2C Exit:  SDA: Z
;            SCL: Z
;
; Uses: .A
;---------------------------------------------------------------
.macro I2C_STOP
	SDA_LOW
	I2C_BRIEF_DELAY
	SCL_HIGH
	I2C_BRIEF_DELAY
	SDA_HIGH
	I2C_BRIEF_DELAY
.endmacro

;---------------------------------------------------------------
; i2c_write
;
; Function: Write a single byte over I2C
;
; Pass:      a    byte to write
;
; Return:    c    0 if ACK, 1 if NAK
;
; I2C Exit:  SDA: Z
;            SCL: 0
;
; Uses: .A, .X, .Y
;---------------------------------------------------------------
.macro I2C_WRITE
.scope
	ldx	#8
loop:	rol
	tay
	SEND_BIT
	tya
	dex
	bne loop
	REC_BIT
.endscope
.endmacro

;---------------------------------------------------------------
; i2c_write_byte
;
; Function: Write a byte value to an offset of an I2C device
;
; Pass:      a    value
;            x    7-bit device address
;            y    offset
;
; Return:    c	  1 on error (NAK)
;
; Uses: .A, .X, .Y
;---------------------------------------------------------------
.macro I2C_WRITE_BYTE val, addr, offs
.scope
	I2C_INIT
	I2C_START
	lda	#addr
	asl
	I2C_WRITE
	bcc	:+
	jmp	error
:	lda	#offs
	I2C_WRITE
	lda	#val
	I2C_WRITE
	I2C_STOP
	clc
	bra	end
error:	sec
end:
.endscope
.endmacro

.macro I2C_WRITE_FIRST_BYTE val, addr, offs
.scope
	I2C_INIT
	I2C_START
	lda	#addr
	asl
	I2C_WRITE
	bcc	:+
	jmp	error
:	lda	#offs
	I2C_WRITE
	lda	#val
	I2C_WRITE
	bra	end
error:	sec
end:
.endscope
.endmacro

.macro KBD_WRITE val
	I2C_WRITE_FIRST_BYTE I2C_KBD_VAL, I2C_SMC, I2C_KBD_CMD2
	ldx	#val
	lda	kbd_bin_tbl,x
	I2C_WRITE
	I2C_STOP
.endmacro

.macro I2C_NACK
	sec
	SEND_BIT
.endmacro

.macro I2C_READ
.scope
	ldx #8
loop:	tay
	REC_BIT
	tya
	rol
	dex
	bne	loop
.endscope
.endmacro

.macro I2C_READ_FIRST_BYTE addr, offs
.scope
	I2C_INIT
	I2C_START		; SDA -> LOW, (wait 5 us), SCL -> LOW, (no wait)
	lda	#(addr*2)
	I2C_WRITE
	bcc	:+
	jmp	err
:	lda	#offs
	I2C_WRITE
	I2C_STOP
	I2C_START
	lda	#(addr*2)+1
	I2C_WRITE
	I2C_READ
	; A contains value transfer to X
	tax
	clc
	bra	end
err:
	I2C_STOP
	sec
end:
.endscope
.endmacro

.macro I2C_READ_BYTE addr, offs
.scope
	I2C_READ_FIRST_BYTE addr, offs
	bcs	err
	I2C_NACK
	I2C_STOP
	clc
	bra	end
err:	sec
end:
.endscope
.endmacro
.endif
