; System menu

.macpack cbm

.include "io.inc"
.include "kernal.inc"
.include "banks.inc"

.export util_menu
.import util_control
.import util_hexedit

.import ujsrfar

VERA_TILEMAP = $1b000

.segment "MENUZP" : zeropage
ptr:
	.res 2

.segment "MENUBSS"
screen_width:
	.res 1
screen_height:
	.res 1
selection:
	.res 1
temp:
	.res 1

.segment "MENU"

.proc util_menu: near
	; initialize variables
	stz selection

	jsr setup_screen
	jmp show_menu

	jmp util_control
.endproc

.proc setup_screen: near
	jsr screen        ;get current screen dimensions
	stx screen_width  ;get current screen dimensions
	sty screen_height ;get current screen dimensions

	; put it back into PETSCII upper/gfx mode
	lda #$8f
	jsr bsout
	lda #$8e
	jsr bsout
	; clear screen
	lda #$93
	jsr bsout

	; we'll keep the current petscii colors

	rts
.endproc

.proc show_menu: near
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #>VERA_TILEMAP
	sta VERA_ADDR_M
	lda #($20 | ^VERA_TILEMAP)
	sta VERA_ADDR_H

	ldx #0
@mt:
	lda menu_title,x
	beq @title_cont
	sta VERA_DATA0
	inx
	bra @mt
@title_cont:
	lda screen_width
	dec
	sta temp
	; write out the rest of the top line of the screen
	lda #$40
@mtl:
	sta VERA_DATA0
	inx
	cpx temp
	bcc @mtl
	; upper right corner
	lda #$6e
	sta VERA_DATA0
	; now draw the bottom border
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda screen_height
	dec
	clc
	adc #>VERA_TILEMAP
	sta VERA_ADDR_M
	lda #$6d
	sta VERA_DATA0
	lda #$40
	ldx #1
@mbl:
	sta VERA_DATA0
	inx
	cpx temp
	bcc @mbl
	; bottom right corner
	lda #$7d
	sta VERA_DATA0

	; now do left line
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #(>VERA_TILEMAP) + 1 ; row 1
	sta VERA_ADDR_M
	lda #($90 | ^VERA_TILEMAP) ; auto increment 256 (one row)
	sta VERA_ADDR_H

	lda #$42
	ldx #2 ; offset by 1
@mll:
	sta VERA_DATA0
	inx
	cpx screen_height
	bcc @mll

	; now do right line
	lda screen_width
	dec
	asl
	adc #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #(>VERA_TILEMAP) + 1 ; row 1
	sta VERA_ADDR_M

	lda #$42
	ldx #2 ; offset by 1
@mrl:
	sta VERA_DATA0
	inx
	cpx screen_height
	bcc @mrl

	lda #($20 | ^VERA_TILEMAP) ; auto increment 2
	sta VERA_ADDR_H

	ldx #0
@itemloop:
	txa
	asl
	tay

	lda menuitems,y
	sta ptr
	lda menuitems+1,y
	beq @enditems
	sta ptr+1

	lda #(<VERA_TILEMAP) + 2 ; first character in row
	sta VERA_ADDR_L
	txa
	clc
	adc #(>VERA_TILEMAP) + 1 ; row
	sta VERA_ADDR_M

	; invert text if selected
	stz temp
	lda #$80
	cpx selection
	bne :+
	sta temp
:	ldy #0
@iterloop:
	lda (ptr),y
	beq @enditer
	ora temp
	sta VERA_DATA0
	iny
	bne @iterloop

@enditer:
	iny
	iny
	lda #$20
	ora temp
@spaceiter:
	sta VERA_DATA0
	iny
	cpy screen_width
	bne @spaceiter

	inx
	bra @itemloop
@enditems:
	; handle keystrokes
keys:
	jsr getin
	beq keys
	cmp #13 ; return
	beq go
	cmp #$91
	beq up
	cmp #$11
	beq down
	cmp #27
	beq esc
	bra keys
go:
	lda selection
	asl
	tax
	jmp (menu_jumptable,x)
up:
	lda selection
	dec
	bmi keys
	sta selection
	jmp show_menu
down:
	lda selection
	inc
	cmp #MENUITEM_CNT
	bcs keys
	sta selection
	jmp show_menu
esc:
	jmp to_basic

.endproc

.proc x16edit: near
new:
	stz $04 ; R1L = file name length, 0 => no file

launch:
	ldx #10 ; First RAM bank used by the editor
	ldy #255 ; Last RAM bank used by the editor
	stz $05 ; Default value: Auto-indent and word
	stz $06 ; Default value: Tab stop width
	stz $07 ; Default value: Word wrap position
	lda #8 ; ¯\\_(ツ)_/¯
	sta $08 ; Set current active device number
	stz $09 ; Default value: text/background
	stz $0a ; Default value: header
	stz $0b ; Default value: status bar

	jsr ujsrfar
	.word $C006
	.byte BANK_X16EDIT
	rts
.endproc

do_diag:
	; clear screen
	lda #$93
	jsr bsout
	
@ln1:	stz VERA_ADDR_L
	lda #>VERA_TILEMAP+1
	sta VERA_ADDR_M
	lda #($20 | ^VERA_TILEMAP)
	sta VERA_ADDR_H
	ldx #0
:	lda warning1,x
	beq @ln2
	sta VERA_DATA0
	inx
	bra :-
@ln2:	stz VERA_ADDR_L
	inc VERA_ADDR_M
	inc VERA_ADDR_M
	ldx #0
:	lda warning2,x
	beq @ln3
	sta VERA_DATA0
	inx
	bra :-
@ln3:	stz VERA_ADDR_L
	inc VERA_ADDR_M
	ldx #0
:	lda warning3,x
	beq @ln4
	sta VERA_DATA0
	inx
	bra :-
@ln4:	stz VERA_ADDR_L
	inc VERA_ADDR_M
	ldx #0
:	lda warning4,x
	beq @ln5
	sta VERA_DATA0
	inx
	bra :-
@ln5:	stz VERA_ADDR_L
	inc VERA_ADDR_M
	inc VERA_ADDR_M
	ldx #0
:	lda warning5,x
	beq @ln6
	sta VERA_DATA0
	inx
	bra :-
@ln6:	stz VERA_ADDR_L
	inc VERA_ADDR_M
	inc VERA_ADDR_M
	ldx #0
:	lda warning6,x
	beq @getchoice
	sta VERA_DATA0
	inx
	bra :-
@getchoice:
	jsr getin
	beq @getchoice
	cmp #27		;ESC
	bne @enter
	; clear screen
	lda #$93
	jsr bsout
	jmp show_menu
@enter:	cmp #13
	bne @getchoice
	jsr ujsrfar
	.word $C000
	.byte BANK_DIAG
	rts

to_basic:
	lda #$93 ; clear screen
	jsr bsout
	rts

menu_title:
	.byte $70,$40
	scrcode "X16 MENU"
	.byte 0

MENUITEM_CNT = 5

menuitems:
	.word menu0, menu1, menu2, menu3, menu4, 0

menu_jumptable:
	.word util_control, util_hexedit, x16edit, do_diag, to_basic

menu0:
	scrcode "CONTROL PANEL"
	.byte 0
menu1:
	scrcode "HEXEDIT"
	.byte 0
menu2:
	scrcode "TEXT EDITOR"
	.byte 0
menu3:
	scrcode "DIAGNOSTICS"
	.byte 0
menu4:
	scrcode "EXIT TO BASIC"
	.byte 0

warning1:
	scrcode "!!!!! WARNING !!!!!"
	.byte 0
warning2:
	scrcode " ONLY WAY TO EXIT"
	.byte 0
warning3:
	scrcode " DIAGNOSTIC IS TO"
	.byte 0
warning4:
	scrcode "POWERCYCLE OR RESET"
	.byte 0
warning5:
	scrcode "   ENTER=ACCEPT"
	.byte 0
warning6:
	scrcode "    ESC=CANCEL"
	.byte 0
