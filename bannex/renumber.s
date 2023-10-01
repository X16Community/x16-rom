gototk = $89
resttk = $8c
gosutk = $8d
runtk  = $8a
thentk = $a7

esctk = $ce

ram_bank = 0
rom_bank = 1

errfc = 14
errov = 15
errid = 21
.export renumber

.importzp index, index2, txttab, chrgot, poker, chkcom
.import rencur, reninc, rennew, renold, rentmp, rentmp2
.import crambank, vartab, curlin, error

.import frmadr

.segment "ANNEX"

; REN [newstart[,increment[,oldstart]]]
; line renumber
.proc renumber: near
	lda curlin+1
	inc
	beq @imm ; ensure renumber only happens in direct mode
	ldx #errid
	jmp error
@imm:
	stz ram_bank
	lda #10
	sta rennew
	stz rennew+1
	sta reninc
	stz reninc+1
	stz renold
	stz renold+1

	jsr chrgot
	beq @go

	jsr frmadr
	lda poker
	sta rennew
	lda poker+1
	sta rennew+1

	jsr chrgot
	beq @go

	jsr chkcom
	jsr frmadr
	lda poker
	sta reninc
	lda poker+1
	sta reninc+1

	jsr chrgot
	beq @go

	jsr chkcom
	jsr frmadr
	lda poker
	sta renold
	lda poker+1
	sta renold+1

@go:
	; make sure rennew < 65280
	lda rennew+1
	inc
	beq @errlin
	; make sure reninc > 0.
	lda reninc+1
	bne @startok
	lda reninc
	bne @startok
@errlin:
	ldx #errfc
	jmp error
@startok:
	jsr renumber_tag  ; mark all of the line numbers after GOTO/GOSUB/THEN/RESTORE/RUN tokens with leading #
	bcs fail
	jsr renumber_walk ; do the actual renumber, while replacing the line numbers after GOTO/GOSUB/THEN/RESTORE/RUN tokens, padding the excess with spaces
	bcs fail
	jsr renumber_cleanup ; clean up the altered after-GOTO/GOSUB/THEN/RESTORE/RUN line numbers
	lda crambank ; restore RAM bank to user selection
	sta ram_bank
fail:
	rts
.endproc

.proc renumber_cleanup: near
	; remove spaces after and # before GOTO/GOSUB/THEN/RESTORE/RUN line number args
	; set up pointer to beginning of BASIC program
	lda txttab
	sta index2
	lda txttab+1
	sta index2+1
chkend:
	; check to see if we're at the end of the program
	lda (index2)
	ldy #1
	ora (index2),y
	beq isend
	ldy #3
culoop:
	iny
culoop2:
	lda (index2),y
	bmi tokenchk
	beq endline
	cmp #'"' ; open quote
	beq openquote
	bra culoop
openquote:
	iny
	lda (index2),y
	beq endline
	cmp #'"' ; close quote
	bne openquote
	bra culoop
skiptk:
	iny
	bra culoop
tokenchk:
	cmp #esctk
	beq skiptk
	cmp #gototk
	beq istoken
	cmp #gosutk
	beq istoken
	cmp #thentk
	beq istoken
	cmp #resttk
	beq istoken
	cmp #runtk
	beq istoken
	bra culoop
endline:
	iny
	tya
	clc
	adc index2
	sta index2
	lda index2+1
	adc #0
	sta index2+1
	bra chkend
isend:
	; relink program at the end
	jsr lnkprg
	clc
	rts
istoken:
	iny
istoken2:
	lda (index2),y
	beq endline
	cmp #' '
	beq istoken ; skip leading spaces
	cmp #','
	beq istoken ; comma separates ON GOTO type statements
	cmp #'#'
	beq target  ; remove leading #
	cmp #'0'
	bcc culoop2 ; a character other than a number (< 0)
	cmp #'9'+1
	bcs culoop2 ; a character other than a number (> 9)
chknumber:
	iny
chknumber2:
	lda (index2),y
	beq endline
	cmp #' '
	beq target2 ; shrink trailing spaces
	cmp #','
	beq istoken ; comma separates ON GOTO type statements
	cmp #'0'
	bcc culoop2 ; a character other than a number (< 0)
	cmp #'9'+1
	bcs culoop2 ; a character other than a number (> 9)
	bra chknumber
target:
	; save the current location at the first #
	tya
	clc
	adc index2
	sta index2
	sta index
	lda index2+1
	adc #0
	sta index2+1
	sta index+1
	ldy #0

	; find the first non-# character
hashloop:
	lda (index),y
	cmp #'#'
	bne :+
	iny
	bra hashloop
:
	; now copy everything back from this offset
shrinkloop1:
	lda (index),y
	sta (index)

	inc index
	bne :+
	inc index+1
:	lda index+1
	cmp vartab+1
	bcc shrinkloop1
	lda index
	cmp vartab
	bcc shrinkloop1

	ldy #0
	bra chknumber2
target2:
	; save the current location at the first space
	tya
	clc
	adc index2
	sta index2
	sta index
	lda index2+1
	adc #0
	sta index2+1
	sta index+1
	ldy #0

	; find the first non-space character
spaceloop:
	lda (index),y
	cmp #' '
	bne :+
	iny
	bra spaceloop
:
	; now copy everything back from this offset
shrinkloop2:
	lda (index),y
	sta (index)

	inc index
	bne :+
	inc index+1
:	lda index+1
	cmp vartab+1
	bcc shrinkloop2
	lda index
	cmp vartab
	bcc shrinkloop2

	ldy #0
	jmp istoken2
.endproc

.proc renumber_walk: near
	; set up ptr at the beginning of the BASIC program
	lda txttab
	sta index2
	lda txttab+1
	sta index2+1

	lda rennew
	sta rencur
	lda rennew+1
	sta rencur+1

	stz ram_bank

	; find the first line number greater than or equal to renold
startloop:
	ldy #1
	lda (index2),y ; check for end of program
	beq done
	ldy #3
	lda (index2),y
	cmp renold+1
	bcc startnext
	bne renloop
	dey
	lda (index2),y
	cmp renold
	bcc startnext
	bra renloop

startnext:
	lda (index2)
	pha
	ldy #1
	lda (index2),y
	sta index2+1
	pla
	sta index2
	bra startloop

fail:
	sec
	rts
done:
	clc
	rts

renloop:
	; replace line number
	ldy #2
	lda (index2),y
	sta renold
	lda rencur
	sta (index2),y
	iny
	lda (index2),y
	sta renold+1
	lda rencur+1
	sta (index2),y

	; search for GOTO/GOSUB/THEN/RESTORE/RUN line number instances
	jsr renumber_replace

	lda rencur
	clc
	adc reninc
	sta rencur
	lda rencur+1
	adc reninc+1
	sta rencur+1

;   turns out it's probably better to let the renumber
;   wrap and the user can probably redo the renumber with a
;   smaller increment.  The line numbers will be out of order
;   but rerunning REN will likely fix everything unless there
;   are duplicated lines and duplicated targets

;	cmp #$FF ; make sure the next line number doesn't overflow
;	beq fail

	; next line
	lda (index2)
	pha
	ldy #1
	lda (index2),y
	sta index2+1
	pla
	sta index2

	ldy #1
	lda (index2),y ; check for end of program
	beq done
	bra renloop    
.endproc

.proc renumber_replace: near
	stz rentmp
	stz rentmp+1

	lda txttab
	sta index
	lda txttab+1
	sta index+1
chkend:
	; check to see if we're at the end of the program
	lda (index)
	ldy #1
	ora (index),y
	beq isend
	ldy #3
tagloop:
	iny
tagloop2:
	lda (index),y
	bmi tokenchk
	beq endline
	cmp #'"' ; open quote
	beq openquote
	bra tagloop
openquote:
	iny
	lda (index),y
	beq endline
	cmp #'"' ; close quote
	bne openquote
	bra tagloop
skiptk:
	iny
	bra tagloop
tokenchk:
	cmp #esctk
	beq skiptk
	cmp #gototk
	beq istoken
	cmp #gosutk
	beq istoken
	cmp #thentk
	beq istoken
	cmp #resttk
	beq istoken
	cmp #runtk
	beq istoken
	bra tagloop
endline:
	iny
	tya
	clc
	adc index
	sta index
	lda index+1
	adc #0
	sta index+1
	bra chkend
isend:
	clc
	rts
istoken:
	iny
istoken2:
	lda (index),y
	beq endline
	cmp #' '
	beq istoken ; skip spaces
	cmp #','
	beq istoken ; comma separates ON GOTO type statements
	cmp #'#'
	beq target
	cmp #'0'
	bcc tagloop2
	cmp #'9'+1
	bcs tagloop2
	bra istoken ; skip over numbers, could be within an ON x GOTO ##1,2,##3 area
target:
repl_loop:
	iny
	lda (index),y
	cmp #'#'
	beq repl_loop
	cmp #'0'
	bcc gotnum
	cmp #'9'+1
	bcs gotnum

	sbc #('0'-1) ; carry is clear so subtracting takes and extra one away
numbers:
	pha
	; multiply rentmp by 10 using rentmp2 as temp storage
	lda rentmp
	asl
	rol rentmp+1
	sta rentmp2
	ldx rentmp+1
	stx rentmp2+1
	asl
	rol rentmp+1
	asl
	rol rentmp+1
	clc
	adc rentmp2
	sta rentmp
	lda rentmp+1
	adc rentmp2+1
	sta rentmp+1
	; add the number we just brought in
	pla
	clc
	adc rentmp
	sta rentmp
	lda rentmp+1
	adc #0
	sta rentmp+1
	bra repl_loop

bail:
	stz rentmp
	stz rentmp+1
	bra istoken2

gotnum:
	lda rentmp+1
	cmp renold+1
	bne bail
	lda rentmp
	cmp renold
	bne bail

	; now we have to replace the string with the new line number
	; back up until we find a non-number, non-#
backup:
	dey
	lda (index),y
	cmp #'#'
	beq backup
	cmp #'0'
	bcc backed
	cmp #'9'+1
	bcs backed
	bra backup

backed:
	iny
	; replace line number string here
	jsr line2string

blankloop:
	lda (index),y
	cmp #'#'
	beq blankit
	cmp #'0'
	bcc bail
	cmp #'9'+1
	bcs bail
blankit:
	lda #' '
	sta (index),y
	iny
	bra blankloop    

.endproc

.proc line2string: near
	stz rentmp2 ; digit to output
	stz rentmp2+1 ; have stored a digit (to avoid leading 0s)
	lda rencur
	sta rentmp
	lda rencur+1
	sta rentmp+1
l10k:
	cmp #>10000
	bcc d1k
	bne :+
	lda rentmp
	cmp #<10000
	bcc d1k
:	inc rentmp2
	lda rentmp
	sec
	sbc #<10000
	sta rentmp
	lda rentmp+1
	sbc #>10000
	sta rentmp+1
	bra l10k
d1k:
	lda rentmp2
	beq s1k
	clc
	adc #'0'
	sta (index),y
	stz rentmp2
	inc rentmp2+1
	iny
s1k:
	lda rentmp+1
l1k:
	cmp #>1000
	bcc d100
	bne :+
	lda rentmp
	cmp #<1000
	bcc d100
:	inc rentmp2
	lda rentmp
	sec
	sbc #<1000
	sta rentmp
	lda rentmp+1
	sbc #>1000
	sta rentmp+1
	bra l1k

d100:
	lda rentmp2
	bne :+
	lda rentmp2+1
	beq s100
:	lda rentmp2
	clc
	adc #'0'
	sta (index),y
	stz rentmp2
	inc rentmp2+1
	iny
s100:
	lda rentmp+1
l100:
	bne :+
	lda rentmp
	cmp #<100
	bcc d10
:	inc rentmp2
	lda rentmp
	sec
	sbc #<100
	sta rentmp
	lda rentmp+1
	sbc #>100
	sta rentmp+1
	bra l100

d10:
	lda rentmp2
	bne :+
	lda rentmp2+1
	beq s10
:	lda rentmp2
	clc
	adc #'0'
	sta (index),y
	stz rentmp2
	inc rentmp2+1
	iny
s10:
	lda rentmp
l10:
	cmp #10
	bcc d1
	sbc #10
	sta rentmp
	inc rentmp2
	bra l10

d1:
	lda rentmp2
	bne :+
	lda rentmp2+1
	beq s1
:	lda rentmp2
	clc
	adc #'0'
	sta (index),y
	iny

s1:
	lda rentmp
	clc
	adc #'0'
	sta (index),y
	iny

	rts
.endproc

.proc renumber_tag: near
	; temporarily tag all of the GOTO/GOSUB/THEN/RESTORE line number args with #
	; set up pointer to beginning of BASIC program
	lda txttab
	sta index2
	lda txttab+1
	sta index2+1
chkend:
	; check to see if we're at the end of the program
	lda (index2)
	ldy #1
	ora (index2),y
	beq isend
	ldy #3
tagloop:
	iny
tagloop2:
	lda (index2),y
	bmi tokenchk
	beq endline
	cmp #'"' ; open quote
	beq openquote
	bra tagloop
openquote:
	iny
	lda (index2),y
	beq endline
	cmp #'"' ; close quote
	bne openquote
	bra tagloop
skiptk:
	iny
	bra tagloop
tokenchk:
	cmp #esctk
	beq skiptk
	cmp #gototk
	beq istoken
	cmp #gosutk
	beq istoken
	cmp #thentk
	beq istoken
	cmp #resttk
	beq istoken
	cmp #runtk
	beq istoken
	bra tagloop
endline:
	iny
	tya
	clc
	adc index2
	sta index2
	lda index2+1
	adc #0
	sta index2+1
	bra chkend
isend:
	clc
	rts
istoken:
	iny
istoken2:
	lda (index2),y
	beq endline
	cmp #' '
	beq istoken ; skip spaces
	cmp #','
	beq istoken ; comma separates ON GOTO type statements
	cmp #':'
	beq tagloop ; colon separates statements
	cmp #'0'
	bcc tagloop2 ; a character other than a number (< 0)
	cmp #'9'+1
	bcs tagloop2 ; a character other than a number (> 9)
target:
	; save the current location
	tya
	clc
	adc index2
	sta index2
	lda index2+1
	adc #0
	sta index2+1
	; shift everything from this point higher by 4 bytes
	lda vartab
	sta index
	lda vartab+1
	sta index+1
	ldy #4
extendloop:
	lda index
	bne :+
	dec index+1
:	dec index

	lda (index)
	sta (index),y

	lda index2+1
	cmp index+1
	bcc extendloop
	lda index2
	cmp index
	bcc extendloop

	lda #'#'

	dey
:	sta (index2),y
	dey
	bpl :-

	; relink the program after the move so that vartab gets
	; updated
	jsr lnkprg
	lda index
	adc #2
	sta vartab
	lda index+1
	adc #0
	sta vartab+1

	ldy #4
endtarget:
	iny
	lda (index2),y
	cmp #'#'
	beq endtarget
	cmp #'0'
	bcc istoken2
	cmp #'9'+1
	bcs istoken2
	bra endtarget
.endproc


.proc lnkprg: near
	lda txttab
	ldy txttab+1
	sta index
	sty index+1
	clc 
chead:
	ldy #1
	lda (index),y
	beq lnkrts
	ldy #4
czloop:
	iny
	lda (index),y
	bne czloop
	iny
	tya
	adc index
	tax
	ldy #0
	sta (index),y
	lda index+1
	adc #0
	iny
	sta (index),y
	stx index
	sta index+1
	bcc chead
lnkrts:
	rts
.endproc
