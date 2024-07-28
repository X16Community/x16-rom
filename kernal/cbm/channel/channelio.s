;----------------------------------------------------------------------
; Channel: I/O
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

setnam	sta fnlen
	stx fnadr
	sty fnadr+1
	rts

setlfs	sta la
	stx fa
	sty sa
	rts

setmsg	sta msgflg
readst	lda status
udst	ora status
	sta status
settmo	rts

;***************************************
;* getin -- get character from channel *
;*      channel is determined by dfltn.*
;* if device is 0, keyboard queue is   *
;* examined and a character removed if *
;* available.  if queue is empty, z    *
;* flag is returned set.  devices 1-31 *
;* advance to basin.                   *
;***************************************
;
ngetin	lda dfltn       ;check device
	bne gn10        ;not keyboard
;
	jmp kbdbuf_get  ;go remove a character
;
gn10	cmp #2          ;is it rs-232
	bne bn10        ;no...use basin

gn232	sec         ;no rs232
	rts

;***************************************
;* basin-- input character from channel*
;*     input differs from get on device*
;* #0 function which is keyboard. the  *
;* screen editor makes ready an entire *
;* line which is passed char by char   *
;* up to the carriage return.  other   *
;* devices are:                        *
;*      0 -- keyboard                  *
;*      1 -- cassette #1               *
;*      2 -- rs232                     *
;*      3 -- screen                    *
;*   4-31 -- serial bus                *
;***************************************
;
nbasin	lda dfltn       ;check device
	bne bn10        ;is not keyboard...
;
;input from keyboard
;
	lda pntr        ;save current...
	sta lstp        ;... cursor column
	lda tblx        ;save current...
	sta lsxp        ;... line number
	jmp loop5       ;blink cursor until return
;
bn10	cmp #3          ;is input from screen?
	bne bn20        ;no...
;
	sta crsw        ;fake a carriage return
	lda lnmx        ;say we ended...
	sta indx        ;...up on this line
	jmp loop5       ;pick up characters
;
bn20	bcs bn30        ;devices >3
;
;input from cassette buffers
;
	sec             ;no tape or rs232
	rts

;input from serial bus
;
bn30	lda status      ;status from last
	beq bn35        ;was good
bn31	lda #$d         ;bad...all done
bn32	clc             ;valid data
bn33	rts
;
bn35	jmp acptr       ;good...handshake

;***************************************
;* bsout -- out character to channel   *
;*     determined by variable dflto:   *
;*     0 -- invalid                    *
;*     1 -- cassette #1                *
;*     2 -- rs232                      *
;*     3 -- screen                     *
;*  4-31 -- serial bus                 *
;***************************************
;
nbsout	pha             ;preserve .a
	lda dflto       ;check device
	cmp #3          ;is it the screen?
	bne bo10        ;no...
;
;print to crt
;
	pla             ;restore data
	jmp prt         ;print on crt
;
bo10
	pla
	bcc bo20        ;device 1 or 2
;
;print to serial bus
;
	jmp ciout
;
;print to cassette devices
;
bo20	sec ; no tape or rs232
	rts

; rsr 5/12/82 fix bsout for no reg affect but errors
