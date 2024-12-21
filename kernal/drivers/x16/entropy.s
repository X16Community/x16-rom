;----------------------------------------------------------------------
; X16 Entropy Driver
;----------------------------------------------------------------------
; (C)2020 Michael Steil, License: 2-clause BSD

.include "io.inc"

.export entropy_init, entropy_get

.segment "ENTROPY"

;---------------------------------------------------------------
; entropy_init
;
; Function:  Initialize entropy generator
;
;---------------------------------------------------------------
entropy_init:
	lda #$ff
	sta d1t1l    ; max value: $ffff
	sta d1t1h
	lda #$40     ; set t1 free run
	sta d1acr
	rts

;---------------------------------------------------------------
; entropy_get
;
; Function:  Return 24 random bits
;
; Return:    a    random value
;            x    random value
;            y    random value
;---------------------------------------------------------------
; We only have two bytes of entropy from the timer, so we
; also return the XOR with the current scan line as 3rd byte
;            a    timer lo eor rotated scanline
;            x    timer hi
;            y    timer lo + timer hi
; Timer lo is read twice, so there will be some difference.
entropy_get:
	lda d1t1h
	tax
	adc d1t1l ; feed in .C from user
	tay
	lda VERA_IRQ_LINE_L
	rol
	eor d1t1l
	rts
