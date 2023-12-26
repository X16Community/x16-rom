.include "kernal.inc"

.import crambank
.import lp_dopause
.import lp_screenpause

.export pause

ram_bank = 0
inputbuf = $0200 	; BASIC input buffer

PAGEDOWN = $02
SPACEBAR = $20
CURSORDOWN = $11
CLEARSCREEN = $93
BREAK = $03

;pause:      ; my pause - replaced with JimmyDasbo's pause
; 	jmp listp
;    php 
;    phx
;    phy
;    pha
;    jsr getin
;    cmp #SPACEBAR ; $20
;    bne exit
;loop:
;    jsr getin
;    beq loop
;exit:
;    pla
;    ply
;    plx
;    plp
;    rts



;******************************************************************
;
; LIST [ xxxx - xxxx ]
; List BASIC program currently in memory
; Spacebar will pause/unpause
; In paused mode below will work:
; PageDown will show one page at a time
; Arrow down will show one line at a time
;
;******************************************************************
.import nlines	;= $0387			; These variables are in KERNAL space
.import llen	;= $0386			; Could not figure out how to import
.import tblx	;= $0383

pause:
	php			; Save cpu flags as they are used after this function
	pha			; BASIC uses the a,x&y registers, they will be
	phy			; restored before returning from this function
	phx
	stz	ram_bank	; Set RAM bank 0 for variables

	lda	inputbuf		;$200		; Use BASIC input buffer to see if first run
	beq	@notfirst
	stz	inputbuf		;$200
	stz	lp_dopause	; Initialize variables
	stz	lp_screenpause
@notfirst:
	jsr	getin        ;$FFE4		; GETIN
	cmp	#SPACEBAR	;$20		; Spacebar
	bne	@cont
	inc	lp_dopause
	jmp	@end
@cont:	lda	lp_screenpause
	beq	@islinepause
	; Handle screen pause
	jsr	@ateos		; Check if we are at end of screen
	bcc	@end
	inc	lp_dopause	; Pause the listing
	stz	lp_screenpause
	bra	@end
@islinepause:
	lda	lp_dopause	; Check if we need to pause the listing
	beq	@end
@pauseloop:
	jsr	getin		;$FFE4		; GETIN
	cmp	#BREAK		;$03		; Is STOP (CTRL+C)?
	bne	@space
	jsr	kbdbuf_put	;$FEC3		; Push STOP back in keyboard buffer
	bra	@end		; So BASIC can handle it
@space:	cmp	#SPACEBAR 	;$20		; Is Space ?
	bne	@pgdown
	stz	lp_dopause	; No more pausing until space is pressed again
	stz	lp_screenpause
	bra	@end
@pgdown:cmp	#PAGEDOWN	;$02		; Is Pagedown ?
	bne	@isarrowdown
	; handle page down
	lda	llen		; If number of columns is less than 23
	cmp	#23		; pagedown should work the sam as 
	bcc	@end		; arrow down
	stz	lp_dopause	; Indicate we need to pause at end of screen
	inc	lp_screenpause
	jsr	@ateos		; Check if we are at end of screen
	bcc	@end
	lda	#CLEARSCREEN	;$93		; Clear screen
	jsr	bsout  		;$FFD2		; CHROUT	
	bra	@end
@isarrowdown:
	cmp	#CURSORDOWN	;$11		; Is cursor down ?
	bne	@pauseloop
	; Let BASIC do its thing and show the next line
@end:
	lda	crambank	; Restore RAM bank
	sta	ram_bank
	plx
	ply			; Restore a,y registers
	pla
	plp			; restore cpu flags
	rts
;******************************************************************
;
; Function to figure out if we are as far down the screen as can
; be without scrolling.
; Trying to take into consideration that lines can actually be
; longer than 80 characters because of abbreviated keywords
;
;******************************************************************
@ateos:
	ldy	lp_dopause	; Save value as variable is borrowed
				; for comparison use
	ldx	nlines		; In any screenmode we need to go
	dex			; back at least 6 to prevent scrolling
	dex
	dex
	dex
	dex
	dex
	lda	llen
@is80:	cmp	#64		; Is it 64 or 80 columns?
	bcc	@is32
	stx	lp_dopause	; Store calculated end of screen
	lda	tblx
	cmp	lp_dopause	; Compare current line with eos
	sty	lp_dopause
	rts
@is32:	dex			; Is it 32 or 40 columns?
	dex			; For 32 column mode we need 
	dex			; more lines to prevent scrolling
	dex
	stx	lp_dopause	; Store calculated end of screen
	lda	tblx
	cmp	lp_dopause	; Compare current line with eos
	sty	lp_dopause
	rts