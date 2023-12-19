;X16 Control Panel
;by David Murray 2022
;dfwgreencars@gmail.com
;
;Adapted to run from ROM
;by MooingLemur 2023
;x16e546@oomox.com

.pc02

.macpack cbm

.export util_control

.include "banks.inc"
.include "kernal.inc"
.include "io.inc"
.include "regs.inc"

; We're borrowing the line editor buffer area.
; We must ensure to zero it out
; before returning to BASIC
BSS_BASE        = $0200

nvram_buffer   := BSS_BASE
menu_select    := BSS_BASE+$20    ;currently selected menu line
screen_w       := BSS_BASE+$21    ;current screen witdh setting
screen_h       := BSS_BASE+$22    ;current screen height setting
bgcol          := BSS_BASE+$23    ;current bg color
tcol           := BSS_BASE+$24    ;current text color
hexnum         := BSS_BASE+$25    ;number to be displayed in hex
menu_l         := BSS_BASE+$26    ;lowest menu item possible
menu_h         := BSS_BASE+$27    ;highest menu item possible
source_l       := BSS_BASE+$28
source_h       := BSS_BASE+$29
counter1       := BSS_BASE+$2A
layout         := BSS_BASE+$2B
layout_changed := BSS_BASE+$2C
egg            := BSS_BASE+$2D
safemode       := BSS_BASE+$2E
tmp1           := BSS_BASE+$2F
tmp2           := BSS_BASE+$30    ;2 bytes
tmp3           := BSS_BASE+$32    ;2 bytes

ptr            := $D4             ;Borrowed ZP from BASIC (poker)

filename_buf   := $00FF

rtc_address     = $6f
nvram_base      = $40
kernal_nvram_cksum_offset = $1f

plot            = $fff0

.proc util_control: near
	; make sure input is keyboard and output is screen
	jsr clrch

	; close all open files
	jsr clall

	; clear screen
	lda #$93
	jsr bsout

	; disable ISO mode and enable PETSCII upper/symbol mode
	lda #$8f
	jsr bsout
	lda #$8e
	jsr bsout

	; store state to track which menus we've been in
	stz layout_changed

	; fetch keyboard layout id
	sec
	jsr keymap
	inc
	sta layout

	stz egg

	stz safemode
	stz menu_select
	jsr get_screen_dimensions
	jsr get_current_color_scheme
	jsr get_nvram

	stz VERA_CTRL
	; fall through to main menu
.endproc

.proc main_menu: near
	lda #0
	sta menu_l
	lda #6
	sta menu_h
	ldy #0
dsm1:	lda menutext,y
	beq dsm1a
	jsr bsout
	iny
	bra dsm1
dsm1a:
	ldy #0
	lda VERA_DC_VIDEO
	and #3
	cmp #2
	bcc @vga
	beq @ntsc
@rgb:
	lda menutext_rgb,y
	beq dsm2
	jsr bsout
	iny
	bra @rgb
@ntsc:
	lda menutext_ntsc,y
	beq dsm2
	jsr bsout
	iny
	bra @ntsc
@vga:
	lda menutext_vga,y
	beq dsm2
	jsr bsout
	iny
	bra @vga
dsm2:
	lda screen_h
	cmp #25
	bcs :+
	jmp dsm4a
:	ldy #0
dsm3:
	lda infoscreen,y
	beq dsm3a
	jsr bsout
	iny
	bra dsm3
dsm3a:
	ldx #16
	ldy #15
	jsr plot
	lda nvram_buffer
	clc
	adc #'0'
	jsr bsout

	ldx #17
	ldy #6
	jsr plot
	lda #%01111110
	sta VERA_CTRL
	lda $9f29
	cmp #'V'
	bne dsm3b
	stz VERA_CTRL
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2a
	stz VERA_CTRL
	pha
	jsr convert_high_nybble
	jsr bsout
	pla
	jsr convert_low_nybble
	jsr bsout

	lda #'.'
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2b
	stz VERA_CTRL
	pha
	jsr convert_high_nybble
	jsr bsout
	pla
	jsr convert_low_nybble
	jsr bsout

	lda #'.'
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2c
	stz VERA_CTRL
	pha
	jsr convert_high_nybble
	jsr bsout
	pla
	jsr convert_low_nybble
	jsr bsout
	bra dsm4
dsm3b:
	stz VERA_CTRL
	ldy #0
:	lda unknown,y
	beq dsm4
	jsr bsout
	iny
	bra :-
dsm4:
	lda #13
	jsr bsout
	ldy #0
:	lda otherstuff,y
	beq dsm4a
	jsr bsout
	iny
	bra :-
dsm4a:
	jsr highlight_menu_option
	jsr show_current_video_status
dsm5:	jsr getin       ;get keyboard input
	cmp #$91        ;cursor up
	bne dsm6
	jsr menu_up
	jmp dsm5
dsm6:	cmp #$11        ;cursor down
	bne dsm7
	jsr menu_down
	jmp dsm5
dsm7:	cmp #133        ;f1
	bne dsm8
	lda VERA_DC_VIDEO
	and #%11111100
	ora #%00000001
	sta VERA_DC_VIDEO
	jmp main_menu
dsm8:	cmp #137        ;f2
	bne dsm9
	lda VERA_DC_VIDEO
	and #%11111100
	ora #%00000010
	sta VERA_DC_VIDEO
	jmp main_menu
dsm9:	cmp #134        ;f3
	bne dsma
	lda VERA_DC_VIDEO
	and #%11111100
	ora #%00000011
	sta VERA_DC_VIDEO
	jmp main_menu
dsma:	cmp #138        ;f4
	bne dsmb
	lda safemode
	dec
	and #1
	sta safemode
	beq dsma1
	jsr apply_safemode
	jmp main_menu
dsma1:
	jsr restore_defaults
	jmp main_menu
dsmb:	cmp #135        ;f5
	bne dsmc
	lda VERA_DC_VIDEO
	eor #%00000100
	sta VERA_DC_VIDEO
	jmp main_menu
dsmc:	cmp #139        ;f6
	bne dsmd
	lda VERA_DC_VIDEO
	eor #%00001000
	sta VERA_DC_VIDEO
	jmp main_menu
dsmd:	cmp #27			;Esc
	bne dsme
	lda #6
	sta menu_select
	jmp main_menu
dsme:	cmp #'T'
	bne dsmf
	jsr smpte_bars
	jmp main_menu
dsmf:	cmp #13         ;return
	bne dsmg
	jmp execute_command
dsmg:	jmp dsm5
menutext:
	.byte 147       ;clear screen
	.byte "X16 CONTROL PANEL",13
	.byte 163,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,163,13
	.byte " COLOR SCHEME",13
	.byte " SCREEN MODE",13
	.byte " SCREEN GEOMETRY",13
	.byte " TIME AND DATE",13
	.byte " KEYBOARD LAYOUT",13
	.byte " SAVE SETTINGS",13
	.byte " EXIT TO BASIC",13,13
	.byte "VIDEO OUTPUT MODE",13
	.byte 163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,163,163,163,163,13
	.byte 18,"F1",146," VGA   ",18,"F4",146," CRTSAFE",13
	.byte 18,"F2",146," NTSC  ",18,"F5",146," ",0
menutext_vga:
	.byte "N/A",13
	.byte 18,"F3",146," RGB   ",18,"F6",146," N/A"
	.byte 0
menutext_ntsc:
	.byte "COLOR",13
	.byte 18,"F3",146," RGB   ",18,"F6",146," 240P"
	.byte 0
menutext_rgb:
	.byte "CSYNC",13
	.byte 18,"F3",146," RGB   ",18,"F6",146," 240P"
	.byte 0
infoscreen:
	.byte 13,13,"NVRAM PROFILE:",13
	.byte "VERA: ",13,0
unknown:
	.byte "UNKNOWN VER.",0
otherstuff:
	.byte "T = TEST PATTERN",13,0
.endproc

.proc menu_up: near
	lda menu_select
	cmp menu_l
	beq mu1
	jsr clear_menu_option
	dec menu_select
	jsr highlight_menu_option
mu1:	rts
.endproc

.proc menu_down: near
	lda menu_select
	cmp menu_h
	beq md1
	jsr clear_menu_option
	inc menu_select
	jsr highlight_menu_option
md1:	rts	
.endproc


.proc highlight_menu_option: near
	lda #%00000001
	sta VERA_ADDR_H
	lda #$b2
	clc
	adc menu_select
	sta VERA_ADDR_M
	ldx #2
hmo1:	stx VERA_ADDR_L
	lda VERA_DATA0
	ora #%10000000
	sta VERA_DATA0
	inx
	inx
	cpx #32
	bne hmo1
	rts
.endproc

.proc clear_menu_option: near
	lda #%00000001
	sta VERA_ADDR_H
	lda #$b2
	clc
	adc menu_select
	sta VERA_ADDR_M
	ldx #2
cmo1:	stx VERA_ADDR_L
	lda VERA_DATA0
	and #%01111111
	sta VERA_DATA0
	inx
	inx
	cpx #32
	bne cmo1
	rts
.endproc

;this little routine places a dot next to the current
;video mode and then whether or not NTSC color is on.
;as well as 240p mode for RGB/NTSC
.proc show_current_video_status: near
	;first show safe mode bit
	lda #%00000001
	sta VERA_ADDR_H
	lda #$bc
	sta VERA_ADDR_M
	lda #$16
	sta VERA_ADDR_L
	lda safemode
	beq scv1
	lda #81	;round ball
	bra scv2
scv1:	lda #32	;blank space
scv2:	sta VERA_DATA0
	;next show ntsc color status
	inc VERA_ADDR_M
	lda VERA_DC_VIDEO
	and #%00000100
	bne scv3
	lda #81	;round ball
	bra scv4
scv3:	lda #32	;blank space
scv4:	sta VERA_DATA0
	;next show progressive bit
	inc VERA_ADDR_M
	lda VERA_DC_VIDEO
	and #%00001000
	beq scv5
	lda #81	;round ball
	bra scv6
scv5:	lda #32	;blank space
scv6:	sta VERA_DATA0
	;now show video output status
	lda #%00000001
	sta VERA_ADDR_H
	lda VERA_DC_VIDEO
	and #%00000011
	clc
	adc #$bb
	sta VERA_ADDR_M
	lda #$04
	sta VERA_ADDR_L
	lda #81	;round ball
	sta VERA_DATA0
	rts
.endproc

.proc execute_command: near
	lda menu_select
	bne exe1
	jmp color_menu      ;color scheme
exe1:	cmp #1          ;screen mode
	bne exe2
	jmp mode_menu
exe2:	cmp #2          ;screen geometry
	bne exe3
	jmp geometry
exe3:	cmp #3          ;time and date
	bne exe4
	jmp time_date_menu
exe4:	cmp #4          ;keyboard layout
	bne exe5
	jmp keyboard_layout_menu
exe5:	cmp #5          ;save_menu
	bne exe6
	jmp save_menu
exe6:	cmp #6          ;exit to basic
	bne exe7

	ldx #rtc_address	;Enable battery backup, bit 3 (VBATEN) of RTC internal address 0x03
	ldy #3
	jsr i2c_read_byte
	bcs :+
	ora #8
	jsr i2c_write_byte

:	lda #147        ;clear the screen
	jsr bsout
	rts
exe7:	jmp main_menu   ;we should never end up here.
.endproc

.proc geometry: near
	lda #%00100001  ;increment by 2 every write
	;draw top line
	sta VERA_ADDR_H
	lda #$b0
	sta VERA_ADDR_M
	lda #0
	sta VERA_ADDR_L
	lda #79         ;petscii top-left corner
	sta VERA_DATA0
	lda screen_w
	sec
	sbc #2
	tax
	lda #119        ;petscii top piece
gm01:	sta VERA_DATA0
	dex
	cpx #00
	bne gm01
	lda #80         ;petscii top-right corner
	sta VERA_DATA0
	;now do most of the screen
	lda screen_h
	sec
	sbc #2
	tay

gm05:	tya
	adc #$af
	sta VERA_ADDR_M
	lda #0
	sta VERA_ADDR_L
	lda #116        ;petscii left piece
	sta VERA_DATA0
	lda screen_w
	sec
	sbc #2
	tax
	lda #32         ;petscii space
gm06:	sta VERA_DATA0
	dex
	cpx #00
	bne gm06
	lda #106        ;petscii right piece
	sta VERA_DATA0
	dey
	cpy #00
	bne gm05	
	;now do the bottom line
	lda screen_h
	clc
	adc #$af
	sta VERA_ADDR_M
	lda #0
	sta VERA_ADDR_L
	lda #76		;petscii bottom-left corner
	sta VERA_DATA0
	lda screen_w
	sec
	sbc #2
	tax
	lda #111        ;petscii bottom piece
gm08:	sta VERA_DATA0
	dex
	cpx #00
	bne gm08
	lda #122        ;petscii bottom-right corner
	sta VERA_DATA0
	;write text
	ldy #0
gem1:	lda geo_screen_text,y
	beq gem2
	jsr bsout
	iny
	jmp gem1
gem2:	lda #2
	sta menu_select
	sta menu_l
	lda #6
	sta menu_h
	jsr highlight_menu_option
ge10:	jsr getin
	cmp #$91        ;cursor up
	bne ge11
	jsr menu_up
	jmp ge10
ge11:	cmp #$11        ;cursor down
	bne ge13
	jsr menu_down
	jmp ge10
ge13:	cmp #87         ;w
	bne ge14
	jsr w_up
	jmp ge10
ge14:	cmp #83         ;s
	bne ge15
	jsr s_down
	jmp ge10
ge15:	cmp #65         ;a
	bne ge16
	jsr a_left
	jmp ge10
ge16:	cmp #68         ;d
	bne ge16a
	jsr d_right
	jmp ge10
ge16a:
	cmp #$d6            ;shift+V
	bne ge16b
	bra eggy
ge16b:
	cmp #27             ;Esc
	beq ge18a
ge17:	cmp #13         ;return	
	bne ge19
	lda menu_select
	cmp #5
	bne ge18
	jsr restore_defaults
	jmp geometry
ge18:	cmp #6
	bne ge19
ge18a:	lda #2
	sta menu_select
	jmp main_menu
ge19:	jmp ge10	

eggy:
	ldx #6
	stx tcol
	lda color_table,x
	jsr bsout
	lda #1
	jsr bsout
	tax
	sta bgcol
	lda color_table,x
	jsr bsout
	lda #1
	jsr bsout

	lda #$00
	clc
	jsr screen_mode

	lda #$07
	sta egg
	clc
	jsr screen_mode
	lda #$2c
	sta VERA_DC_HSCALE
	lda #$40
	sta VERA_DC_VSCALE
	lda #$ab
	sta VERA_DC_BORDER
	lda #2
	sta VERA_CTRL
	lda #$10
	sta VERA_DC_HSTART
	lda #$90
	sta VERA_DC_HSTOP
	lda #$1c
	sta VERA_DC_VSTART
	lda #$d3
	sta VERA_DC_VSTOP
	stz VERA_CTRL
	lda #4
	jsr screen_set_charset
	lda #2
	sta menu_select
	jmp main_menu

w_up:
	lda menu_select
	cmp #2          ;screen size
	bne cu01
	jsr clear_240p
	jmp inc_vscale
cu01:	cmp #3          ;h/v start
	bne cu02
	jmp dec_vstart
cu02:	cmp #4
	beq dec_vstop
	rts
	

s_down:
	lda menu_select
	cmp #2	;screen size
	bne cd01
	jsr clear_240p
	jmp dec_vscale
cd01:	cmp #3	;hv-start
	bne cd02
	jmp inc_vstart
cd02:	cmp #4
	beq inc_vstop
	rts

a_left:
	lda menu_select
	cmp #2	;screen size
	bne cl01
	jmp inc_hscale
cl01:	cmp #3	;hv-start
	bne cl02
	jmp dec_hstart
cl02:	cmp #4
	beq dec_hstop
	rts

d_right:
	lda menu_select
	cmp #2	;screen size
	bne cr01
	jmp dec_hscale
cr01:	cmp #3	;hv-start	
	bne cr02
	jmp inc_hstart
cr02:	cmp #4
	beq inc_hstop
	rts

clear_240p:
	stz VERA_CTRL
	lda #$08
	trb VERA_DC_VIDEO
	rts

inc_vstop:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_VSTOP
	cmp #$f0
	bcs ivsp
	inc VERA_DC_VSTOP
ivsp:	lda #%00000000
	sta VERA_CTRL
	rts

dec_vstop:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_VSTOP
	cmp VERA_DC_VSTART
	beq dvsp
	dec VERA_DC_VSTOP
dvsp:	lda #%00000000
	sta VERA_CTRL
	rts

inc_hstop:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_HSTOP
	cmp #$a0
	bcs ihsp
	inc VERA_DC_HSTOP
ihsp:	lda #%00000000
	sta VERA_CTRL
	rts

dec_hstop:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_HSTOP
	cmp VERA_DC_HSTART
	beq dhsp
	dec VERA_DC_HSTOP
dhsp:	lda #%00000000
	sta $9f25
	rts

inc_hstart:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_HSTART
	cmp VERA_DC_HSTOP
	bcs ihst
	inc VERA_DC_HSTART
ihst:	lda #%00000000
	sta VERA_CTRL
	rts

dec_hstart:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_HSTART
	cmp #$00
	beq dhst
	dec VERA_DC_HSTART
dhst:	lda #%00000000
	sta VERA_CTRL
	rts

inc_vstart:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_VSTART
	cmp VERA_DC_VSTOP
	bcs ivst
	inc VERA_DC_VSTART
ivst:	lda #%00000000
	sta VERA_CTRL
	rts

dec_vstart:
	lda #%00000010
	sta VERA_CTRL
	lda VERA_DC_VSTART
	cmp #$00
	beq dvst
	dec VERA_DC_VSTART
dvst:	lda #%00000000
	sta VERA_CTRL
	rts

inc_vscale:
	lda VERA_DC_VSCALE
	cmp #$ff
	beq ivs1
	inc VERA_DC_VSCALE
ivs1:	rts

dec_vscale:
	lda VERA_DC_VSCALE
	cmp #$00
	beq ivs1
	dec VERA_DC_VSCALE
dvs1:	rts

inc_hscale:
	lda VERA_DC_HSCALE
	cmp #$ff
	beq ihs1
	inc VERA_DC_HSCALE
ihs1:	rts

dec_hscale:
	lda VERA_DC_HSCALE
	cmp #$00
	beq ihs1
	dec VERA_DC_HSCALE
dhs1:	rts

geo_screen_text:
	.byte 19,17,17,29,"SCREEN GEOMETRY",13
	.byte 29,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,13
	.byte 29,"SET SCREEN SIZE",13
	.byte 29,"SET H/V START",13
	.byte 29,"SET H/V STOP",13
	.byte 29,"SET TO DEFAULT",13
	.byte 29,"EXIT",13
	.byte 17,29,"USE WASD KEYS TO",13
	.byte 29,"ADJUST SCREEN",13,0
.endproc

.proc restore_defaults: near
	sec
	jsr screen_mode
	clc
	jsr screen_mode
	rts
.endproc

.proc mode_menu: near
	lda #0
	sta menu_select
	sta menu_l
	lda #12
	sta menu_h

mod0:	ldy #0
mod1:	lda mode_screen_text,y
	beq mod1a
	jsr bsout
	iny
	jmp mod1
mod1a:
	ldy #0
	lda screen_h
	cmp #16
	bcc mod2
mod1b:
	lda mode_screen_text2,y
	beq mod2
	jsr bsout
	iny
	jmp mod1b
mod2:	sec
	jsr screen_mode ;get
	cmp #11
	bcc :+
	lda #0
:	sta menu_select
	jsr highlight_menu_option
mod5:	jsr getin
	cmp #$91        ;cursor up
	bne mod6
	jsr menu_up
	jmp mod5
mod6:	cmp #$11        ;cursor down
	bne mod7
	jsr menu_down
	jmp mod5
mod7:	cmp #13         ;return
	bne mod8
	jmp mode_change
mod8:	cmp #27			;Esc
	beq mc00
mod9:
	jmp mod5

mode_change:
	lda menu_select
	cmp #12
	bne mc01
mc00:	lda #1
	sta menu_select
	jmp main_menu
mc01:	lda menu_select
	clc
	jsr screen_mode ;set
	jsr get_screen_dimensions
	lda safemode
	beq mc02
	jsr apply_safemode
mc02:
	jmp mod0
mode_screen_text:
	.byte 147,29,"SCREEN MODE",13
	.byte 29,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,13
	.byte 29,"0 -80 X 60",13
	.byte 29,"1 -80 X 30",13
	.byte 29,"2 -40 X 60",13
	.byte 29,"3 -40 X 30",13
	.byte 29,"4 -40 X 15",13
	.byte 29,"5 -20 X 30",13
	.byte 29,"6 -20 X 15",13
	.byte 29,"7 -22 X 23",13
	.byte 29,"8 -64 X 50",13
	.byte 29,"9 -64 X 25",13
	.byte 29,"10-32 X 50",13
	.byte 29,"11-32 X 25",13
	.byte 29,"EXIT",0
mode_screen_text2:
	.byte 13,13,"MODES 7 AND ABOVE"
	.byte 13,"ARE DESIGNED TO BE"
	.byte 13,"NATIVELY CRT-SAFE."
	.byte 13,"SAFE MODE AT MAIN"
	.byte 13,"MENU RESCALES OTHER"
	.byte 13,"MODES INWARD TO"
	.byte 13,"AVOID OVERSCAN.",0
.endproc

.proc get_current_color_scheme: near
	lda #%00000001
	sta VERA_ADDR_H
	lda #$b0
	sta VERA_ADDR_M
	lda #01
	sta VERA_ADDR_L
	lda VERA_DATA0  ;get color data for top-left character	
	and #%00001111
	sta tcol
	lda VERA_DATA0  ;get color data for top-left character (again)
	and #%11110000
	lsr
	lsr
	lsr
	lsr
	sta bgcol
	rts
.endproc

.proc color_menu: near
	;now setup screen
	lda #2
	sta menu_select
	sta menu_l
	lda #5
	sta menu_h

col0:	ldy #0
col1:	lda col_screen_text,y
	beq col2
	jsr bsout
	iny
	jmp col1
col2:	lda #%00100001  ;inc by 2
	sta VERA_ADDR_H
	lda #$b4
	sta VERA_ADDR_M
	lda #20
	sta VERA_ADDR_L
	lda tcol
	jsr hexwrite
	lda #$b5
	sta VERA_ADDR_M
	lda #20
	sta VERA_ADDR_L
	lda bgcol
	jsr hexwrite
	lda #$b6
	sta VERA_ADDR_M
	lda #20
	sta VERA_ADDR_L
	lda VERA_DC_BORDER
	jsr hexwrite
	jsr highlight_menu_option
col5:	jsr getin
	cmp #$91        ;cursor up
	bne col6
	jsr menu_up
	jmp col5
col6:	cmp #$11        ;cursor down
	bne col7
	jsr menu_down
	jmp col5
col7:	cmp #157        ;cursor left
	bne col8
	jsr col_cursor_left
	jmp col0
col8:	cmp #29	        ;cursor right
	bne col8a
	jsr col_cursor_right
	jmp col0
col8a:
	cmp #27             ;ESC
	beq col9a
col9:	cmp #13	        ;return
	bne col10
	lda menu_select
	cmp #5
	bne col10
col9a:	stz menu_select
	jmp main_menu
col10:	jmp col5

col_cursor_left:
	lda menu_select
	cmp #2
	bne ccl1
	jmp dec_text_color
ccl1:	cmp #3
	bne ccl2
	jmp dec_bg_color
ccl2:	cmp #4
	bne ccl3
	jmp dec_border_color
ccl3:	rts

col_cursor_right:
	lda menu_select
	cmp #2
	bne ccr1
	jmp inc_text_color
ccr1:	cmp #3
	bne ccr2
	jmp inc_bg_color
ccr2:	cmp #4
	bne ccr3
	jmp inc_border_color
ccr3:	rts

inc_text_color:
	lda tcol
	inc
	and #$0f
	sta tcol
	tay
	lda color_table,y
	jsr bsout
	rts

dec_text_color:
	lda tcol
	dec
	and #$0f
	sta tcol
	tay
	lda color_table,y
	jsr bsout
	rts

inc_bg_color:
	lda bgcol
	inc
	and #$0f
	sta bgcol
	lda #1
	jsr bsout     ; swap fg/bg color
	ldy bgcol
	lda color_table,y
	jsr bsout
	lda #1
	jsr bsout     ; swap fg/bg color
	rts

dec_bg_color:
	lda bgcol
	dec
	and #$0f
	sta bgcol
	lda #1
	jsr bsout     ; swap fg/bg color
	ldy bgcol
	lda color_table,y
	jsr bsout
	lda #1
	jsr bsout     ; swap fg/bg color
	rts

inc_border_color:
	inc VERA_DC_BORDER
	rts

dec_border_color:
	dec VERA_DC_BORDER
	rts

col_screen_text:
	.byte 147,17,17,29,"SCREEN COLORS",13
	.byte 29,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,13
	.byte 29,"   TEXT:",13
	.byte 29,"BACKGRN:",13
	.byte 29," BORDER:",13
	.byte 29,"   EXIT",13
	.byte 17,29,"LEFT/RIGHT TO",13
	.byte 29,"ADJUST COLORS",13,0
.endproc

.proc get_screen_dimensions: near
	jsr screen       ; get current screen dimensions
	stx screen_w
	sty screen_h
	rts
.endproc


.proc veraplot: near
	lda #%00100001  ;inc by 2
	sta VERA_ADDR_H
	txa
	clc
	adc #$b0
	sta VERA_ADDR_M
	tya
	asl
	sta VERA_ADDR_L

	rts
.endproc

;This routine writes a 2-digit hex number to
;the screen.  VERA needs to be already
;configured for the right VRAM location.
.proc hexwrite: near
	pha
	lda VERA_ADDR_H
	pha
	and #%00000111
	sta VERA_ADDR_H
	lda VERA_DATA0
	asl
	pla
	sta VERA_ADDR_H
	pla
	pha
	php
	lsr
	lsr
	lsr
	lsr
	tay
	lda hex_code_table,y
	plp
	php
	bcc @1
	ora #$80
@1:	sta VERA_DATA0
	plp
	pla
	php
	and #%00001111
	tay
	lda hex_code_table,y
	plp
	bcc @2
	ora #$80
@2:	sta VERA_DATA0
	rts	
.endproc

.proc keyboard_layout_menu: near
	lda #0
	sta menu_l
	lda #0
	sta menu_h
	lda #$93
	jsr bsout
klm0:	ldy #0
klm1:	lda key_menu_text,y
	beq klm2
	jsr bsout
	iny
	jmp klm1
klm2:	stz menu_select
	jsr kl_print_current
	jsr highlight_menu_option

klm3:	jsr getin       ;get keyboard input
	cmp #$91        ;cursor up
	bne klm5
	jsr menu_up
	jmp klm3
klm5:	cmp #$11        ;cursor down
	bne klm6
	jsr menu_down
	jmp klm3

klm6:	cmp #157        ;cursor left
	bne klm7
	jsr kl_cursor_left
	bra klm0
klm7:	cmp #29	        ;cursor right
	bne klm8
	jsr kl_cursor_right
	bra klm0
klm8:	cmp #13         ;return
	beq kl_execute
klm9:	cmp #27			;Esc
	beq kl_execute
klma:	bra klm3

kl_execute:
kle2:	
	jsr kl_apply_layout
	lda #4
	sta menu_select
	jmp main_menu

kl_cursor_left:
	lda layout
	beq kllr
	dec
	sta layout
kllr:	rts

kl_cursor_right:
	lda layout
	cmp #layout_count-1
	beq klrr
	inc
	sta layout
klrr:	rts

kl_apply_layout:
	lda layout
	bne kal1
	inc
kal1: 
	asl
	tay
	lda layouts,y
	sta ptr
	lda layouts+1,y
	sta ptr+1

	ldy #0
kal2:
	lda (ptr),y
	sta filename_buf,y
	beq kal3
	iny
	bra kal2
kal3:	
	ldx #<filename_buf
	ldy #>filename_buf
	clc
	jsr keymap

	lda #1
	sta layout_changed

	rts

kl_print_current:
	ldy #6
	ldx #2
	clc
	jsr plot

	lda #$12
	jsr bsout

	lda layout
	asl
	tay
	lda layouts,y
	sta ptr
	lda layouts+1,y
	sta ptr+1
	ldy #0
klpc1:
	lda (ptr),y
	beq klpc2
	jsr bsout
	iny
	bra klpc1
klpc2:
	lda #$92
	jsr bsout
	rts

key_menu_text:
	.byte 19,29,"KEYBOARD LAYOUT",13
	.byte 163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,163,13
	.byte " MAP:             ",13,13
	.byte "LEFT/RIGHT TO",13
	.byte " CHANGE LAYOUT",13,13
	.byte "ENTER TO CONFIRM",13,0


.endproc

.proc save_menu: near
	lda #0
	sta menu_l
	lda #3
	sta menu_h
	ldy #0
svm1:	lda save_menu_text,y
	beq svm2
	jsr bsout
	iny
	jmp svm1
svm2:	stz menu_select
	jsr highlight_menu_option
svm3:	jsr getin       ;get keyboard input
	cmp #$91        ;cursor up
	bne svm5
	jsr menu_up
	jmp svm3
svm5:	cmp #$11        ;cursor down
	bne svm6
	jsr menu_down
	jmp svm3
svm6:	cmp #13         ;return
	beq sm_execute
svm7:	cmp #27         ;Esc
	beq sme4
svm8:	jmp svm3

sm_execute:
	lda menu_select
	bne sme2
	jmp save_to_nvram0
sme2:	cmp #1
	bne sme3
	jmp save_to_nvram1
sme3:	cmp #2
	bne sme4
	jmp save_autoboot
sme4:	lda #5
	sta menu_select
	jmp main_menu
	
save_to_nvram0:
	sec
	jsr screen_mode ;get current screen mode
	sta nvram_buffer+1
	lda VERA_DC_VIDEO
	sta nvram_buffer+2
	lda VERA_DC_HSCALE
	sta nvram_buffer+3
	lda VERA_DC_VSCALE
	sta nvram_buffer+4
	lda VERA_DC_BORDER
	sta nvram_buffer+5
	lda #2
	sta VERA_CTRL
	lda VERA_DC_HSTART
	sta nvram_buffer+6
	lda VERA_DC_HSTOP
	sta nvram_buffer+7
	lda VERA_DC_VSTART
	sta nvram_buffer+8
	lda VERA_DC_VSTOP
	sta nvram_buffer+9
	stz VERA_CTRL
	lda bgcol
	asl
	asl
	asl
	asl
	clc
	adc tcol
	sta nvram_buffer+10
	lda layout_changed
	beq :+
	lda layout
	sta nvram_buffer+11
:	jmp write_to_nvram

save_to_nvram1:
	sec
	jsr screen_mode ;get current screen mode
	sta nvram_buffer+14
	lda VERA_DC_VIDEO
	sta nvram_buffer+15
	lda VERA_DC_HSCALE
	sta nvram_buffer+16
	lda VERA_DC_VSCALE
	sta nvram_buffer+17
	lda VERA_DC_BORDER
	sta nvram_buffer+18
	lda #2
	sta VERA_CTRL
	lda VERA_DC_HSTART
	sta nvram_buffer+19
	lda VERA_DC_HSTOP
	sta nvram_buffer+20
	lda VERA_DC_VSTART
	sta nvram_buffer+21
	lda VERA_DC_VSTOP
	sta nvram_buffer+22
	stz VERA_CTRL
	lda bgcol
	asl
	asl
	asl
	asl
	clc
	adc tcol
	sta nvram_buffer+23
	lda layout_changed
	beq :+
	lda layout
	sta nvram_buffer+24
:	; fall through

write_to_nvram:
	;now create checksum
	ldx #0
	lda #0
	clc
chs1:	adc nvram_buffer,x ; carry is clear on loop
	inx
	cpx #kernal_nvram_cksum_offset
	bcc chs1
	sta nvram_buffer+kernal_nvram_cksum_offset
	;now copy this data to nvram
	stz counter1
wtn1:	lda counter1
	cmp #kernal_nvram_cksum_offset+1
	beq nvmsg1
	clc
	adc #nvram_base
	tay
	ldx counter1
	lda nvram_buffer,x
	ldx #$6f	;i2c bus address of rtc
	jsr i2c_write_byte
	inc counter1
	jmp wtn1
	;now display message
nvmsg1:	ldx #0
nvmsg2:	lda nv_msg,x
	beq nvrtm
	jsr bsout
	inx
	bra nvmsg2
nvrtm:	jsr getin
	beq nvrtm
	jmp sme4

save_menu_text:
	.byte 147       ;clear screen
	.byte "SAVE SETTINGS",13
	.byte 163,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,163,13
	.byte " NVRAM - 0",13
	.byte " NVRAM - 1",13
	.byte " AUTOBOOT.X16",13
	.byte " CANCEL",13,13,0

nv_msg: .byte 147,"SAVED TO NVRAM,",13,"PRESS ANY KEY.",0
.endproc

.proc get_nvram: near
	stz counter1
gtnv1:	lda counter1
	cmp #kernal_nvram_cksum_offset
	bcs gtnv2
	; carry is clear
	adc #$40
	tay
	ldx #$6f        ;i2c bus address of rtc
	jsr i2c_read_byte
	ldx counter1
	sta nvram_buffer,x
	inc counter1
	bra gtnv1
gtnv2:	rts
.endproc

.macro WRITE_RAW_BYTES start, end
	.local @1
	ldx #0
@1:
	lda start,x
	jsr bsout
	inx
	cpx #(end-start)
	bne @1
.endmacro

.proc save_autoboot: near
	; copy filename itself to RAM so kernal can read it
	ldx #filename_len
sab1:	lda filename-1,x
	sta a:filename_buf-1,x
	dex
	bne sab1


	lda #filename_len   ;length of filename
	ldx #<filename_buf
	ldy #>filename_buf
	jsr setnam          ;setnam a=file name length x/y=pointer to filename

	lda #$02
	ldx #$08
	ldy #$02
	jsr setlfs          ;setlfs a=logical number x=device number y=secondary

	jsr open
	
	ldx #$02
	jsr ckout           ;open for write and set output channel

	WRITE_RAW_BYTES basic_start, basic_prog1

	;Foreground color
	lda tcol
	jsr convert_high_nybble
	jsr bsout
	lda tcol
	jsr convert_low_nybble
	jsr bsout
	lda #','
	jsr bsout
	lda #'$'
	jsr bsout
	;Background color
	lda bgcol
	jsr convert_high_nybble
	jsr bsout
	lda bgcol
	jsr convert_low_nybble
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog1, basic_prog2

	;kernal screen mode
	sec
	jsr screen_mode    ;get current screen mode
	pha
	jsr convert_high_nybble
	jsr bsout
	pla
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog2, basic_prog3

	;Display Composer register (DC_VIDEO)
	lda VERA_DC_VIDEO
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_VIDEO
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog3, basic_prog4

	;Horizontal Scale register (DC_HSCALE)
	lda VERA_DC_HSCALE
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_HSCALE
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog4, basic_prog5

	;Verical Scale register (DC_VSCALE)
	lda VERA_DC_VSCALE
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_VSCALE
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog5, basic_prog6

	;Border Color (DC_BORDER)
	lda VERA_DC_BORDER
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_BORDER
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog6, basic_prog8

	;DCSEL=1
	lda #$02
	sta VERA_CTRL

	;Horizontal Start (DC_HSTART)
	lda VERA_DC_HSTART
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_HSTART
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog8, basic_prog9

	;Horizontal Stop (DC_HSTOP)
	lda VERA_DC_HSTOP
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_HSTOP
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog9, basic_prog10

	;Vertical Start (DC_VSTART)
	lda VERA_DC_VSTART
	jsr convert_high_nybble	
	jsr bsout
	lda VERA_DC_VSTART
	jsr convert_low_nybble	
	jsr bsout
	lda #0
	jsr bsout

	WRITE_RAW_BYTES basic_prog10, basic_prog11

	;Vertical STOP (DC_VSTOP)
	lda VERA_DC_VSTOP
	jsr convert_high_nybble
	jsr bsout
	lda VERA_DC_VSTOP
	jsr convert_low_nybble
	jsr bsout
	lda #0
	jsr bsout

	;DCSEL=0
	lda #00
	sta VERA_CTRL

	WRITE_RAW_BYTES basic_prog11, basic_prog13

	lda layout
	asl
	tay
	lda layouts,y
	sta ptr
	lda layouts+1,y
	sta ptr+1

	ldy #0
kbs0:
	lda (ptr),y
	beq kbs1
	jsr bsout
	iny
	bra kbs0
kbs1:
	lda #$22
	jsr bsout
	lda #':'
kbs2:
	cpy #$09 ; total length of variable data ($0B) minus one for the quote above, and one for the final null below
	bcs kbs3
	jsr bsout
	iny
	bra kbs2
kbs3:
	lda #0
	jsr bsout

	lda egg
	beq @noegg

	WRITE_RAW_BYTES altbasic_prog13, altbasic_end

	bra @afterbasic
@noegg:
	WRITE_RAW_BYTES basic_prog13, basic_end

@afterbasic:
	jsr clrch       ;return output to screen

	lda #$02
	jsr close       ;close file


	;now display message
	ldx #0
msg1:	lda saved_msg,x
	beq rtme
	jsr bsout
	inx
	jmp msg1
rtme:	jsr getin
	beq rtme
	jmp main_menu

saved_msg:
	.byte 147,"FILE SAVED,",13,"PRESS ANY KEY.",0
filename:
	.byte "@:AUTOBOOT.X16,S,W"
filename_len=*-filename

loadaddr=$0801

nextlin0 = loadaddr+(basic_prog1-basic_prog0)+$07
nextlin1 = nextlin0+(basic_prog2-basic_prog1)+$03
nextlin2 = nextlin1+(basic_prog3-basic_prog2)+$03
nextlin3 = nextlin2+(basic_prog4-basic_prog3)+$03
nextlin4 = nextlin3+(basic_prog5-basic_prog4)+$03
nextlin5 = nextlin4+(basic_prog6-basic_prog5)+$03
nextlin6 = nextlin5+(basic_prog7-basic_prog6)
nextlin7 = nextlin6+(basic_prog8-basic_prog7)+$03
nextlin8 = nextlin7+(basic_prog9-basic_prog8)+$03
nextlin9 = nextlin8+(basic_prog10-basic_prog9)+$03
nextlin10 = nextlin9+(basic_prog11-basic_prog10)+$03
nextlin11 = nextlin10+(basic_prog12-basic_prog11)
nextlin12 = nextlin11+(basic_prog13-basic_prog12)+$0B
nextlin13 = nextlin12+(basic_prog14-basic_prog13)

altnextlin13 = nextlin12+(altbasic_prog14-altbasic_prog13)
altnextlin14 = altnextlin13+(altbasic_prog15-altbasic_prog14)


basic_start:
	.word loadaddr         ;Program load address
basic_prog0:
	.word nextlin0
	.word $0000
	.byte $CE,$8D,'$'      ;0 COLOR$
basic_prog1:
	.word nextlin1
	.word $0001
	.byte $CE,$86,"$"      ;1 SCREEN$
basic_prog2:
	.word nextlin2
	.word $0002
	.byte $97,"$9F29,$"    ;2 POKE$9F29,$
basic_prog3:
	.word nextlin3
	.word $0003
	.byte $97,"$9F2A,$"    ;3 POKE$9F2A,$
basic_prog4:
	.word nextlin4
	.word $0004
	.byte $97,"$9F2B,$"    ;4 POKE$9F2B,$
basic_prog5:
	.word nextlin5
	.word $0005
	.byte $97,"$9F2C,$"    ;5 POKE$9F2C,$
basic_prog6:
	.word nextlin6
	.word $0006
	.byte $97,"$9F25,$02"  ;6 POKE$9F25,$02
	.byte $00
basic_prog7:
	.word nextlin7
	.word $0007
	.byte $97,"$9F29,$"    ;7 POKE$9F29,$
basic_prog8:
	.word nextlin8
	.word $0008
	.byte $97,"$9F2A,$"    ;8 POKE$9F2A,$
basic_prog9:
	.word nextlin9
	.word $0009
	.byte $97,"$9F2B,$"    ;9 POKE$9F2B,$
basic_prog10:
	.word nextlin10
	.word $000A
	.byte $97,"$9F2C,$"    ;10 POKE$9F2C,$
basic_prog11:
	.word nextlin11
	.word $000B
	.byte $97,"$9F25,$00"  ;11 POKE$9F25,$00
	.byte $00
basic_prog12:
	.word nextlin12
	.word $000C
	.byte $CE,$94,$22      ;12 KEYMAP"
basic_prog13:
	.word nextlin13
	.word $000D
	.byte $A2              ;13 NEW
	.byte $00
basic_prog14:
	.word $0000
basic_end:

altbasic_prog13:
	.word altnextlin13
	.word $000D            ;13 PRINT "...":BANK1,0:POKE$30C,4:SYS$FF62
	.byte $99,$22,$93,"**** CBM BASIC V2 ****"
	.byte $13,$11,$11,"3583 BYTES FREE",$22,':'
	.byte $CE,$98,"1,0:"
	.byte $97,"$30C,4:"
	.byte $9E,"$FF62"
	.byte $00
altbasic_prog14:
	.word altnextlin14
	.word $000E
	.byte $A2              ;14 NEW
	.byte $00
altbasic_prog15:
	.word $0000
altbasic_end:


.endproc

.proc convert_high_nybble: near
	lsr
	lsr
	lsr
	lsr
	tay
	lda hex_table,y	
	rts
.endproc

.proc convert_low_nybble: near
	and #%00001111
	tay
	lda hex_table,y	
	rts
.endproc

.proc apply_safemode: near
	sec
	jsr screen_mode

	cmp #7
	bcs @exit
	tax
	stz VERA_CTRL
	lda @hscale,x
	sta VERA_DC_HSCALE
	lda @vscale,x
	sta VERA_DC_VSCALE
	lda #2
	sta VERA_CTRL
	lda #$10
	sta VERA_DC_HSTART
	lda #$90
	sta VERA_DC_HSTOP
	lda @vstart,x
	sta VERA_DC_VSTART
	lda @vstop,x
	sta VERA_DC_VSTOP
	stz VERA_CTRL
	lda VERA_DC_VSCALE
	lda VERA_DC_VIDEO
	and #%11110111
	sta VERA_DC_VIDEO
@exit:
	rts

@hscale:
	.byte $a1,$a0,$51,$51,$51,$28,$29
@vscale:
	.byte $99,$4d,$99,$4d,$26,$4d,$27
@vstart:
	.byte $14,$14,$14,$14,$14,$14,$14
@vstop:
	.byte $dd,$dd,$dd,$dc,$dd,$dc,$d9

.endproc

.proc time_date_menu: near
	lda #0
	sta menu_l
	lda #8
	sta menu_h
	ldy #0
tdm1:	lda time_date_text,y
	beq tdm2
	jsr bsout
	iny
	jmp tdm1
tdm2:	stz menu_select
tdm3:	jsr td_update_display
	jsr highlight_menu_option
	jsr getin	;get keyboard input
	cmp #$91	;cursor up
	bne tdm5
	jsr menu_up
	bra tdm3
tdm5:	cmp #$11	;cursor down
	bne tdm6
	jsr menu_down
	bra tdm3
tdm6:	cmp #$9D        ;cursor left
	bne tdm7
	jsr td_left
	bra tdm3
tdm7:	cmp #$1D        ;cursor right
	bne tdm8
	jsr td_right
	bra tdm3
tdm8:	cmp #13	;return
	bne tdm9
	jmp td_execute
tdm9:	cmp #27 ;esc
	beq tde0
tdma:	wai
	bra tdm3

td_execute:
	lda menu_select
	cmp #8
	bne tde1
tde0:	jsr td_start_clock
	lda #3
	sta menu_select
	jmp main_menu
tde1:	cmp #7
	bne tdm3
	jsr td_start_clock
	bra tdm3

td_left:
	lda menu_select
	bne @1
	jmp dec_year
@1:	cmp #1
	bne @2
	jmp dec_month
@2:	cmp #2
	bne @3
	jmp dec_day
@3:	cmp #3
	bne @4
	jmp dec_wday
@4:	cmp #4
	bne @5
	jmp dec_hour
@5:	cmp #5
	bne @6
	jmp dec_min
@6:	cmp #6
	bne @7
	jmp dec_sec
@7:	rts


td_right:
	lda menu_select
	bne @1
	jmp inc_year
@1:	cmp #1
	bne @2
	jmp inc_month
@2:	cmp #2
	bne @3
	jmp inc_day
@3:	cmp #3
	bne @4
	jmp inc_wday
@4:	cmp #4
	bne @5
	jmp inc_hour
@5:	cmp #5
	bne @6
	jmp inc_min
@6:	cmp #6
	bne @7
	jmp inc_sec
@7:	rts

dec_year:
	ldx #rtc_address
	ldy #6
	jsr i2c_read_byte
	sed
	sec
	sbc #1
	cld
	jsr i2c_write_byte	
	rts

dec_month:
	ldx #rtc_address
	ldy #5
	jsr i2c_read_byte
	sed
	sec
	sbc #1
	bne @1
	lda #$12
@1:	cld
	jsr i2c_write_byte	
	rts

dec_day:
	ldx #rtc_address
	ldy #4
	jsr i2c_read_byte
	sed
	sec
	sbc #1
	bne @1
	lda #$31
@1:	cld
	jsr i2c_write_byte	
	rts

dec_wday:
	ldx #rtc_address
	ldy #3
	jsr i2c_read_byte
	and #$07
	dec
	bne @1
	lda #7
@1:	ora #$08
	jsr i2c_write_byte	
	rts


dec_hour:
	ldx #rtc_address
	ldy #2
	jsr i2c_read_byte
	and #$3f
	sed
	sec
	sbc #1
	bpl @1
	lda #$23
@1:	cld
	jsr i2c_write_byte	
	rts
	
dec_min:
	ldx #rtc_address
	ldy #1
	jsr i2c_read_byte
	and #$7f
	bra dec_common

dec_sec:
	ldx #rtc_address
	ldy #0
	jsr i2c_read_byte
	and #$7f

dec_common:
	sed
	sec
	sbc #1
	cmp #$60
	bcc @1
	lda #$59
@1:	cld
	jsr i2c_write_byte	
	rts



inc_year:
	ldx #rtc_address
	ldy #6
	jsr i2c_read_byte
	sed
	clc
	adc #1
	cld
	jsr i2c_write_byte	
	rts

inc_month:
	ldx #rtc_address
	ldy #5
	jsr i2c_read_byte
	sed
	clc
	adc #1
	cmp #$13
	bcc @1
	lda #$01
@1:	cld
	jsr i2c_write_byte	
	rts


inc_day:
	ldx #rtc_address
	ldy #4
	jsr i2c_read_byte
	sed
	clc
	adc #1
	cmp #$32
	bcc @1
	lda #$01
@1:	cld
	jsr i2c_write_byte	
	rts


inc_wday:
	ldx #rtc_address
	ldy #3
	jsr i2c_read_byte
	and #$07
	inc
	cmp #8
	bcc @1
	lda #1
@1:	ora #$08
	jsr i2c_write_byte	
	rts


inc_hour:
	ldx #rtc_address
	ldy #2
	jsr i2c_read_byte
	and #$3f
	sed
	clc
	adc #1
	cmp #$24
	bcc @1
	lda #$00
@1:	cld
	jsr i2c_write_byte	
	rts

inc_min:
	ldx #rtc_address
	ldy #1
	and #$7f
	jsr i2c_read_byte
	bra inc_common

inc_sec:
	ldx #rtc_address
	ldy #0
	jsr i2c_read_byte
	and #$7f

inc_common:
	sed
	clc
	adc #1
	cmp #$60
	bcc @1
	lda #$00
@1:	cld
	jsr i2c_write_byte	
	rts


td_start_clock:
	ldx #rtc_address
	ldy #0
	jsr i2c_read_byte
	ora #$80
	jsr i2c_write_byte
	rts

td_update_display:
	; position for seconds
	clc
	ldx #8
	ldy #10
	jsr veraplot

	; grab seconds
	ldx #rtc_address
	ldy #0
	jsr i2c_read_byte
	and #$7f

	jsr hexwrite

	; position for minutes
	clc
	ldx #7
	ldy #10
	jsr veraplot

	; grab minutes
	ldx #rtc_address
	ldy #1
	jsr i2c_read_byte
	and #$7f

	jsr hexwrite

	; position for hours
	clc
	ldx #6
	ldy #10
	jsr veraplot

	; grab hours
	ldx #rtc_address
	ldy #2
	jsr i2c_read_byte
	and #$7f
	cmp #$40
	bcc @24h
	; if clock is stored in 12h am/pm mode, force it to 24h here and write it back to the RTC
	and #$3f
	sed
	cmp #$12 ; 12 am -> 0
	beq @is12
	cmp #$32 ; 12 pm -> 0 + pm = 12
	beq @is12
	bra @not12
@is12:
	sec
	sbc #$12
@not12:
	cmp #$20
	bcc @nopm
	and #$1f
	clc
	adc #$12
@nopm:
	cld
	pha
	ldx #rtc_address
	ldy #2
	jsr i2c_write_byte
	pla
@24h:
	jsr hexwrite

	; position for weekday
	clc
	ldx #5
	ldy #10
	jsr veraplot

	stz counter1
	lda menu_select
	cmp #3
	bne @wd1
	lda #$80
	sta counter1
@wd1:
	; grab weekday
	ldx #rtc_address
	ldy #3
	jsr i2c_read_byte
	and #$07

	asl
	asl
	tay 
	lda wkdy-4,y
	ora counter1
	sta VERA_DATA0
	lda wkdy-3,y
	ora counter1
	sta VERA_DATA0
	lda wkdy-2,y
	ora counter1
	sta VERA_DATA0

	; position for day
	clc
	ldx #4
	ldy #10
	jsr veraplot

	; grab day
	ldx #rtc_address
	ldy #4
	jsr i2c_read_byte
	and #$3f

	jsr hexwrite

	; position for month
	clc
	ldx #3
	ldy #10
	jsr veraplot

	; grab month
	ldx #rtc_address
	ldy #5
	jsr i2c_read_byte
	and #$1f

	jsr hexwrite


	; position for year
	clc
	ldx #2
	ldy #10
	jsr veraplot

	; grab year
	ldx #rtc_address
	ldy #6
	jsr i2c_read_byte

	jsr hexwrite

	rts	

wkdy:
	scrcode "MON TUE WED THU FRI SAT SUN"
time_date_text:	
	.byte 147       ;clear screen
	.byte "SET TIME AND DATE",13
	.byte 163,163,163,163,163,163,163,163,163,163
	.byte 163,163,163,163,163,163,163,13
	.byte "    YEAR:",13
	.byte "   MONTH:",13
	.byte "     DAY:",13
	.byte " WEEKDAY:",13
	.byte "    HOUR:",13
	.byte "  MINUTE:",13
	.byte "  SECOND:",13
	.byte " START CLOCK",13
	.byte " EXIT",13,13
	.byte "ARROWS TO CHANGE",13,0
.endproc

.proc smpte_bars: near
	; preserve previous mode params on stack
	stz VERA_CTRL
	lda VERA_DC_VSCALE
	pha
	lda VERA_DC_HSCALE
	pha

	lda #1
	sta VERA_CTRL
	lda VERA_DC_VSTOP
	pha
	lda VERA_DC_VSTART
	pha
	lda VERA_DC_HSTOP
	pha
	lda VERA_DC_HSTART
	pha

	stz VERA_CTRL

	sec
	jsr screen_mode
	pha

	; set bitmap graphics
	lda #$80
	jsr screen_mode


	; preserve old palette on stack
	lda #$e0
	sta VERA_ADDR_L
	lda #$fb
	sta VERA_ADDR_M
	lda #$11
	sta VERA_ADDR_H

	ldx #10
:
	lda VERA_DATA0
	pha
	dex
	bne :-

	; set custom palette
	lda #$e0
	sta VERA_ADDR_L
	lda #$fb
	sta VERA_ADDR_M
	lda #$11
	sta VERA_ADDR_H
:
	lda custom_palette,x
	sta VERA_DATA0
	inx
	cpx #10
	bcc :-

	; draw the bars (x counts from 22 to 1 in loop)
	ldx #22
barloop:
	phx
	lda bars_l-1,x
	sta ptr
	lda bars_h-1,x
	sta ptr+1

	lda (ptr)
	tax
	ldy #0
	jsr GRAPH_set_colors

	; populate r0-r3 from (ptr),1 through (ptr),8
	ldy #8
:
	lda (ptr),y
	sta r0-1,y
	dey
	bne :-

	stz r4L
	stz r4H

	sec
	jsr GRAPH_draw_rect

	plx
	dex
	bne barloop

wait_for_key:
	jsr getin
	beq wait_for_key


	; restore everything

	; restore old palette from stack (auto-decrement DATA0)
	lda #$e9
	sta VERA_ADDR_L
	lda #$fb
	sta VERA_ADDR_M
	lda #$19
	sta VERA_ADDR_H

	ldx #10
:
	pla
	sta VERA_DATA0
	dex
	bne :-

	; restore previous screen mode
	clc
	pla
	jsr screen_mode


	; restore previous mode params from stack
	lda #1
	sta VERA_CTRL

	pla
	sta VERA_DC_HSTART
	pla
	sta VERA_DC_HSTOP
	pla
	sta VERA_DC_VSTART
	pla
	sta VERA_DC_VSTOP

	stz VERA_CTRL

	pla
	sta VERA_DC_HSCALE

	pla
	sta VERA_DC_VSCALE

	rts


bars_l:
	.lobytes white75
	.lobytes yellow75
	.lobytes cyan75
	.lobytes green75
	.lobytes magenta75
	.lobytes red75
	.lobytes blue75

	.lobytes blue75s
	.lobytes black000s1
	.lobytes magenta75s
	.lobytes black000s2
	.lobytes cyan75s
	.lobytes black000s3
	.lobytes white75s

	.lobytes minusi
	.lobytes white100
	.lobytes plusq
	.lobytes black000b1
	.lobytes black000b
	.lobytes black000b2
	.lobytes gray111b
	.lobytes black000b3
bars_h:
	.hibytes white75
	.hibytes yellow75
	.hibytes cyan75
	.hibytes green75
	.hibytes magenta75
	.hibytes red75
	.hibytes blue75

	.hibytes blue75s
	.hibytes black000s1
	.hibytes magenta75s
	.hibytes black000s2
	.hibytes cyan75s
	.hibytes black000s3
	.hibytes white75s

	.hibytes minusi
	.hibytes white100
	.hibytes plusq
	.hibytes black000b1
	.hibytes black000b
	.hibytes black000b2
	.hibytes gray111b
	.hibytes black000b3


white75:
	.byte $1c
	.word 0,0,45,160
yellow75:
	.byte $f0
	.word 45,0,46,160
cyan75:
	.byte $aa
	.word 91,0,45,160
green75:
	.byte $f1
	.word 136,0,46,160
magenta75:
	.byte $f2
	.word 182,0,46,160
red75:
	.byte $3a
	.word 228,0,46,160
blue75:
	.byte $f3
	.word 274,0,46,160

blue75s:
	.byte $f3
	.word 0,160,45,20
black000s1:
	.byte $00
	.word 45,160,46,20
magenta75s:
	.byte $f2
	.word 91,160,45,20
black000s2:
	.byte $00
	.word 136,160,46,20
cyan75s:
	.byte $aa
	.word 182,160,46,20
black000s3:
	.byte $00
	.word 228,160,46,20
white75s:
	.byte $1c
	.word 274,160,46,20

minusi:
	.byte $f4
	.word 0,180,57,60
white100:
	.byte $1f
	.word 57,180,57,60
plusq:
	.byte $df
	.word 114,180,57,60
black000b1:
	.byte $00
	.word 171,180,56,60
black000b:
	.byte $10
	.word 227,180,16,60
black000b2:
	.byte $00
	.word 243,180,15,60
gray111b:
	.byte $11
	.word 258,180,16,60
black000b3:
	.byte $00
	.word 274,180,46,60


custom_palette:
	.word $cc0,$0c0,$c0c,$00c,$024


.endproc

hex_table:
	.byte "0123456789ABCDEF"

hex_code_table:
	scrcode "0123456789ABCDEF"

;This table lists the PETSCII codes used
;to set different colors
color_table:
	.byte 144   ;BLACK
	.byte 5	    ;WHITE
	.byte 28    ;RED
	.byte 159   ;CYAN
	.byte 156   ;PURPLE
	.byte 30    ;GREEN
	.byte 31    ;BLUE
	.byte 158   ;YELLOW
	.byte 129   ;ORANGE
	.byte 149   ;BROWN
	.byte 150   ;L RED
	.byte 151   ;D GRAY
	.byte 152   ;M GRAY
	.byte 153   ;L GREEN
	.byte 154   ;L BLUE
	.byte 155   ;L GRAY


layouts:
	.word nochg
	.word abcx16
	.word enusint
	.word engb
	.word svse
	.word dede
	.word dadk
	.word itit
	.word plpl
	.word nbno
	.word huhu
	.word eses
	.word fifi
	.word ptbr
	.word cscz
	.word jajp
	.word frfr
	.word dech
	.word enusdvo
	.word etee
	.word frbe
	.word enca
	.word isis
	.word ptpt
	.word hrhr
	.word sksk
	.word slsi
	.word lvlv
	.word ltlt
layout_count = (*-layouts) >> 1
nochg:	.byte "DEFAULT",0
abcx16:	.byte "ABC/X16",0
enusint:
	.byte "EN-US/INT",0
engb:	.byte "EN-GB",0
svse:	.byte "SV-SE",0
dede:	.byte "DE-DE",0
dadk:	.byte "DA-DK",0
itit:	.byte "IT-IT",0
plpl:	.byte "PL-PL",0
nbno:	.byte "NB-NO",0
huhu:	.byte "HU-HU",0
eses:	.byte "ES-ES",0
fifi:	.byte "FI-FI",0
ptbr:	.byte "PT-BR",0
cscz:	.byte "CS-CZ",0
jajp:	.byte "JA-JP",0
frfr:	.byte "FR-FR",0
dech:	.byte "DE-CH",0
enusdvo:
	.byte "EN-US/DVO",0
etee:	.byte "ET-EE",0
frbe:	.byte "FR-BE",0
enca:	.byte "EN-CA",0
isis:	.byte "IS-IS",0
ptpt:	.byte "PT-PT",0
hrhr:	.byte "HR-HR",0
sksk:	.byte "SK-SK",0
slsi:	.byte "SL-SI",0
lvlv:	.byte "LV-LV",0
ltlt:	.byte "LT-LT",0
