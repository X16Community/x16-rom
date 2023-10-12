;----------------------------------------------------------------------
; I2C Driver
;----------------------------------------------------------------------
; (C)2015-2022 Dieter Hauer, Michael Steil, Joe Burks
; License: 2-clause BSD

.include "io.inc"
.include "regs.inc"

pr  = d1pra
ddr = d1ddra
SDA = (1 << 0)
SCL = (1 << 1)

.segment "I2CMUTEX"
i2c_mutex: .res 1

.segment "I2C"

.export i2c_read_byte, i2c_write_byte, i2c_batch_read, i2c_batch_write
.export i2c_read_first_byte, i2c_read_next_byte, i2c_read_stop
.export i2c_write_first_byte, i2c_write_next_byte, i2c_write_stop
.export i2c_restore, i2c_mutex

__I2C_USE_INLINE_FUNCTIONS__=1

; Cost vs. benefit of inline I2C pin functions
;
;                         JSR     Inline       Diff
;                       -----------------------------------
; Size (bytes)          |  264  |   360    |   96 (+36%) |
; Kbd Scan (us @ 8MHz)  |  497  |   284    |  152 (-43%)  |
;                       -----------------------------------
;
; The keyboard scan code read time was used as the benchmark
; since that is normally done once every VSYNC, whether a
; scancode is available or not.

;---------------------------------------------------------------
; scl_high
;
; Function: Release I2C clock signal and let pullups float it to
;           logic 1 level.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: unchanged
;            SCL: Z
;---------------------------------------------------------------
.if __I2C_USE_INLINE_FUNCTIONS__

.macro scl_high
.scope
	lda #SCL
	trb ddr

wait_for_clk:
	lda pr
	and #SCL
	beq wait_for_clk
.endscope
.endmacro

.else

.macro scl_high
	jsr _scl_high
.endmacro

.endif

;---------------------------------------------------------------
; scl_low
;
; Function: Actively drive I2C clock low
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: unchanged
;            SCL: 0
;---------------------------------------------------------------
.if __I2C_USE_INLINE_FUNCTIONS__
.macro scl_low
	lda #SCL
	tsb ddr
.endmacro
.else
.macro scl_low
	jsr _scl_low
.endmacro
.endif

;---------------------------------------------------------------
; sda_high
;
; Function: Release SDA signal and let pull up resistors return
;           it to logic 1 level
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: Z
;            SCL: unchanged
;---------------------------------------------------------------
.if __I2C_USE_INLINE_FUNCTIONS__
.macro sda_high
	lda #SDA
	trb ddr
.endmacro
.else
.macro sda_high
	jsr _sda_high
.endmacro
.endif

;---------------------------------------------------------------
; sda_low
;
; Function: Actively drive the SDA signal low
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: 0
;            SCL: unchanged
;---------------------------------------------------------------
.if __I2C_USE_INLINE_FUNCTIONS__
.macro sda_low
	lda #SDA
	tsb ddr
.endmacro
.else
.macro sda_low
	jsr _sda_low
.endmacro
.endif

;---------------------------------------------------------------
; send_bit
;
; Function: Send a single bit over I2C.
; Pass:      C    bit value to send.
;
; Return:    None
;
; I2C Exit: SDA: Z if C is set;
;                0 if C is clear
;           SCL: 0
;---------------------------------------------------------------
.macro send_bit
.if __I2C_USE_INLINE_FUNCTIONS__
	bcs @1
	sda_low
	bra @2
@1:	sda_high
@2:	scl_high
	scl_low
.else
	jsr _send_bit
.endif
.endmacro

;---------------------------------------------------------------
; rec_bit
;
; Function: Clock in a single bit from a device over I2C
;
; Pass:      None
;
; Return:    c    bit value received
;
; I2C Exit:  SDA: Z
;            SCL: 0
;---------------------------------------------------------------
.macro rec_bit
.if __I2C_USE_INLINE_FUNCTIONS__
	sda_high		; Release SDA so that device can drive it
	scl_high
	lda pr
	.assert SDA = (1 << 0), error, "update the shift instructions if SDA is not bit #0"
	lsr             ; bit -> C
	scl_low
.else
	jsr _rec_bit
.endif
.endmacro

;---------------------------------------------------------------
; i2c_ack
;
; Function: Send an I2C ACK.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit: SDA: Z
;           SCL: 0
;---------------------------------------------------------------
.macro i2c_ack
	clc
	send_bit
.endmacro

;---------------------------------------------------------------
; i2c_nack
;
; Function: Send an I2C NAK.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit: SDA: Z
;           SCL: 0
;---------------------------------------------------------------
.macro i2c_nack
	sec
	send_bit
.endmacro

;---------------------------------------------------------------
; i2c_read_byte
;
; Function:
;
; Read sequence:
;   Start condition
;     > 7 bits of device address, MSb first
;     > 1 bit = 0 (write indicator bit)
;     < Read ACK/NAK from device
;     > 8 bits of register offset
;   Stop condition
;   Start condition
;     > 7 bits of device address, MSb first
;     > 1 bit = 1 (read indicator bit)
;     < Read ACK/NAK from device (this is not done by the kernel!!)
;     < Read 8 bits from device
;     > NAK to indicate end of requested bytes from device
;   Stop condition
;
; Pass:      x    7-bit device address
;            y    offset
;
; Return:    a    value
;            x    device (preserved)
;            y    offset (preserved)
;            c    1 on error (NAK)
;---------------------------------------------------------------
i2c_read_byte:
	php
	sei
	phx
	phy

	lda i2c_mutex
	bne @err

	jsr i2c_read_first_byte
	bcs @err
	pha
	jsr i2c_read_stop
	pla
	
	ply
	plx
	plp
	
	cmp #0
	clc
	
	rts

@err:
	ply
	plx
	plp
	sec
	lda #$ee
	rts

;---------------------------------------------------------------
; i2c_read_first_byte
;
; Function: Reads one byte over I2C without stopping the
;           transmission. Subsequent bytes may be read by
;           i2c_read_next_byte. When done, call function
;           i2c_read_stop to close the I2C transmission.
;
; Pass:      x    7-bit device address
;            y    offset
;
; Return:    a    value
;            c    1 on error (NAK)
;---------------------------------------------------------------
i2c_read_first_byte:
	lda i2c_mutex
	beq @1
	sec
	rts

@1:	jsr i2c_init
	jsr i2c_start                        ; SDA -> LOW, (wait 5 us), SCL -> LOW, (no wait)
	txa                ; device
	asl
	pha                ; device * 2
	phy
	jsr i2c_write
	ply
	bcs @error
	plx                ; device * 2
	tya                ; offset
	phx                ; device * 2
	jsr i2c_write
	jsr i2c_stop
	jsr i2c_start
	pla                ; device * 2
	inc
	jsr i2c_write
	bra i2c_read_next_byte_after_ack
	
@error:
	pla
	jsr i2c_stop
	lda #$ee
	sec
	rts

;---------------------------------------------------------------
; i2c_read_next_byte
;
; Function:	After the first byte has been read by 
;			i2c_read_first_byte, this function may be used to
;			read one or more subsequent bytes without 
;			restarting the I2C transmission
;
; Pass:		Nothing
;
; Return:	a    value
;---------------------------------------------------------------
i2c_read_next_byte:
	lda i2c_mutex
	beq :+
	lda #$ee
	rts

:	i2c_ack

i2c_read_next_byte_after_ack:
	jsr i2c_read
	cmp #0
	clc
	rts
	
;---------------------------------------------------------------
; i2c_read_stop
;
; Function:	Stops I2C transmission that has been initialized
;			with i2c_read_first_byte
;
; Pass:		Nothing
;
; Return:	Nothing
;---------------------------------------------------------------
i2c_read_stop:
	lda i2c_mutex
	beq :+
	rts
:	i2c_nack
	jmp i2c_stop

;---------------------------------------------------------------
; i2c_write_byte
;
; Function: Write a byte value to an offset of an I2C device
;
; Pass:      a    value
;            x    7-bit device address
;            y    offset
;
; Return:    x    device (preserved)
;            y    offset (preserved)
;            c	  1 on error (NAK)
;---------------------------------------------------------------
i2c_write_byte:
	php
	sei
	phx
	phy

	ldy i2c_mutex
	bne @error
	
	ply
	phy

	jsr i2c_write_first_byte
	bcs @error
	jsr i2c_write_stop

	ply
	plx
	plp
	clc
	rts

@error:
	ply
	plx
	plp
	sec
	rts

;---------------------------------------------------------------
; i2c_write_first_byte
; 
; Function: Writes one byte over I2C without stopping the
;           transmission. Subsequent bytes may be written by
;           i2c_write_next_byte. When done, call function
;           i2c_write_stop to close the I2C transmission.
;
; Pass:      a    value
;            x    7-bit device address
;            y    offset
;
; Return:    c    1 on error (NAK)
;---------------------------------------------------------------
i2c_write_first_byte:
	pha                ; value
	lda i2c_mutex
	bne @error

	jsr i2c_init
	jsr i2c_start
	txa                ; device
	asl
	phy
	jsr i2c_write
	ply
	bcs @error
	tya                ; offset
	phy
	jsr i2c_write
	ply
	pla                ; value
	jsr i2c_write
	clc
	rts

@error:
	pla                ; value
	sec
	rts
;---------------------------------------------------------------
; i2c_write_next_byte
;
; Function:	After the first byte has been written by 
;			i2c_write_first_byte, this function may be used to
;			write one or more subsequent bytes without 
;			restarting the I2C transmission
;
; Pass:		a    value
;
; Return:	Nothing
;---------------------------------------------------------------
i2c_write_next_byte:
	ldx i2c_mutex
	beq :+
	rts
:	jmp i2c_write

;---------------------------------------------------------------
; i2c_write_stop
;
; Function:	Stops I2C transmission that has been initialized
;			with i2c_write_first_byte
;
; Pass:		Nothing
;
; Return:	Nothing
;---------------------------------------------------------------
i2c_write_stop:
	lda i2c_mutex
	beq :+
	rts
:	jmp i2c_stop


;---------------------------------------------------------------
; Copyright (c) 2015, Dieter Hauer
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
; ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
;---------------------------------------------------------------
i2c_write:
	ldx #8
i2c_write_loop:
	rol
	tay
	send_bit
	tya
	dex
	bne i2c_write_loop
	rec_bit     ; C = 0: success
	rts

;---------------------------------------------------------------
; i2c_read
;
; Function: Read a single byte from a device over I2C
;
; Pass:      None
;
; Return:    a    value from device
;
; I2C Exit:  SDA: Z
;            SCL: 0
;---------------------------------------------------------------
i2c_read:
	ldx #8
i2c_read_loop:	
	tay
	rec_bit
	tya
	rol
	dex
	bne i2c_read_loop
	rts

;---------------------------------------------------------------


;---------------------------------------------------------------
; i2c_stop
;
; Function: Signal an I2C stop condition. This is done by driving
;           SDA high while SCL high.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: Z
;            SCL: Z
;---------------------------------------------------------------
i2c_stop:
	sda_low
	jsr i2c_brief_delay
	scl_high
	jsr i2c_brief_delay
	sda_high
	jsr i2c_brief_delay
	rts

;---------------------------------------------------------------
; i2c_start
;
; Function: Signal an I2C start condition. The start condition
;           drives the SDA signal low prior to driving SCL low.
;           Start/Stop is the only time when it is legal to for
;           SDA to change while SCL is high. Both SDA and SCL
;           will be in the LOW state at the end of this function.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: 0
;            SCL: 0
;---------------------------------------------------------------
i2c_start:
	sda_low
	jsr i2c_brief_delay
	scl_low
	rts

;---------------------------------------------------------------
; i2c_init
;
; Function: Configure VIA for being an I2C controller.
;
; Pass:      None
;
; Return:    None
;
; I2C Exit:  SDA: Z
;            SCL: Z
;---------------------------------------------------------------
i2c_init:
	lda #SDA | SCL
	trb pr
	sda_high
	scl_high
	rts

.if !__I2C_USE_INLINE_FUNCTIONS__
_sda_low:
	lda #SDA
	tsb ddr
	rts

_sda_high:
	lda #SDA
	trb ddr
	rts

_scl_high:
	lda #SCL
	trb ddr
:	lda pr     ; Wait for clock to go high
	and #SCL
	beq :-
	rts

_scl_low:
	lda #SCL
	tsb ddr
	rts

_send_bit:
	bcs @1
	sda_low
	bra @2
@1:	sda_high
@2:	scl_high
	scl_low
	rts

_rec_bit:
	sda_high		; Release SDA so that device can drive it
	scl_high
	lda pr
	.assert SDA = (1 << 0), error, "update the shift instructions if SDA is not bit #0"
	lsr             ; bit -> C
	scl_low
	rts

.endif

;---------------------------------------------------------------
; i2c_brief_delay
;
; Function: delay CPU execution to give I2C signals a chance to
;           settle and devices to respond.
;
; Pass:      None
;
; Return:    None
;---------------------------------------------------------------
i2c_brief_delay:
	pha
	pla
	pha
	pla
	rts

;---------------------------------------------------------------
; i2c_batch_read
;
; Function:
;   Read a batch of data into a RAM buffer
;
; Pass:      x    7-bit device address
;	     r0   pointer to start of data buffer
;            r1   number of bytes to read
;            c    0: Advance buffer pointer on each byte
;                 1: Buffer pointer not advanced
;
; Return:    x    device (preserved)
;            r0   pointer to start of data buffer (preserved)
;            r1   number of bytes to read (preserved)
;            c    1 on error (NAK)
;---------------------------------------------------------------
i2c_batch_read:
	; Preserve input values on stack
	lda r0
	pha
	lda r0+1
	pha
	lda r1
	pha
	lda r1+1
	pha

	phx
	php

	; Exit if number of bytes to read is 0
	lda r1
	ora r1+1
	bne @br1

	plp
	plx
	clc
	jmp i2c_batch_read_restore

@br1:	; Init I2C transmission
	lda #1
	sta i2c_mutex

	sei
	jsr i2c_init
	jsr i2c_start
	
	plp
	pla                ; 7 bit address
	pha
	php

	asl                ; device * 2
	ina                ; set read bit
	jsr i2c_write
	bcc i2c_batch_read_loop

@err:	sei
	jsr i2c_stop
	plp
	plx
	sec
	bra i2c_batch_read_restore

i2c_batch_read_loop:
	; Read one byte and store it in the buffer
	jsr i2c_read
	sta (r0)

	; Advance buffer pointer, if so requested (function called with C=0)
	plp
	php
	bcs @br3

	inc r0
	bne @br2
	inc r0+1

	; Rewind buffer pointer and increment RAM bank if address >= $C000
@br2:	lda r0+1
	cmp #$c0
	bcc @br3
	lda #$a0
	sta r0+1
	inc ram_bank

	; Decrement byte request counter
@br3:	lda r1
	bne @br4
	dec r1+1
@br4:	dec r1

	; Check if requested number of bytes have been read
	lda r1
	ora r1+1
	beq i2c_batch_read_exit

	; Acknowledge, and fetch next byte
	i2c_ack
	bra i2c_batch_read_loop

i2c_batch_read_exit:
	i2c_nack
	sei
	jsr i2c_stop
	
	plp
	plx
	clc

i2c_batch_read_restore:
	pla
	sta r1+1
	pla
	sta r1
	pla
	sta r0+1
	pla
	sta r0
	stz i2c_mutex
	rts

;---------------------------------------------------------------
; i2c_batch_write
;
; Function:
;   Write a batch of data from a RAM buffer
;
; Pass:      x    7-bit device address
;	     r0   pointer to start of data buffer
;            r1   number of bytes to write
;
; Return:    x    device (preserved)
;            r0   pointer to start of data buffer (preserved)
;            r1   number of bytes to write (preserved)
;            r2   number of bytes written
;            c    1 on error (NAK)
;---------------------------------------------------------------
i2c_batch_write:
	; Preserve input on stack
	lda r0
	pha
	lda r0+1
	pha
	lda r1
	pha
	lda r1+1
	pha
	phx
	php

	; Reset counter
	stz r2
	stz r2+1

	; Exit if number of bytes to write is 0
	lda r1
	ora r1+1
	bne @1
	plp
	clc
	bra @restore

@1:	; Init I2C transmission
	lda #1
	sta i2c_mutex

	sei
	jsr i2c_init
	jsr i2c_start
	plp
	pla                ; 7 bit device address
	pha
	php
	asl                ; device * 2
	jsr i2c_write
	bcs @err

@loop:	; Write one byte
	lda (r0)
	jsr i2c_write
	bcs @err

	; Increment byte count written
	inc r2
	bne @2
	inc r2+1

@2:	; Advance buffer pointer
	inc r0
	bne @3
	inc r0+1

@3:	; Rewind buffer pointer if address >= $C000
	lda r0+1
	cmp #$c0
	bcc @4
	lda #$a0
	sta r0+1
	inc ram_bank

@4:	; Decrement bytes to write counter
	lda r1
	bne @5
	dec r1+1
@5:	dec r1

	; Check if all requested bytes have been written
	lda r1
	ora r1+1
	bne @loop

@exit:	sei
	jsr i2c_stop
	plp
	clc
	bra @restore

@err:	sei
	jsr i2c_stop
	plp
	sec

@restore:
	plx
	pla
	sta r1+1
	pla
	sta r1
	pla
	sta r0+1
	pla
	sta r0
	stz i2c_mutex
	rts

;---------------------------------------------------------------
; i2c_restore
;
; Function:
;   Restore i2c driver
;---------------------------------------------------------------
i2c_restore:
	stz i2c_mutex
	jmp i2c_stop