.include "kernal.inc"
.include "banks.inc"

readst = $ffb7

.feature labels_without_colons

.importzp index1, txtptr, eormsk, poker

.import basic_fa, curlin, verck, valtyp

.import mode
.import linprt
.import crdo
.import error
.import fcerr
.import frefac
.import frmevl
.import getadr
.import nsnerr6
.import erexit
.import cld10

.export dos
dos_getfa = getfa
.export dos_getfa
dos_ptstat3 = ptstat3
.export dos_ptstat3
dos_clear_disk_status = clear_disk_status
.export dos_clear_disk_status
dos_chkdosw = chkdosw
.export dos_chkdosw

.segment "ANNEX"


; check if current buffer contains a dos wedge command
chkdosw:
	lda (txtptr)
	cmp #'@'
	beq dosat
	cmp #'>'
	beq dosat
	cmp #'/'
	beq dossla
	cmp #'^'
	beq doscar
	cmp #'_'
	beq doslef
	cmp #'%'
	beq dospct
	clc
	rts

dosat:
	ldy #1
	lda (txtptr),y
	beq dossta
	jsr dosparm
	bcs dosret
	jsr dos2
dosret:
	sec
	rts
dossta: ; DOS
	jsr ptstat
	bra dosret
doscar: ; LOAD "FILE",8 : RUN
	ldx #0
@kbd_stuff:
	lda @runc,x
	beq @load
	jsr kbdbuf_put
	inx
	bne @kbd_stuff
@load:
	jmp doswld
@runc:
	.byte "RUN",13,0
@runl = *-@runc

dossla: ; LOAD "FILE",8
	jmp doswld
dospct: ; LOAD "FILE",8,1
	jsr getfa
	tax
	lda #1
	ldy #1
	jsr setlfs
	ldy #1
	jsr dosparm
	ldx index1
	ldy index1+1
	jsr setnam
	lda #0
	jsr load
	bcc dosret
	jmp erexit
doslef:
	jsr getfa
	sta verck ; used by save routine
	tax
	lda #1
	ldy #1
	jsr setlfs
	ldy #1
	jsr dosparm
	ldx index1
	ldy index1+1
	jsr setnam
	jsr nsnerr6 ; BASIC SAVE
	bra dosret
doswld:
	stz eormsk
	jsr getfa
	tax
	lda #1
	ldy #0
	jsr setlfs
	ldy #1
	jsr dosparm
	ldx index1
	ldy index1+1
	jsr setnam
	ldx #<$801
	stx poker
	ldy #>$801
	sty poker+1
	lda #0
	jmp cld10
inydosparm:
	iny

dosparm:
	lda (txtptr),y
	cmp #' '
	beq inydosparm
	cmp #$22
	beq inydosparm
	cmp #'#'
	beq dosnum
	tya
	clc
	adc txtptr
	sta index1
	lda txtptr+1
	adc #0
	sta index1+1
	ldy #0
:	lda (index1),y
	beq :+
	cmp #$22
	beq :+
	iny
	bne :-
:	tya
	clc
	rts
dosnum:
	iny
	lda (txtptr),y
	sec
	sbc #'0'
@2:
	cmp #8
	bcc @dd
	cmp #32
	bcs @fcerr
	jsr dossw
	jmp dosret
@fcerr:
	jmp fcerr	
@dd:
	cmp #4 ; can't be above 32 anyway
	bcs @fcerr
	asl
	sta verck
	asl
	asl
	adc verck
	sta verck
	iny
	lda (txtptr),y
	beq @fcerr
	sec
	sbc #'0'
	clc
	adc verck
	bra @2


; ----------------------------------------------------------------
; XXX This is very similar to the code in MONITOR. When making
; XXX changes, have a look at both versions!
; ----------------------------------------------------------------
dos beq ptstat      ;no argument: print status
	jsr frmevl
	bit valtyp
	bmi @str
; numeric
	jsr getadr
	cmp #0          ;lo
	beq :+
@fcerr	jmp fcerr
:	cpy #8           ;hi
	bcc @fcerr
	cpy #32
	bcs @fcerr
	tya
	jmp dossw

@str	jsr frefac      ;get ptr to string, length in .a
	cmp #0
	beq ptstat      ;no argument: print status
dos2:
	sta verck       ;save length
	ldx index1
	ldy index1+1
	jsr setnam
	ldy #0
	lda (index1),y
; dir?
	cmp #'$'
	beq disk_dir
; switch default drive?
	cmp #'8'
	beq dossw
	cmp #'9'
	beq dossw

;***************
; DOS command
	sec
	jsr listen_cmd
	ldy #0
:	lda (index1),y
	jsr iecout
	iny
	cpy verck       ;length?
	bne :-
	jsr unlstn
	lda curlin+1
	inc
	beq ptstat
	rts

; in:  C=1 show "DEVICE NOT PRESENT" on error
;      C=0 return error in C
; out: C=0 no error
;      C=1 error
listen_cmd:
	php
	jsr getfa
	jsr listen
	lda #$6f
	jsr second
	jsr readst
	bmi @error
	plp
	clc
	rts
@error:	plp
	bcs device_not_present
	sec
	rts
device_not_present:
	ldx #5 ; "DEVICE NOT PRESENT"
	jmp error


clear_disk_status:
	clc
	bra ptstat2
;***************
; print status
ptstat	sec
ptstat2	php
	; keep C:
	; for printing status, print error
	; for clearing status, return error
	jsr listen_cmd
	bcc :+
	plp
	rts
:	jsr unlstn
	jsr getfa
ptstat4
	jsr talk
	lda #$6f
	jsr tksa
dos11	jsr iecin
	beq dos0
	plp
	php
	bcc :+
	jsr bsout
:	cmp #13
	bne dos11
dos0	plp
	jmp untalk

;***************
; switch default drive
dossw	sta basic_fa
	rts

getfa:
	lda #8
	cmp basic_fa
	bcs :+
	lda basic_fa
:	rts


;***************
;  read & display the disk directory

LOGADD = 15

disk_dir
	jsr getfa
	tax
	lda #LOGADD     ;la
	ldy #$60        ;sa
	jsr setlfs
	jsr open        ;open directory channel
	jsr readst
	bpl :+
	lda #LOGADD
	jsr close
	jmp device_not_present
:	ldx #LOGADD
	jsr chkin       ;make it an input channel

	jsr crdo

	ldy #4          ;first pass only- trash first four bytes read

@d20
@d25	jsr basin
	jsr readst
	bne disk_done   ;...branch if error
	dey
	bne @d25        ;...loop until done

	jsr basin       ;get # blocks low
	pha
	jsr readst
	tay
	pla
	cpy #0
	bne disk_done   ;...branch if error
	tax
	jsr basin       ;get # blocks high
	pha
	jsr readst
	tay
	pla
	cpy #0
	bne disk_done   ;...branch if error
	jsr linprt      ;print # blocks

	lda #' '
	jsr bsout       ;print space  (to match loaded directory display)

	ldy #0
@d30	jsr basin       ;read & print filename & filetype
	beq @d40        ;...branch if eol
	pha
	jsr readst
	tax
	pla
	cpx #0
	bne disk_done   ;...branch if error
	bit mode
	bvs @d30out     ; ISO mode
	cmp #$22
	beq @d30qtsw    ; quotation mark
	cpy #0
	beq @d30out     ; not inside of quotes
	cmp #$60
	bcc @d30out     ; is unshifted character
	cmp #$80
	bcc @d30sub20   ; shifted character, subtract $20
	cmp #$e0
	bcs @d30ques    ; unprintable, show ?
	bra @d30out     ; the rest are valid PETSCII
@d30sub20
	sec
	sbc #$20
@d30out
	jsr bsout
	bra @d30

@d40	jsr crdo        ;start a new line
	jsr stop
	beq disk_done   ;...branch if user hit STOP
	ldy #2
	bra @d20
@d30qtsw ; toggle y between 0 and 1 to indicate whether we're inside quotes
	cpy #0
	beq :+
	dey
	dey
:	iny
	bra @d30out
@d30ques
	lda #'?'
	bra @d30out

disk_done
	jsr clrch
	lda #LOGADD
	sec
	jmp close


ptstat3
	sec
	php
	jmp ptstat4
