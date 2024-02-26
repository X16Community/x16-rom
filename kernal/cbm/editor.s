;----------------------------------------------------------------------
; Editor
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

.feature labels_without_colons

;screen editor constants
;
maxchr=80
nwrap=4 ;max number of physical lines per logical line

.export plot   ; set cursor position
.export scrorg ; return screen size
.export cint   ; initialize screen
.export prt    ; print character
.export loop5  ; input a line until carriage return

.importzp mhz  ; constant

.importzp tmp2

.import dfltn, dflto ; XXX

.import iokeys
.import panic

.import shflag
SCREEN_MODE_4030 = 3
MODIFIER_4080 = 32
MODIFIER_SHIFT = 1

.include "io.inc"

; kernal
.export crsw
.export indx
.export lnmx
.export lstp
.export lsxp
.export cursor_blink
.export check_charset_switch

.export tblx
.export pntr

.export defcb

; screen driver
.import screen_mode
.import screen_set_charset
.import screen_get_color
.import screen_set_color
.import screen_get_char
.import screen_set_char
.import screen_set_char_color
.import screen_get_char_color
.import screen_set_position
.import screen_get_position
.import screen_copy_line
.import screen_clear_line
.import screen_save_state
.import screen_restore_state
.import screen_toggle_default_nvram
.import screen_set_defaults_from_nvram
.export llen
.export scnsiz
.export color

; keyboard driver
.import kbd_config, kbd_scan, kbdbuf_clear, kbdbuf_put, kbdbuf_get, kbd_remove, kbdbuf_get_modifiers, kbdbuf_get_stop

; beep driver
.import beep

.import emulator_get_data

.import fetch_keymap_from_nvram

.import callkbvec

.import c816_irqb

.include "65c816.inc"
.include "banks.inc"
.include "mac.inc"

.segment "KVAR2" ; more KERNAL vars
ldtb1	.res 8       ;end of line flags, one bit per line
; Screen
;
.export mode; [ps2kbd]
.export data; [cpychr]
mode	.res 1           ;    bit7=1: charset locked, bit6=1: ISO
                         ;    bits3-0: current charset
.assert * = $0373, error, "cc65 depends on CURS_COLOR = $0373, change with caution"
gdcol	.res 1           ;    original color before cursor
autodn	.res 1           ;    auto scroll down flag(=0 on,<>0 off)
lintmp	.res 1           ;    temporary for line index
.assert * = $0376, error, "cc65 depends on CHARCOLOR = $0376, change with caution"
color	.res 1           ;    activ color nybble
.assert * = $0377, error, "cc65 depends on RVS = $0377, change with caution"
rvs	.res 1           ;$C7 rvs field on flag
indx	.res 1           ;$C8
lsxp	.res 1           ;$C9 x pos at start
lstp	.res 1           ;$CA
.assert * = $037B, error, "cc65 depends on CURS_FLAG = $037B, change with caution"
blnsw	.res 1           ;$CC cursor blink enab
.assert * = $037C, error, "cc65 depends on CURS_BLINK = $037C, change with caution"
blnct	.res 1           ;$CD count to toggle cur
.assert * = $037D, error, "cc65 depends on CURS_CHAR = $037D, change with caution"
gdbln	.res 1           ;$CE char before cursor
.assert * = $037E, error, "cc65 depends on CURS_STATE = $037E, change with caution"
blnon	.res 1           ;$CF on/off blink flag
crsw	.res 1           ;$D0 input vs get flag
.assert * = $0380, error, "cc65 depends on CURS_X = $0380, change with caution"
pntr	.res 1           ;$D3 pointer to column
qtsw	.res 1           ;$D4 quote switch
lnmx	.res 1           ;$D5 40/80 max positon
.assert * = $0383, error, "cc65 depends on CURS_Y = $0383, change with caution"
tblx	.res 1           ;$D6
data	.res 1           ;$D7
insrt	.res 1           ;$D8 insert mode flag
.assert * = $0386, error, "cc65 depends on LLEN = $0386, change with caution"
llen	.res 1           ;$D9 x resolution
.assert * = $0387, error, "cc65 depends on NLINES = $0387, change with caution"
nlines	.res 1           ;$DA y resolution
nlinesp1	.res 1          ;    X16: y resolution + 1
nlinesm1	.res 1          ;    X16: y resolution - 1
verbatim	.res 1

.segment "C816_SCRORG"
;
;return max rows,cols of screen
;
scrorg	php
	set_carry_if_65c816
	bcc @not_65c816

.pushcpu
.setcpu "65816"
	sep #$20
	.A8
	pha
	lda $02,S
	and #4
	beq @not_interrupt
	pla
	plp
	jmp c816_irqb

@not_interrupt
	pla

.popcpu

@not_65c816
	plp
	ldx llen
	ldy nlines
	rts

.segment "EDITOR"
;
;read/plot cursor position
;
plot	bcs plot10
	php
	sei
	phx
	phy
	lda blnon
	beq :+
	lda gdbln
	ldx gdcol       ;restore original color
	ldy #0
	sty blnon
	jsr dspp
:	ply
	plx
	stx tblx
	sty pntr
	jsr stupt
	plp
plot10	ldx tblx
	ldy pntr
	rts

;
;set screen size
;
scnsiz	stx llen
	sty nlines
	iny
	sty nlinesp1
	dey
	dey
	sty nlinesm1
	jmp clsr ; clear screen

;initialize i/o
;
cint	jsr iokeys

;
; establish screen memory
;
	jsr panic       ;set up vic

	jsr screen_set_defaults_from_nvram
	lda #2          ;uppercase PETSCII, not locked
	sta mode
	stz blnon       ;we dont have a good char from the screen yet

	jsr fetch_keymap_from_nvram
	bne @l1
	jsr emulator_get_data
	bra @l2
@l1
	dec
@l2
	jsr kbd_config  ;set keyboard layout

	lda #$c
	sta blnct
	sta blnsw

; clear screen, populate ldtb1 with non-continuing lines
clsr	lda #$ff
	ldx #7
lps1	sta ldtb1,x
	dex
	bpl lps1
	ldx nlinesm1    ;clear from the bottom line up
clear1	jsr screen_clear_line ;see scroll routines
	dex
	bpl clear1

;home function
;
nxtd	ldy #0
	sty pntr        ;left column
	sty tblx        ;top line
;
;move cursor to tblx,pntr
;
stupt
	ldx tblx        ;get curent line index
	lda pntr        ;get character pointer
fndstr	pha
	ldy ldtbl_byte,x
	lda ldtb1,y
	and ldtbl_bit,x
	tay
	pla
	cpy #0          ;find begining of line
	bne stok        ;branch if start found
	clc
	adc llen        ;adjust pointer
	sta pntr
	dex
	bpl fndstr
;
stok	jsr screen_set_position
;
	lda llen
	dec
	inx
fndend	pha
	ldy ldtbl_byte,x
	lda ldtb1,y
	and ldtbl_bit,x
	tay
	pla
	cpy #0
	bne stdone
	clc
	adc llen
	inx
	bpl fndend
stdone
	sta lnmx
	rts

;
loop4	jsr prt
loop3
	lda ram_bank    ;Check if 40/80 column modifier key bit is set
	pha
	stz ram_bank
	lda shflag
	and #MODIFIER_4080
	beq loop3b

	lda shflag      ;Clear 40/80 key bit
	and #(255-MODIFIER_4080)
	sta shflag
	
	and #MODIFIER_SHIFT
	bne scrpnc
	jsr screen_toggle_default_nvram
	jsr fetch_keymap_from_nvram ; since we toggled profiles, perhaps this one has a different keymap
	beq :+
	dec
	jsr kbd_config
:
	bra loop3b
scrpnc
	; screen panic, cycle through VGA/composite/RGB modes
	stz VERA_CTRL
	lda VERA_DC_VIDEO
	inc
	and #3
	bne :+
	inc
:
	sta tmp2
	lda VERA_DC_VIDEO
	and #$7c
	ora tmp2
	sta VERA_DC_VIDEO
	; beep code to indicate which mode we switched to
	ldx tmp2
	ldy beephi-1,x
	lda beeplo-1,x
	tax
	lda #1
	jsr beep
	bra loop3b

loop3b:	pla
	sta ram_bank
	jsr kbdbuf_get
	beq nochr
	pha
	KVARS_START_TRASH_X_NZ
	sec
	jsr callkbvec
	KVARS_END_TRASH_X_NZ
	bcs nokbo ; no override wanted, continue as normal
	jsr clear_cursor
	pla
	KVARS_START_TRASH_X_NZ
	clc
	jsr callkbvec ; allow override
	KVARS_END_TRASH_X_NZ
	pha
	lda #1
	sta blnct
	php
	sei
	jsr cursor_blink
	plp
nokbo
	pla
nochr
	sta blnsw
	sta autodn      ;turn on auto scroll down
    ; power saving: a character from the keyboard
	; cannot arrive before the next timer IRQ
	bne ploop3
	.byte $cb       ; WAI instruction
	jmp loop3
ploop3
	pha
	php
	sei
	lda blnon
	beq lp21
	lda gdbln
	ldx gdcol       ;restore original color
	ldy #0
	sty blnon
	jsr dspp
lp21	plp             ;restore I
	pla
	cmp #$83        ;run key?
	bne lp22
; put SHIFT+STOP text into keyboard buffer
	jsr kbdbuf_clear
	ldx #0
:	lda runtb,x
	jsr kbdbuf_put
	inx
	cpx #runtb_end-runtb
	bne :-
	jmp loop3

lp22	pha
	sec
	sbc #$85         ;f1 key?
	bcc lp29
	cmp #8
	bcs lp29         ;beyond f8
	cmp #4
	rol              ;convert to f1-f8 -> 0-7
	and #7
	ldx #0
	tay
	beq lp27
lp25	lda fkeytb,x     ;search for replacement
	beq lp26
	inx
	bne lp25
lp26	inx
	dey
	bne lp25
lp27	jsr kbdbuf_clear
lp24	lda fkeytb,x
	jsr kbdbuf_put
	tay              ;set flags
	beq lp28
	inx
	bne lp24
lp28	pla
loop3a	jmp loop3
;
lp29	pla
	cmp #$d
	beq :+
	jmp loop4
:	ldy lnmx
	sty crsw
clp5
	jsr screen_get_char
	cmp #' '
	bne clp6
	dey
	bne clp5
clp6	iny
	sty indx
	ldy #0
	sty autodn      ;turn off auto scroll down
	sty pntr
	sty qtsw
	lda lsxp
	bmi lop5
	ldx tblx
	cpx lsxp        ;check if on same line
	beq finpux      ;yes..return to send
	jsr findst      ;check if we wrapped down...
finpux	cpx lsxp
	bne lop5
	lda lstp
	sta pntr
	cmp indx
	bcc lop5
	bcs clp2

;input a line until carriage return
;
loop5	tya
	pha
	txa
	pha
	lda crsw
	beq loop3a
lop5	ldy pntr
	jsr screen_get_char
notone
	sta data
	bit mode
	bvs lop53       ;ISO
lop51	and #$3f
	asl data
	bit data
	bpl lop54
	ora #$80
lop54	bcc lop52
	ldx qtsw
	bne lop53
lop52	bvs lop53
	ora #$40
lop53

; verbatim mode:
; if the character is reverse or >= $60, return 0
	bit verbatim
	stz verbatim
	bpl @0
	cmp #$60
	bcs @2a
@1:	pha
	jsr screen_get_char ; again
	bmi @2
	pla
	bra @0
@2:	pla
@2a:	lda #0
@0:

	inc pntr
	jsr qtswc
	cpy indx
	bne clp1
clp2	lda #0
	sta crsw
	; we're almost done here so we need to
	; reset the keystroke callback vectors to defaults
	lda ram_bank
	pha
	stz ram_bank
	stz edkeybk ; bank
	lda #<defcb
	sta edkeyvec ; low
	lda #>defcb
	sta edkeyvec+1 ; high
	pla
	sta ram_bank

	lda #$d
	ldx dfltn       ;fix gets from screen
	cpx #3          ;is it the screen?
	beq clp2a
	ldx dflto
	cpx #3
	beq clp21
clp2a	jsr prt
clp21	lda #$d
clp1	sta data
	pla
	tax
	pla
	tay
	lda data
	bit mode
	bvs clp7        ;ISO
	cmp #$de        ;is it <pi> ?
	bne clp7
	lda #$ff
clp7	clc
	rts

qtswc	cmp #$22
	bne qtswl
	lda qtsw
	eor #$1
	sta qtsw
	lda #$22
qtswl	rts

nxt33
	bit mode
	bvs nc3         ;ISO
	ora #$40
nxt3	ldx rvs
	beq nvs
nc3	ora #$80
nvs	ldx insrt
	beq nvs1
	dec insrt
nvs1	ldx color       ;put color on screen
	jsr dspp
	jsr wlogic      ;check for wraparound
loop2	pla
	tay
	lda insrt
	beq lop2
	lsr qtsw
lop2	pla
	tax
	pla
	clc             ;good return
	cli
	rts

wlogic
	jsr chkdwn      ;maybe we should we increment tblx
	inc pntr        ;bump charcter pointer
	lda lnmx        ;
	cmp pntr        ;if lnmx is less than pntr
	bcs wlgrts      ;branch if lnmx>=pntr
	cmp #maxchr-1   ;past max characters
	bcs wlog10      ;branch if so
	lda autodn      ;should we auto scroll down?
	beq wlog20      ;branch if not
	jmp bmt1        ;else decide which way to scroll

wlog20
	ldx tblx        ;see if we should scroll down
	cpx nlines
	bcc wlog30      ;branch if not
	jsr scrol       ;else do the scrol up
	dec tblx        ;and adjust curent line#
	ldx tblx
wlog30	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	eor #$ff
	and ldtb1,y
	sta ldtb1,y     ;wrap the line
	inx             ;index to next line
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	ora ldtb1,y     ;make it a non-continuation line
	sta ldtb1,y
	dex             ;get back to current line
	lda lnmx        ;continue the bytes taken out
	clc
	adc llen
	sta lnmx
findst
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	and ldtb1,y     ;is this the first line?
	bne finx        ;branch if so
	dex             ;else backup 1
	bne findst
finx
	jmp screen_set_position ;make sure pnt is right

wlog10	dec tblx
	jsr nxln
	lda #0
	sta pntr        ;point to first byte
wlgrts	rts

bkln	ldx tblx
	bne bkln1
	stx pntr
	pla
	pla
	jmp loop2
;
bkln1	dex
	stx tblx
	jsr stupt
	ldy lnmx
	sty pntr
	rts

;print routine
;
prt
; verbatim mode
	bit verbatim
	bpl @prt0

	bit mode
	bvc :+          ;skip if PETSCII
; ISO: "no exceptions" quote mode
	pha
	lda #2
	sta qtsw
	pla
	inc insrt
	bra @l2
; PETSCII: handle ranges manually
:	cmp #$20
	bcs :+
	inc rvs
	ora #$40        ;$00-$1F: reverse, add $40
:	cmp #$80
	bcc @l2         ;$20-$7F: printable character
	cmp #$A0
	bcs @l2         ;$A0-$FF: printable character
	inc rvs
	and #$7F
	ora #$60        ;$80-$9F: reverse, clear MSB, add $60
@l2:	jsr @prt1
	stz verbatim
	stz rvs
	stz qtsw
	and #$ff        ;set flags
	rts

@prt0:	cmp #$80
	bne @prt1
	ror verbatim    ;C=1, enable
	and #$ff        ;set flags
	rts

@prt1:	pha
	sta data
	txa
	pha
	tya
	pha
	lda #0
	sta crsw
	ldy pntr
	lda data
	bpl :+
	jmp nxtx
:	ldx qtsw
	cpx #2          ;"no exceptions" quote mode?
	beq njt1
	cmp #$d
	bne njt1
	jmp nxt1
njt1	cmp #' '
	bcc ntcn
	bit mode
	bvs njt9        ;ISO
	cmp #$60        ;lower case?
	bcc njt8        ;no...
	and #$df        ;yes...make screen lower
	bne njt9        ;always
njt8	and #$3f
njt9	jsr qtswc
	jmp nxt3
ntcn	ldx insrt
	beq cnc3x
	bit mode
	bvc cnc3y       ;not ISO
	jmp nvs
cnc3y	jmp nc3
cnc3x	cmp #$14
	bne ntcn1
cnc3w	tya
	bne bak1up
	jsr bkln
	jmp bk2
bak1up	jsr chkbak      ;should we dec tblx
	dey
	sty pntr
; move line left
bk15	iny
	jsr screen_get_char
	dey
	jsr screen_set_char
	iny
	jsr screen_get_color
	dey
	jsr screen_set_color
	iny
	cpy lnmx
	bne bk15
; insert space
bk2	lda #' '
	jsr screen_set_char
	lda color
	jsr screen_set_color
	bmi ntcn1
	jmp jpl3
ntcn1	ldx qtsw
	beq nc3w
	bit mode
	bvc cnc3        ;not ISO
	jmp nvs
cnc3	jmp nc3
nc3w	cmp #$12
	bne nc1
	bit mode
	bvs nc1         ;ISO
	sta rvs
nc1	cmp #$13
	bne nc15
	jsr nxtd
	jmp loop2
nc15	cmp #$19        ;DEL (not backspace)
	bne nc2
	iny
	jsr chkdwn
	sty pntr
	dey
	cpy lnmx
	bcc nc16
	dec tblx
	jsr nxln
	stz pntr
nc16	ldy pntr
	jmp cnc3w
nc2	cmp #$04        ;END (go to end of line)
	bne nc25
	ldy lnmx
nc21	jsr screen_get_char
	cmp #' '
	bne nc23
	dey
	bne nc21
	dey
nc23	iny
	sty pntr        ;column
	jsr screen_get_position
	stx tblx        ;row
	jsr stupt       ;move cursor to tblx,pntr
	jmp loop2
nc25	cmp #$1d        ;CSR RIGHT
	bne ncx2
	iny
	jsr chkdwn
	sty pntr
	dey
	cpy lnmx
	bcc ncz2
	dec tblx
	jsr nxln
	ldy #0
jpl4	sty pntr
ncz2	jmp loop2
ncx2	cmp #$11
	bne colr1
	clc
	tya
	adc llen
	tay
	inc tblx
	cmp lnmx
	bcc jpl4
	beq jpl4
	dec tblx
curs10	sbc llen
	bcc gotdwn
	sta pntr
	bne curs10
gotdwn	jsr nxln
jpl3	jmp loop2
colr1	jsr chkcol      ;check for a color

	cmp #$0e        ;does he want lower case?
	bne upper       ;branch if not
	bit mode
	bvs outhre      ;ISO
	lda mode
	and #$ce
	ora #1          ;upper/lower
	jmp setchr

upper
	cmp #$8e        ;does he want upper case
	bne lock        ;branch if not
	bit mode
	bvs outhre      ;ISO
	lda mode
	and #$ce        ;upper/graph
setchr	sta mode
	and #$0f
	jsr screen_set_charset
outhre	jmp loop2

lock
	cmp #8          ;does he want to lock in this mode?
	bne unlock      ;branch if not
	lda #$80        ;else set lock switch on
	ora mode        ;don't hurt anything - just in case
	bmi lexit

unlock
	cmp #9          ;does he want to unlock the keyboard?
	bne isoon       ;branch if not
	lda #$7f        ;clear the lock switch
	and mode        ;dont hurt anything
lexit	sta mode
	jmp loop2       ;get out

isoon
	cmp #$0f        ;switch to ISO mode?
	bne isooff      ;branch if not
	lda mode
	and #4
	bne isosk
	lda #1
	bra isocon
isosk
	lda #6
isocon
	jsr screen_set_charset
	lda mode
	ora #$40
	bra isosto

isooff
	cmp #$8f        ;switch to PETSCII mode?
	bne bell        ;branch if not
	lda mode
	and #4
	bne petsk
	lda #2
petsk
	jsr screen_set_charset
	lda mode
	and #$ff-$40
isosto	sta mode
	jsr clsr        ;clear screen
	jmp loop2

bell
	cmp #$07        ;bell?
	bne outhre      ;branch if not
	ldx #<1181      ; freq
	ldy #>1181
	lda #4          ; duration
	jsr beep
	jmp loop2

;shifted keys
;
nxtx
keepit
	and #$7f
	bit mode
	bvs nxtx1       ;ISO
	cmp #$7f
	bne nxtx1
	lda #$5e
nxtx1
nxtxa
	cmp #$20        ;is it a function key
	bcc uhuh
	jmp nxt33
uhuh
	ldx qtsw
	cpx #2          ;"no exceptions" quote mode?
	beq up5
	cmp #$d
	bne up5
	jmp nxt1
up5	ldx qtsw
	bne up6
	cmp #$14
	bne up9
; check whether last char in line is a space
	ldy lnmx
	jsr screen_get_char
	cmp #' '
	bne ins3
	cpy pntr
	bne ins1
ins3	cpy #maxchr-1
	bcs insext      ;exit if line too long
	jsr newlin      ;scroll down 1
ins1	ldy lnmx
; move line right
ins2	dey
	jsr screen_get_char
	iny
	jsr screen_set_char
	dey
	jsr screen_get_color
	iny
	jsr screen_set_color
	dey
	cpy pntr
	bne ins2
; insert space
	lda #$20
	jsr screen_set_char
	lda color
	jsr screen_set_color
	inc insrt
insext	jmp loop2
up9	ldx insrt
	beq up2
up6
	bit mode
	bvs up1         ;ISO
	ora #$40
up1	jmp nc3
up2	cmp #$11
	bne nxt2
	ldx tblx
	bne up3
	ldx #0          ;scroll screen DOWN!
	jsr bmt2        ;insert line at top of screen
	lda ldtb1
	ora #$01        ;first line is not an extension
	sta ldtb1
	jsr stupt
	bra jpl2
up3	dec tblx
	lda pntr
	sec
	sbc llen
	bcc upalin
	sta pntr
	bpl jpl2
upalin	jsr stupt
	bne jpl2
nxt2	cmp #$12
	bne nxt6
	lda #0
	sta rvs
nxt6	cmp #$1d
	bne nxt61
	tya
	beq bakbak
	jsr chkbak
	dey
	sty pntr
	jmp loop2
bakbak	jsr bkln
	jmp loop2
nxt61	cmp #$13
	bne shend
	jsr clsr
jpl2	jmp loop2
shend	cmp #$04        ;Shift+End (go to bottom of screen)
	bne sccl
	stz pntr        ;column
	lda nlinesm1
	sta tblx        ;line
	jsr stupt       ;move cursor to tblx,pntr
	jmp loop2
sccl
	ora #$80        ;make it upper case
	jsr chkcol      ;try for color
	jmp upper       ;was jmp loop2
;
nxln	lsr lsxp
	ldx tblx
nxln2	inx
	cpx nlines      ;off bottom?
	bne nxln1       ;no...
	jsr scrol       ;yes...scroll
nxln1	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	and ldtb1,y     ;continued line?
	beq nxln2       ;yes...scroll again
	stx tblx
	jmp stupt
nxt1
	ldx #0
	stx insrt
	stx rvs
	stx qtsw
	stx pntr
	jsr nxln
jpl5	jmp loop2
;
;
; check for a decrement tblx
;
chkbak	ldx #nwrap
	lda #0
chklup	cmp pntr
	beq back
	clc
	adc llen
	bcs :+ ; abort check if column overflowed
	dex
	bne chklup
:
	rts
;
back	dec tblx
	rts
;
; check for increment tblx
;
chkdwn	ldx #nwrap
	lda llen
	dec
dwnchk	cmp pntr
	beq dnline
	clc
	adc llen
	bcs :+ ; abort check if column overflowed
	dex
	bne dwnchk
:
	rts
;
dnline	ldx tblx
	cpx nlines
	beq dwnbye
	inc tblx
;
dwnbye	rts

chkcol
	cmp #1          ;check ctrl-a for invert.
	bne ntinv
	lda color       ;get current text color.
	asl a           ;swap msn/lsn.  ; c 11010000 -> 1 10100000
	adc #$80        ; example ->    ; 1 10100000 -> 1 00100001
	rol a           ;               ; 1 00100001 -> 0 01000011
	asl a           ; clever        ; c 01000011 -> 0 10000110
	adc #$80        ;  approach!    ; 0 10000110 -> 1 00000110
	rol a                           ; 1 00000110 -> 0 00001101
	sta color       ;stash back.
	lda #1          ;restore .a
	rts
ntinv
	ldx #15         ;there's 15 colors
chk1a	cmp coltab,x
	beq chk1b
	dex
	bpl chk1a
	rts
;
chk1b
	pha
	lda color
	and #$f0        ;keep bg color
	stx color
	ora color
	sta color       ;change the color
	pla             ;restore .a
	rts

coltab
;blk,wht,red,cyan,magenta,grn,blue,yellow
	.byt $90,$05,$1c,$9f,$9c,$1e,$1f,$9e
	.byt $81,$95,$96,$97,$98,$99,$9a,$9b

;screen scroll routine
;
scrol
;
;   s c r o l l   u p
;
scro0	ldx #$ff
	dec tblx
	dec lsxp
	dec lintmp
scr10	inx             ;goto next line
	jsr screen_set_position ;point to 'to' line
	cpx nlinesm1    ;done?
	bcs scr41       ;branch if so
;
	phx
	inx
	jsr screen_copy_line ;scroll this line up1
	plx
	bra scr10
;
scr41
	jsr screen_clear_line
;
	sec              ;scroll hi byte pointers
	ldx #7
scrl5	ror ldtb1,x
	dex
	bpl scrl5

;
	lda ldtb1       ;continued line?
	and #1
	beq scro0       ;yes...scroll again
;
	inc tblx
	inc lintmp
	jsr kbdbuf_get_modifiers
	and #4
	beq mlp42
;
	lda #<mhz
	ldy #0
mlp4	nop             ;delay
	dex
	bne mlp4
	dey
	bne mlp4
	sec
	sbc #1
	bne mlp4
;
mlp42	ldx tblx
;
pulind	rts

newlin
	ldx tblx
bmt1	inx
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	and ldtb1,y     ;find last display line of this line
	beq bmt1
bmt2	stx lintmp      ;found it
;generate a new line
	cpx nlinesm1    ;is one line from bottom?
	beq newlx       ;yes...just clear last
	bcc newlx       ;<nlines...insert line
	jsr scrol       ;scroll everything
	ldx lintmp
	dex
	dec tblx
	jmp wlog30
newlx	ldx nlines
scd10	dex
	jsr screen_set_position ;set up to addr
	cpx lintmp
	bcc scr40
	beq scr40       ;branch if finished
	phx
	dex
	jsr screen_copy_line ;scroll this line down
	plx
	bra scd10
scr40
	jsr screen_clear_line
	ldx nlines
	dex
	dex
scrd21
	cpx lintmp      ;done?
	bcc scrd22      ;branch if so
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	and ldtb1,y     ;was it continued
	beq scrd19      ;branch if so
	inx
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	ora ldtb1,y
	sta ldtb1,y
	dex
	bra scrd20
scrd19	inx
	ldy ldtbl_byte,x
	lda ldtbl_bit,x
	eor #$ff
	and ldtb1,y
	sta ldtb1,y
	dex
scrd20	dex
	bne scrd21
scrd22
	ldx lintmp
	jmp wlog30

;
;put a char on the screen
;
dspp	ldy #1
	sty blnct       ;blink cursor
	ldy pntr
	jmp screen_set_char_color

cursor_blink:
	lda blnsw       ;blinking crsr ?
	bne @5          ;no
	dec blnct       ;time to blink ?
	bne @5          ;no

	jsr screen_save_state
	lda #20         ;reset blink counter
	sta blnct
	ldy pntr        ;cursor position
	lsr blnon       ;carry set if original char
	php
	jsr screen_get_char_color
	inc blnon       ;set to 1
	plp
	bcs @1          ;branch if not needed
	sta gdbln       ;save original char
	stx gdcol       ;save original color
	ldx color       ;blink in this color
@1	bit mode
	bvc @3          ;not ISO
	cmp #$9f
	bne @2
	lda gdbln
	bra @4
@2	lda #$9f
	bra @4
@3	eor #$80        ;blink it
@4	ldy pntr
	jsr screen_set_char_color       ;display it
	jsr screen_restore_state

@5	rts

; call with .a: shflag
check_charset_switch:
	cmp #3
	bne @skip
	lda mode
	bmi @skip       ;not if locked
	bvs @skip       ;not if ISO mode
	eor #1          ;alternate between 2 and 3
	sta mode
	jmp screen_set_charset
@skip	rts


defcb: ; default basin callback vector
	sec
	rts

clear_cursor:
	lda #$FF
	sta blnsw
	lda blnon
	beq @1 ; rts
	lda gdbln
	ldy pntr
	jsr screen_set_char
	lda #0
	sta blnon
@1:	rts

runtb	.byt "LOAD",$d,"RUN:",$d
runtb_end:

fkeytb	.byt "LIST:", 13, 0
	.byt "SAVE", '"', "@:", 0
	.byt "LOAD ", '"', 0
	.byt "S", 'C' + $80, "-1:REM", 0
	.byt "RUN:", 13, 0
	.byt "MONITOR:", 13, 0
	.byt "DOS",'"', "$",13, 0
	.byt "DOS", '"', 0

beeplo: .lobytes 526,885,1404
beephi: .hibytes 526,885,1404

ldtbl_bit:	
.repeat 8
	.byte $01,$02,$04,$08,$10,$20,$40,$80
.endrepeat
ldtbl_byte:
.repeat 8,i
	.byte i,i,i,i,i,i,i,i
.endrepeat
