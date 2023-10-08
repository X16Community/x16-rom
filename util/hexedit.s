;Hexedit (X16 version)
;by David Murray 2023
;dfwgreencars@gmail.com

.pc02

.include "io.inc"
.include "kernal.inc"
.include "regs.inc"
.include "banks.inc"

; for some reason these are commented out in kernal.inc
readst = $ffb7
setmsg = $ff90

.macpack cbm

.export util_hexedit

.segment "HEXEDITZP": zeropage
source_l:
	.res 1 ;for reading from a data source inderectly
source_h:
	.res 1 ;for reading from a data source inderectly
load_address_l:
	.res 1 ;for reading/writing to files
load_address_h:
	.res 1 ;for reading/writing to files
hexnum:
	.res 1 ;for writing a hexidecimal or BCD number to screen
temp:
	.res 1 ;	
data_source:
	.res 1 ;0=system 1=vram 2=i2c
line_render:
	.res 1 ;current line being rendered
column_render:
	.res 1 ;current column being rendered
address_render_l:
	.res 1 ;current address line being rendered
address_render_h:
	.res 1 ;current address line being rendered
screen_width:
	.res 1 ;width of text screen
screen_height:
	.res 1 ;height of text screen
text_color:
	.res 1 ;color of text.
hex_columns:
	.res 1 ;number of hex columns to display
file_size_l:
	.res 1 ;total size of file
files_size_h:
	.res 1 ;total size of file
display_mode:
	.res 1 ;0=scr 1=petscii 2=ascii
top_address_l:
	.res 1 ;what address to start displaying
top_address_h:
	.res 1 ;from at the top.
cursor_x:
	.res 1 ;cursor location
cursor_y:
	.res 1 ;cursor location
bank_sel:
	.res 1 ;used for selecting current bank
select_begin_l:
	.res 1 ;used for selecting chunks of data
select_begin_h:
	.res 1 ;
select_end_l:
	.res 1 ;
select_end_h:
	.res 1 ;
select_active:
	.res 1 ;bits 0 and 1 for start and end %11=go
eof_l:
	.res 1 ;for storing the length of a file
eof_h:
	.res 1 ;being edited in "file mode."
filename_length:
	.res 1 ;length of file name
drive_number:
	.res 1 ;current drive number
highlight:
	.res 1; 0=no highlight 1=highlight
cursor_temp:
	.res 1 ;stores cursor color
after_off:
	.res 1 ;flags highlight to be off after next byte
ula:
	.res 1 ;use load address 0=no 1=yes
max_l:
	.res 1 ;the max top address for a screen size
max_h:
	.res 1 ;the max top address for a screen size
temp_l:
	.res 1 ;
temp_h:
	.res 1 ;

.segment "HEXEDITBSS"
buffer:
	.res 32 ;32 byte buffer for various things
filename:
	.res 16 ;0220-022F / Filename (16 Chars max)

.segment "HEXEDIT"

util_hexedit:
	; turn off kernal save/load messages
	lda #0
	jsr setmsg
	stz top_address_l
	stz top_address_h
	stz cursor_x
	stz cursor_y
	stz display_mode
	stz data_source
	stz select_active
	lda #08
	sta drive_number
	jsr screen        ;get current screen dimensions
	stx screen_width  ;get current screen dimensions
	sty screen_height ;get current screen dimensions
	;Verify screen mode
	cpx #32   ;32 columns minimum required
	bcs scok1	
	jsr display_screen_error
	rts
scok1:	jsr set_hex_columns
	lda #02	               ;Uppercase/gfx
	jsr screen_set_charset ;make sure we're in uppercase/gfx
	jsr modify_charset
	lda #$42  ;set uppercase
	jsr bsout
	lda #08   ;disable charset switching
	jsr bsout
	jsr calc_top_from_bottom
	jmp help_screen
scok2:	jsr clear_screen
	jsr display_status_line
	jsr display_screen_top
	jsr render_entire_area
	jsr display_screen_bottom
	jsr draw_cursor
user_input:
	jsr getin
	cmp #0
	beq user_input
	;check if it is 0-9
	cmp #48 ;0
	bcc usin0
	cmp #58 ;9+1
	bcs usin4
	jmp key0_9
usin4:	;check if it is A-F
	cmp #'A'
	bcc usin0
	cmp #'F'+1
	bcs usin0
	jmp keya_f
usin0:	ldx #0
usin1:	cmp key_table,x
	beq user_key_found
	inx
	cpx #23 ;number of keys in table.
	bne usin1	
	jmp user_input ;key not recognized
user_key_found:	
	txa
	asl
	tax
	jmp (user_jump_table,x)

key_table:
	.byte $85 ;F1
	.byte $89 ;F2
	.byte $86 ;F3
	.byte $48 ;H
	.byte $91 ;Cursor Up
	.byte $11 ;Cursor Down
	.byte $9D ;Cursor Left
	.byte $1D ;Cursor Right
	.byte $1B ;Escape
	.byte $13 ;Home
	.byte $04 ;End
	.byte $82 ;Page up
	.byte $02 ;Page down
	.byte $D3 ;Shift-S
	.byte $CC ;Shift-L
	.byte $C2 ;Shift-B
	.byte $C5 ;Shift-E
	.byte $C3 ;Shift-C
	.byte $C4 ;Shift-D
	.byte $47 ;G
	.byte $0D ;return
	.byte $DA ;Shift-Z
	.byte $93 ;shift+home (clear)

user_jump_table:
	.word switch_data_source
	.word switch_bank
	.word switch_display_mode
	.word help_screen
	.word cursor_up
	.word cursor_down
	.word cursor_left
	.word cursor_right
	.word exit_program
	.word home
	.word end
	.word page_up
	.word page_down
	.word save_file
	.word load_file
	.word mark_begin
	.word mark_end
	.word mark_clear
	.word change_drive_number
	.word goto_address
	.word return
	.word zero_selection
	.word zero_file_area

zero_file_area:
	;verify we are in file mode
	lda data_source
	cmp #2
	beq zfa1
	jmp  user_input
zfa1:	;setup selection
	stz select_begin_l
	stz select_begin_h
	lda #$ff
	sta select_end_l
	sta select_end_h
	;clear the area
	jmp zero_file_ram	

zero_selection:
	;First see if a selection is active
	lda select_active
	cmp #%00000011
	beq zese0
	jmp user_input
zese0:	lda data_source
	cmp #0  ;system RAM
	bne zese1
	jmp zero_system_ram
zese1:	cmp #1  ;V-RAM
	bne zese2
	jmp zero_vram
zese2:	cmp #2  ;file RAM
	bne zese3
	jmp zero_file_ram
zese3:	;add more stuff for other RAM types later.
	jmp  user_input

zero_file_ram:
	;setup initial values
	lda select_begin_l
	sta source_l
	sta temp_l
	lda select_begin_h
	sta source_h
	and #%00011111
	clc	
	adc #$a0
	sta temp_h
	lda select_begin_h
	lsr
	lsr
	lsr
	lsr
	lsr
	inc
	sta ram_bank
	ldy #0
	;zero the byte out
zfr1:	lda #0
	sta (temp_l),y	
	;Check if we've finished
	lda source_h
	cmp select_end_h
	bne zfr3
	lda source_l
	cmp select_end_l
	beq zfr9 ;finished
zfr3:	;Advance source_l/h
	inc source_l
	bne zfr4
	inc source_h
zfr4:	;Advance temp
	inc temp_l
	bne zfr1
	inc temp_h
	lda temp_h
	cmp #$c0
	bne zfr1
	lda #$a0
	sta temp_h
	inc ram_bank
	jmp zfr1
zfr9:	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

zero_system_ram:
	lda select_begin_l
	sta source_l
	lda select_begin_h
	sta source_h
	ldy #0
zsr1:	lda #0
	sta (source_l),y
	;Check if we've reached the end
	lda source_h
	cmp select_end_h
	bne zsr3	
	lda source_l
	cmp select_end_l
	bne zsr3
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input
zsr3:	;advance to next memory location
	inc source_l
	bne zsr1
	inc source_h
	jmp zsr1

zero_vram:
	lda #%00010000
	clc	
	adc bank_sel
	sta VERA_ADDR_H
	lda select_begin_h
	sta VERA_ADDR_M
	lda select_begin_l
	sta VERA_ADDR_L
zevr1:	stz VERA_DATA0
	;check if we've reached the end.
	lda VERA_ADDR_M
	cmp select_end_h
	bne zevr1
	lda VERA_ADDR_L
	cmp select_end_l
	bne zevr1
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

mark_begin:
	jsr calc_current_address
	jsr calc_the_rest
	;check if end is already set
	lda select_active
	and #%00000010
	cmp #%00000010
	bne mkbg9
	;check if end is before the beginning
	lda source_h
	cmp select_end_h
	beq mkbg1
	bcc mkbg9
	jmp user_input ;abort
mkbg1:	lda source_l
	cmp select_end_l
	bcc mkbg9
	jmp user_input ;abort
mkbg9:	;all is good, set beginning
	lda source_l
	sta select_begin_l
	lda source_h
	sta select_begin_h
	lda select_active
	ora #%00000001
	sta select_active
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

mark_end:
	jsr calc_current_address
	jsr calc_the_rest
	;check if begin is already set
	lda select_active
	and #%00000001
	cmp #%00000001
	bne mken9
;check if end is before the beginning
	lda select_begin_h
	cmp source_h
	beq mken1
	bcc mken9
	jmp user_input	;abort
mken1:	lda select_begin_l
	cmp source_l
	bcc mken9
	jmp user_input	;abort
mken9:	;all is good, set end
	lda source_l
	sta select_end_l
	lda source_h
	sta select_end_h
	lda select_active
	ora #%00000010
	sta select_active
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

mark_clear:
	stz select_active
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

return:
	jsr erase_cursor
	stz cursor_x
	jmp cursor_down

key0_9:	
	sec
	sbc #48
	sta temp
	jmp enter_data

keya_f:
	sec
	sbc #55
	sta temp
	jmp enter_data

enter_data:
	jsr calc_current_address
	lda source_l
	sta address_render_l
	lda source_h
	sta address_render_h
	;figure out which type of RAM to write
	lda data_source
	cmp #0
	bne enda1
	jsr enter_system_ram
	jmp enda5
enda1:	cmp #1
	bne enda2
	jsr enter_video_ram
	jmp enda5
enda2:	cmp #2
	bne enda3
	jsr enter_file_ram
	jmp enda5
enda3:	;add stuff here for other data sources
enda5:	;Now redraw line
	lda cursor_y
	sta line_render
	jsr get_source_data
	jsr render_single_line
	lda hex_columns
	asl
	dec
	cmp cursor_x
	bne enda6
	jsr draw_cursor
	jmp return
enda6:	jmp cursor_right

enter_file_ram:
	jsr calc_the_rest
	lda source_h
	sta hexnum
	and #%00011111
	clc
	adc #$a0
	sta source_h
	lda hexnum
	lsr
	lsr
	lsr
	lsr
	lsr
	inc
	sta ram_bank
	ldy #0
	;Is it left or right nybble?
	lda cursor_x
	and #%00000001
	cmp #%00000001
	beq efr3
	;do left nybble
	asl temp
	asl temp
	asl temp
	asl temp
	lda (source_l),y
	and #%00001111
	ora temp
	sta (source_l),y	
	rts
efr3:	;do right nybble
	lda (source_l),y
	and #%11110000
	ora temp	
	sta (source_l),y
	rts

enter_system_ram:
	;Is it left or right nybble?
	lda cursor_x
	and #%00000001
	cmp #%00000001
	beq cca3
	;do left nybble
	asl temp
	asl temp
	asl temp
	asl temp
	lda (source_l),y
	and #%00001111
	ora temp
	sta (source_l),y	
	rts
cca3:	;do right nybble
	lda (source_l),y
	and #%11110000
	ora temp	
	sta (source_l),y
	rts

enter_video_ram:
	;set vera registers
	lda bank_sel
	sta VERA_ADDR_H
	lda source_h
	sta VERA_ADDR_M
	lda cursor_x
	lsr
	clc	
	adc source_l
	sta VERA_ADDR_L
	;Is it left or right nybble?
	lda cursor_x
	and #%00000001
	cmp #%00000001
	beq eva3
	;do left nybble
	asl temp
	asl temp
	asl temp
	asl temp
	lda VERA_DATA0
	and #%00001111
	ora temp
	sta VERA_DATA0	
	rts
eva3:	;do right nybble
	lda VERA_DATA0
	and #%11110000
	ora temp	
	sta VERA_DATA0
	rts
;This routine will put the left-hand screen value
;in source_l/source_h.
calc_current_address:
	;Find address of current line
	lda cursor_y
	sta source_l  ;multiply the 16 bit
	stz source_h  ;value by 8.
	asl source_l
	rol source_h
	asl source_l
	rol source_h
	asl source_l
	rol source_h	
	lda hex_columns
	cmp #8
	beq cca1
	asl source_l  ;one more shift to make it
	rol source_h  ;multiply by 16
cca1:	;add it to top line address
	lda top_address_l
	clc
	adc source_l
	sta source_l
	lda top_address_h
	adc source_h
	sta source_h
	;find horizontal address
	lda cursor_x
	lsr
	tay
	rts

;This supplments the above routine by adding
;in the horizontal position as well.
calc_the_rest:
	lda cursor_x
	lsr
	clc
	adc source_l
	sta source_l
	lda source_h
	adc #0
	sta source_h
	rts

switch_bank:
	lda data_source
	cmp #0 ;system RAM
	bne swb1
	jmp goto_system_bank
swb1:	;toggle VRAM bank
	lda bank_sel
	eor #%00000001
	sta bank_sel	
swb9:	;clean up screen after bank switch
	stz select_active
	jsr display_status_line
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

switch_data_source:
	stz bank_sel
	sta ram_bank
	inc data_source
	lda data_source
	cmp #3; only do 3 types 
	bne sds1
	stz data_source
sds1:	;clean up screen after data switch
	stz cursor_x
	stz cursor_y
	stz top_address_l
	stz top_address_h
	stz select_active
	jsr display_status_line
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

home:
	jsr erase_cursor
	stz cursor_x
	stz cursor_y
	jsr draw_cursor
	jmp user_input

end:	
	jsr erase_cursor
	lda screen_height
	sec
	sbc #5
	sta cursor_y
	jsr draw_cursor
	jmp user_input

page_up:
	jsr calc_full_chart
	lda top_address_l
	sec
	sbc source_l
	sta top_address_l
	lda top_address_h
	sbc source_h
	sta top_address_h
	bcs pu01  ;make sure we didn't wrap
	stz top_address_l
	stz top_address_h
pu01:	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

page_down:	
	jsr calc_full_chart
	lda top_address_l
	clc
	adc source_l
	sta top_address_l
	lda top_address_h
	adc source_h
	sta top_address_h
	bcc pd01  ;make sure we didn't wrap
	lda max_l
	sta top_address_l
	lda max_h
	sta top_address_h	
pd01:	jsr validate_max
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

;This chart basically calculates the number of
;hex digits in a given screen, for use in
;page up/page down.
calc_full_chart:
	lda screen_height
	sec
	sbc #4
	sta source_l  ;multiply the 16 bit
	stz source_h  ;value by 8.
	asl source_l
	rol source_h
	asl source_l
	rol source_h
	asl source_l
	rol source_h	
	lda hex_columns
	cmp #8
	beq calfu
	asl source_l  ;one more shift to make it
	rol source_h  ;multiply by 16
calfu:	rts
draw_cursor:
	jsr find_cursor
	lda #$10      ;black on white
	sta VERA_DATA0
	jsr display_current_address
	rts

erase_cursor:
	jsr calc_current_address
	jsr calc_the_rest
	lda select_active
	cmp #%00000011
	beq ercu2
nthl:	jsr find_cursor
	lda #$6f      ; not highlighted
	sta VERA_DATA0
	rts
ercu2:	;Selection is active, highlight or not?
	lda source_h
	cmp select_begin_h  ;Equal to begin
	bne ercu3	
	lda source_l
	cmp select_begin_l
	beq drhl
ercu3:	lda source_h
	cmp select_end_h    ;Equal to end
	bne ercu4	
	lda source_l
	cmp select_end_l
	beq drhl
ercu4:	lda select_begin_h
	cmp source_h
	beq ercu5
	bcc ercu6
	bcs nthl
ercu5:	lda select_begin_l
	cmp source_l
	bcs nthl
	;check ending
ercu6:	lda select_end_h
	cmp source_h
	beq ercu7
	bcc nthl
	bcs drhl
ercu7:	lda select_end_l
	cmp source_l
	bcc nthl
drhl:	jsr find_cursor
	lda #$f6  ; highlighted
	sta VERA_DATA0
	rts

find_cursor:
	lda #%00010001
	sta VERA_ADDR_H
	lda #$b2
	clc
	adc cursor_y
	sta VERA_ADDR_M
	lda cursor_x
	asl
	clc
	adc #15
	sta VERA_ADDR_L
	rts

cursor_up:
	lda cursor_y
	cmp #0
	bne cru1
	jmp scroll_up_one
cru1:	jsr erase_cursor
	dec cursor_y
	jsr draw_cursor
	jmp user_input

cursor_down:
	lda screen_height
	sec
	sbc #5
	cmp cursor_y
	bne crd1
	jmp scroll_down_one
crd1:	jsr erase_cursor
	inc cursor_y
	jsr draw_cursor
	jmp user_input

cursor_left:
	lda cursor_x
	cmp #0
	beq crl1
	jsr erase_cursor
	dec cursor_x
	jsr draw_cursor
	jmp user_input
crl1:	jsr calc_current_address
	lda source_h
	ora source_l
	beq crl2
	jsr erase_cursor
	lda hex_columns
	asl
	dec
	sta cursor_x
	jsr draw_cursor
	jmp cursor_up
crl2:	jmp user_input

cursor_right:
	lda hex_columns
	asl
	dec
	cmp cursor_x
	beq crr1
	jsr erase_cursor
	inc cursor_x
	jsr draw_cursor
	jmp user_input
crr1:	
	jsr erase_cursor
	stz cursor_x
	jsr draw_cursor
	jmp cursor_down

scroll_down_one:
	lda top_address_l	
	clc
	adc hex_columns
	sta top_address_l
	lda top_address_h
	adc #0
	sta top_address_h
	bcc sdo1   ;make sure we didn't wrap
	lda max_l
	sta top_address_l
	lda max_h
	sta top_address_h
sdo1:	jsr validate_max
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

scroll_up_one:
	lda top_address_l	
	sec
	sbc hex_columns
	sta top_address_l
	lda top_address_h
	sbc #0
	sta top_address_h
	;check that we didn't loop beyond $0000
	bcs suo1
	stz top_address_h
	stz top_address_l
suo1:	jsr render_entire_area
	jsr draw_cursor
	jmp user_input

validate_max:
	lda top_address_h
	cmp max_h
	beq vdo1
	bcc vdo3
	jmp vd02
vdo1:	lda top_address_l
	cmp max_l
	beq vd02
	bcc vdo3
vd02:	lda max_l
	sta top_address_l
	lda max_h
	sta top_address_h
vdo3:	rts

;This routine figures out what the top address
;should be for any given screen size, if the 
;user has hit bottom, so it doesn't go past $FFFF
calc_top_from_bottom:
	lda screen_height
	sec
	sbc #04
	sta source_l	;get number of rows
	stz source_h
	asl source_l	;multiply by 8
	rol source_h	
	asl source_l
	rol source_h
	asl source_l
	rol source_h
	lda hex_columns
	cmp #16		;mult by 2 for larger width
	bne ctfb1
	asl source_l
	rol source_h
ctfb1:	;now subtract this amount from $1,000
	lda #$00
	sec
	sbc source_l
	sta max_l
	lda #$00
	sbc source_h
	sta max_h
	rts

exit_program:
	jsr erase_cursor
	;display message for Y/N
	lda #<txt_exit_message
	sta source_l
	lda #>txt_exit_message
	sta source_h
	jsr display_message
	;beep
	lda #7
	jsr bsout
	;wait for user response
expr3:	jsr getin
	cmp #78 ;N
	bne expr4
	jsr display_status_line
	jsr draw_cursor
	jmp user_input
expr4:	cmp #89 ;Y
	bne expr3
	;Go ahead and exit now.
	lda #02
	jsr screen_set_charset  ;first set the font back to normal.
	jsr clear_screen
	lda #09	;enable charset switching
	jsr bsout
	lda #19	;home
	jsr bsout
	; turn kernal saving/loading messages back on
	lda #$80
	jsr setmsg
	rts
	
switch_display_mode:
	lda display_mode
	cmp #2
	beq sdm2
	inc display_mode
sdm1:	jsr display_screen_top
	jsr render_entire_area
	jsr draw_cursor
	jmp user_input	
sdm2:	stz display_mode
	bra sdm1

render_entire_area:
	stz after_off
	jsr set_initial_color
	stz line_render
	lda top_address_h
	sta address_render_h
	lda top_address_l
	sta address_render_l
rea1:	jsr get_source_data
	jsr render_single_line
	inc line_render
	lda screen_height
	sec
	sbc #4
	cmp line_render
	beq rea2
	jsr inc_address_render
	jmp rea1	
rea2:	rts

get_source_data:
	lda data_source
	cmp #0	;system RAM
	bne gds2
	jsr get_system_ram
	rts
gds2:	cmp #1	;VRAM
	bne gds3
	jsr get_vram
	rts
gds3:	jsr get_file_ram
	rts

get_file_ram:
	;setup initial ram location
	lda address_render_l
	sta source_l
	lda address_render_h
	and #%00011111
	clc
	adc #$a0
	sta source_h
	lda address_render_h
	lsr
	lsr
	lsr
	lsr
	lsr
	inc
	sta ram_bank
	;Start copying data
	ldy #0
	ldx #0
gfr1:	lda (source_l),y
	sta buffer,x
	inx
	cpx #hex_columns
	bne gfr2
	jmp gfr4
gfr2:	inc source_l
	bne gfr3
	inc source_h
	lda source_h
	cmp #%01000000
	bne gfr3
	inc ram_bank
gfr3:	jmp gfr1
gfr4:	rts

get_system_ram:
	ldy #0
gsr1:	lda (address_render_l),y
	sta buffer,y
	iny
	cpy hex_columns
	bne gsr1
	rts

get_vram:
	lda #%00010000
	clc
	adc bank_sel
	sta VERA_ADDR_H
	lda address_render_h
	sta VERA_ADDR_M
	lda address_render_l
	sta VERA_ADDR_L
	ldy #0
gvr1:	lda VERA_DATA0
	sta buffer,y
	iny
	cpy hex_columns
	bne gvr1
	rts
	
inc_address_render:
	lda address_render_l
	clc
	adc hex_columns
	sta address_render_l
	lda address_render_h
	adc #0
	sta address_render_h
	rts

;Note about rendering.  Since the charset
;is modified, we only show characters 0-127.  Any
;reversed characters are simulated by reversing the
;screen color attributes.

render_single_line:
	;Set starting point in VRAM
	lda #%00010001
	sta VERA_ADDR_H
	lda #$b2
	clc
	adc line_render
	sta VERA_ADDR_M
	lda #$04
	sta VERA_ADDR_L
	;render offset.
	lda #$67
	sta text_color
	lda address_render_h
	sta hexnum
	jsr display_hexnum
	lda address_render_l
	sta hexnum
	jsr display_hexnum
	;display divider
	lda #93
	sta VERA_DATA0
	lda #$61  ;white on blue
	sta VERA_DATA0
	;display actual data
rsl0:	stz column_render
rsl1:	ldy column_render
	lda buffer,y
	sta hexnum
	jsr set_text_color
	jsr display_thin_hexnum
	lda after_off
	cmp #1
	bne rsl1b
	lda #$6f   ;highlight off
	sta highlight
rsl1b:	inc column_render
	lda column_render
	cmp hex_columns
	bne rsl1
	;display divider
	lda #93
	sta VERA_DATA0
	lda #$61	;white on blue
	sta VERA_DATA0
	;display text representation
	lda display_mode
	cmp #0   ;screen codes
	beq display_screen_codes
	jmp rsl5
	;display screen codes
display_screen_codes:	
	stz column_render
	ldx #$6f ;gray on blue
rsl2:	ldy column_render
	lda buffer,y
	and #%10000000
	cmp #%10000000
	bne rsl3
	lda buffer,y	
	and #%01111111
	sta VERA_DATA0
	lda #$f6  ;blue on gray (reverse)
	sta VERA_DATA0
	bra rsl4
rsl3:	lda buffer,y
	sta VERA_DATA0
	stx VERA_DATA0
rsl4:	inc column_render
	lda column_render
	cmp hex_columns
	bne rsl2	
	rts
rsl5:	cmp #1    ;PETSCII
	beq display_petscii
	jmp display_ascii
display_petscii:
	stz column_render
	ldx #$6f  ;Gray on blue
dspet1:	ldy column_render
	lda buffer,y
	jsr convert_petscii_to_screen_code
	sta VERA_DATA0
	stx VERA_DATA0
	inc column_render
	lda column_render
	cmp hex_columns
	bne dspet1
	rts
display_ascii:
	stz column_render
	ldx #$6f ;Gray on blue
dsasc1:	ldy column_render
	lda buffer,y
	cmp #$20         ; if A<$20 then...
	bcc sub_p
	cmp #$3f         ; if A<$3F then
	bcc nochange
	cmp #$95         ; if A<$95 then
	bcc sasc1
	bra sub_p
sasc1:	and #%00011111
	jmp nochange
sub_p:	lda #$2e         ; Substitute period
nochange:
	sta VERA_DATA0
	stx VERA_DATA0
	inc column_render
	lda column_render
	cmp hex_columns
	bne dsasc1
	rts

set_initial_color:
	lda select_active
	cmp #%00000011
	beq sic1
sic0:	lda #$6f       ;no highlight
	sta highlight
	rts
sic1:	;check if starting address falls
	;within selection table   SB>TA<SE
	;check beginning
	lda select_begin_h
	cmp top_address_h
	beq sic2
	bcc sic3
	bcs sic0
sic2:	lda select_begin_l
	cmp top_address_l
	bcs sic0
	;check ending
sic3:	lda select_end_h
	cmp top_address_h
	beq sic4
	bcc sic0
	bcs sic9
sic4:	lda select_end_l
	cmp top_address_l
	bcc sic0
sic9:	;Do highlight
	lda #$f6	
	sta highlight
	rts	

set_text_color:
	lda select_active
	cmp #%00000011
	beq stc0
	lda #$6f
	sta text_color
	rts
stc0:	;Check if we've reached begin/end mark
	;calculate actual address into source_l/h
	lda address_render_l
	clc
	adc column_render
	sta source_l
	lda address_render_h
	adc #0
	sta source_h
	;now compare
	lda source_l
	cmp select_begin_l
	beq stc1
	cmp select_end_l
	bne stc8
	lda source_h
	cmp select_end_h
	bne stc8
	;select end found
	;lda #$6f       ;highlight off
	;sta highlight
	lda #1
	sta after_off
	bra stc8	
stc1:	lda source_h
	cmp select_begin_h
	bne stc8
	;Select begin found
	lda #$f6        ;highlight off
	sta highlight
	stz after_off
	;jmp stc8		
stc8:	;Set color
	lda highlight
	sta text_color
	rts

convert_petscii_to_screen_code:
	cmp #$20        ; // if A<32 then...
	bcc ddRev
	cmp #$60        ; // if A<96 then...
	bcc dd1
	cmp #$80        ; // if A<128 then...
	bcc dd2
	cmp #$a0        ; // if A<160 then...
	bcc dd3
	cmp #$c0        ; // if A<192 then...
	bcc dd4
	cmp #$ff        ; // if A<255 then...
	bcc ddRev
	lda #$7e        ; // A=255, then A=126
	bne ddEnd
dd2:	and #$5f        ; // if A=96..127 then strip bits 5 and 7
	bne ddEnd
dd3:	ora #$40        ; // if A=128..159, then set bit 6
	bne ddEnd
dd4:	eor #$c0        ; // if A=160..191 then flip bits 6 and 7
	bne ddEnd
dd1:	and #$3f        ; // if A=32..95 then strip bits 6 and 7
	bpl ddEnd       ; // <- you could also do .byte $0c here
ddRev:	eor #$80        ; // flip bit 7 (reverse on when off and vice versa)
ddEnd:	RTS

;20 COLUMNS = NOT ALLOWED
;32 COLUMNS = 8 HEX COLUMNS
;40 COLUMNS = 8 HEX COLUMNS
;64 COLUMNS = 16 HEX COLUMNS
;80 COLUMNS = 16 HEX COLUMNS

set_hex_columns:
	lda screen_width
	cmp #64
	bcs shc2
	lda #8
	sta hex_columns
	rts
shc2:	lda #16
	sta hex_columns
	rts
	
display_screen_error:
	ldx #0
dse1:	lda screen_error_text,x
	cmp #0
	beq dse2
	jsr bsout
	inx
	jmp dse1
dse2:	rts
	
screen_error_text:
	.byte $93,"HEXEDIT REQUIRES AT LEAST 32 COLUMNS!",0

display_screen_top:
	lda #%00010001
	lda #$b0
	sta VERA_ADDR_M
	lda #$00
	sta VERA_ADDR_L
	;display offset text
	ldx #0
dst1:	lda txt_offset,x
	sta VERA_DATA0
	lda #$67   ;yellow on blue
	sta VERA_DATA0
	inx
	cpx #6
	bne dst1
	;display divider
	lda #93
	sta VERA_DATA0
	lda #$61   ;white on blue
	sta VERA_DATA0
	;display column counters
	stz hexnum
	lda #$67   ;yellow on blue
	sta text_color
dst2:	jsr display_thin_hexnum
	inc hexnum
	lda hexnum
	cmp hex_columns	
	bne dst2
	;display divider
	lda #93
	sta VERA_DATA0
	lda #$61    ;white on blue
	sta VERA_DATA0
	;add space for wider screens
	lda hex_columns
	cmp #8
	beq dst3a
	ldx #4
	lda #32
	ldy #$67
dst2a:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dst2a
dst3a:	;display display_mode text
	ldx display_mode
	lda txt_display_sa,x
	tax
dst3:	lda txt_display_mode,x
	cmp #0
	beq dst4a
	sta VERA_DATA0
	lda #$67    ;yellow on blue
	sta VERA_DATA0
	inx
	jmp dst3
	;start at next screen row and draw divider line
dst4a:	lda #%00010001
	lda #$b1
	sta VERA_ADDR_M
	lda #$00
	sta VERA_ADDR_L	
	lda #67
	ldy #$61	;white on blue
	ldx #6
dst4:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dst4
	lda #91
	sta VERA_DATA0
	sty VERA_DATA0
	lda hex_columns
	asl
	tax
	lda #67
dst5:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dst5
	lda #91
	sta VERA_DATA0
	sty VERA_DATA0
	ldx hex_columns
	lda #67
dst6:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dst6
	rts

txt_offset:
	scrcode "OFFSET"
txt_display_mode:
	scrcode "SCR CODE"
	.byte 0
	scrcode " PETSCII"
	.byte 0
	scrcode "  ASCII "
	.byte 0
txt_display_sa:
	.byte 0,9,18

display_screen_bottom:
	lda #%00010001
	lda #$ae
	clc
	adc screen_height
	sta VERA_ADDR_M
	lda #$00
	sta VERA_ADDR_L	
	lda #67
	ldy #$61   ;white on blue
	ldx #6
dsb4:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dsb4
	lda #113
	sta VERA_DATA0
	sty VERA_DATA0
	lda hex_columns
	asl
	tax
	lda #67
dsb5:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dsb5
	lda #113
	sta VERA_DATA0
	sty VERA_DATA0
	ldx hex_columns
	lda #67
dsb6:	sta VERA_DATA0
	sty VERA_DATA0
	dex
	bne dsb6
	rts

display_thin_hexnum:
	ldy text_color
	lda hexnum
	lsr
	lsr
	lsr
	lsr
	ora #$a0
	sta VERA_DATA0
	sty VERA_DATA0
	lda hexnum
	and #%00001111
	ora #$b0	
	sta VERA_DATA0
	sty VERA_DATA0
	rts

display_hexnum:
	ldy text_color
	lda hexnum
	lsr
	lsr
	lsr
	lsr
	tax
	lda hexchart,x
	sta VERA_DATA0
	sty VERA_DATA0
	lda hexnum
	and #%00001111
	tax
	lda hexchart,x
	sta VERA_DATA0
	sty VERA_DATA0
	rts

hexchart:
	scrcode "0123456789ABCDEF"

clear_screen:
	ldy #0
	lda #%00010001
	sta VERA_ADDR_H
csc0:	tya	
	clc
	adc #$b0
	sta VERA_ADDR_M
	ldx #0
	lda #0
	sta VERA_ADDR_L
csc1:	lda #32    ;SPACE
	sta VERA_DATA0
	lda #$61   ;WHITE ON BLUE
	sta VERA_DATA0
	inx
	cpx screen_width
	bne csc1
	iny
	cpy screen_height
	bne csc0
	rts

;This routine only replaces 32 characters of the charset.

modify_charset:
	lda #%00010001
	sta VERA_ADDR_H
	lda #$f5
	sta VERA_ADDR_M
	lda #$00
	sta VERA_ADDR_L
	ldy #0
cp1:	lda charset,y
	sta VERA_DATA0
	iny
	cpy #$00
	bne cp1
	rts

;Custom character set for A0-AF is right justified
;and B0-BF is left justified.  
charset:
	.byte $1C,$36,$36,$36,$36,$36,$1C,$00; #160 $A0
	.byte $0C,$1C,$0C,$0C,$0C,$0C,$1E,$00; #161 $A1
	.byte $1C,$36,$06,$0C,$18,$30,$3E,$00; #162 $A2
	.byte $1C,$36,$06,$1C,$06,$36,$1C,$00; #163 $A3
	.byte $06,$0E,$1E,$36,$3F,$06,$06,$00; #164 $A4
	.byte $3E,$30,$3C,$06,$06,$36,$1C,$00; #165 $A5
	.byte $1C,$36,$30,$3C,$36,$36,$1C,$00; #166 $A6
	.byte $3E,$06,$0C,$18,$18,$18,$18,$00; #167 $A7
	.byte $1C,$36,$36,$1C,$36,$36,$1C,$00; #168 $A8
	.byte $1C,$36,$36,$1E,$06,$36,$1C,$00; #169 $A9
	.byte $1C,$36,$36,$3E,$36,$36,$36,$00; #170 $AA
	.byte $3C,$36,$36,$3C,$36,$36,$3C,$00; #171 $AB
	.byte $1C,$36,$30,$30,$30,$36,$1C,$00; #172 $AC
	.byte $3C,$36,$36,$36,$36,$36,$3C,$00; #173 $AD
	.byte $3E,$30,$30,$3C,$30,$30,$3E,$00; #174 $AE
	.byte $3E,$30,$30,$3C,$30,$30,$30,$00; #175 $AF
	.byte $70,$D8,$D8,$D8,$D8,$D8,$70,$00; #176 $B0
	.byte $60,$E0,$60,$60,$60,$60,$F0,$00; #177 $B1
	.byte $70,$D8,$18,$30,$60,$C0,$F8,$00; #178 $B2
	.byte $70,$D8,$18,$70,$18,$D8,$70,$00; #179 $B3
	.byte $18,$38,$78,$D8,$FC,$18,$18,$00; #180 $B4
	.byte $F8,$C0,$F0,$18,$18,$D8,$70,$00; #181 $B5
	.byte $70,$D8,$C0,$F0,$D8,$D8,$70,$00; #182 $B6
	.byte $F8,$18,$30,$60,$60,$60,$60,$00; #183 $B7
	.byte $70,$D8,$D8,$70,$D8,$D8,$70,$00; #184 $B8
	.byte $70,$D8,$D8,$78,$18,$D8,$70,$00; #185 $B9
	.byte $70,$D8,$D8,$F8,$D8,$D8,$D8,$00; #186 $BA
	.byte $F0,$D8,$D8,$F0,$D8,$D8,$F0,$00; #187 $BB
	.byte $70,$D8,$C0,$C0,$C0,$D8,$70,$00; #188 $BC
	.byte $F0,$D8,$D8,$D8,$D8,$D8,$F0,$00; #189 $BD
	.byte $F8,$C0,$C0,$F0,$C0,$C0,$F8,$00; #190 $BE
	.byte $F8,$C0,$C0,$F0,$C0,$C0,$C0,$00; #191 $BF

display_status_line:
	;draw initial status line
	lda #<txt_status
	sta source_l
	lda #>txt_status
	sta source_h
	jsr display_message
	;fill in mode
	ldy #$50   ;black on green
	lda screen_height
	clc
	adc #$af
	sta VERA_ADDR_M
	lda #10
	sta VERA_ADDR_L
	ldx data_source
	lda txt_modes_c,x
	tax
dsl3:	lda txt_modes,x
	cmp #0
	beq dsl4
	sta VERA_DATA0
	sty VERA_DATA0
	inx
	jmp dsl3
dsl4:	;Fill in bank
	lda #36
	sta VERA_ADDR_L
	lda data_source
	cmp #2	
	bcs dsl5
	lda bank_sel
	sta hexnum
	sty text_color
	jsr display_hexnum
	rts
dsl5:	;file and i2c will display dashes for bank.
	lda #45   ;minus sign
	sta VERA_DATA0
	sty VERA_DATA0
	sta VERA_DATA0
	sty VERA_DATA0
	rts	

txt_modes:
	scrcode "SYSTEM"
	.byte 0
	scrcode "V-RAM "
	.byte 0
	scrcode "FILE  "
	.byte 0
	scrcode "I2C   "
	.byte 0
txt_modes_c:
	.byte 0,7,14,21

display_current_address:
	;set placement for screen write
	lda #%00010001
	sta VERA_ADDR_H
	lda screen_height
	clc
	adc #$af
	sta VERA_ADDR_M
	lda #54
	sta VERA_ADDR_L
	;figure out current address of cursor
	jsr calc_current_address
	jsr calc_the_rest
	;write hex digits to status line
	lda #$50   ;Black on green
	sta text_color
	lda source_h
	sta hexnum
	jsr display_hexnum
	lda source_l
	sta hexnum
	jsr display_hexnum
	rts

goto_system_bank:
	stz temp
	jsr erase_cursor
	;set placement for screen write
	lda #%00010001
	sta VERA_ADDR_H
	lda screen_height
	clc
	adc #$af
	sta VERA_ADDR_M
	lda #36
	sta VERA_ADDR_L
	lda #45      ;minus sign
	ldy #01      ;white on black
	sta VERA_DATA0
	sty VERA_DATA0
	sta VERA_DATA0
	sty VERA_DATA0
	lda #36
	sta VERA_ADDR_L   ;return to first spot
	;Wait for user to type numbers
goba1:	jsr getin
	cmp #0
	beq goba1
	;check if it is 0-9
	cmp #48   ;0
	bcc goba3
	cmp #58   ;9+1
	bcs goba2
	sec
	sbc #48
	jmp goba8
goba2:	;check if it is A-F
	cmp #65   ;A
	bcc goba3
	cmp #71   ;F+1
	bcs goba3	
	sec
	sbc #55
	jmp goba8
goba3:	cmp #27   ;escape
	bne goad1
	jsr display_status_line
	jsr draw_cursor
	jmp user_input
goba8:	;process user numbers
	ldx temp
	sta buffer,x
	tax
	lda hexchart,x
	sta VERA_DATA0
	lda #01   ;white on black
	sta VERA_DATA0
	inc temp
	lda temp	
	cmp #2
	bne goba1
	lda buffer
	asl
	asl
	asl
	asl
	ora buffer+1
	sta bank_sel
	sta ram_bank
	jsr render_entire_area
	stz cursor_x
	stz cursor_y
	jsr display_status_line
	jsr draw_cursor
	jmp user_input

goto_address:
	stz temp
	jsr erase_cursor
	;set placement for screen write
	lda #%00010001
	sta VERA_ADDR_H
	lda screen_height
	clc
	adc #$af
	sta VERA_ADDR_M
	lda #54
	sta VERA_ADDR_L
	lda #45      ;minus sign
	ldy #01      ;white on black
	sta VERA_DATA0
	sty VERA_DATA0
	sta VERA_DATA0
	sty VERA_DATA0
	sta VERA_DATA0
	sty VERA_DATA0
	sta VERA_DATA0
	sty VERA_DATA0
	lda #54
	sta VERA_ADDR_L   ;return to first spot
	ldx #0
	;Wait for user to type numbers
goad1:	jsr getin
	cmp #0
	beq goad1
	;check if it is 0-9
	cmp #48   ;0
	bcc goad3
	cmp #58   ;9+1
	bcs goad2
	sec
	sbc #48
	jmp goad8
goad2:	;check if it is A-F
	cmp #65   ;A
	bcc goad3
	cmp #71   ;F+1
	bcs goad3	
	sec
	sbc #55
	jmp goad8
goad3:	cmp #20   ;backspace
	bne goad4
	jmp gobs1
goad4:	cmp #27   ;escape
	bne goad1
	jsr draw_cursor
	jmp user_input
goad8:	ldx temp
	sta buffer,x
	tax
	lda hexchart,x
	sta VERA_DATA0
	lda #01   ;white on black
	sta VERA_DATA0
	inc temp
	lda temp	
	cmp #4
	bne goad1
	lda buffer
	asl
	asl
	asl
	asl
	ora buffer+1
	sta top_address_h
	lda buffer+2
	asl
	asl
	asl
	asl
	ora buffer+3
	sta top_address_l
	jsr validate_max
	jsr render_entire_area
	stz cursor_x
	stz cursor_y
	jsr draw_cursor
	jmp user_input
gobs1:	;backspace address
	lda temp
	cmp #0
	bne gobs2
	jmp goad1
gobs2:	dec VERA_ADDR_L
	dec VERA_ADDR_L
	lda #45   ;minus sign
	sta VERA_DATA0
	lda #01   ;white on black
	sta VERA_DATA0
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	dec temp
	jmp goad1

help_screen:
	;prepare source
	lda #<help_text_page1
	sta source_l
	lda #>help_text_page1
	sta source_h
	;Determine screen size
hedi1:	lda screen_width
	sec
	sbc #32
	sta temp
	;Prepare screen
	jsr clear_screen
	lda #%00010001
	sta VERA_ADDR_H
	lda screen_height
	sec
	sbc #15
	lsr
	adc #$b0
	sta VERA_ADDR_M
	adc #15
	sta hexnum   ;used as a temp value here
	lda temp
	sta VERA_ADDR_L
	;copy text
	ldy #0
	ldx #0
hesc1:	lda (source_l),y
	sta VERA_DATA0
	cmp #63
	bcs hesc5
	lda #$67   ;white on blue
	sta VERA_DATA0
	jmp hesc4
hesc5:	lda #$61   ;white on blue
	sta VERA_DATA0
hesc4:	inc source_l
	bne hesc2
	inc source_h
hesc2:	inx
	cpx #32
	bne hesc1
	ldx #0
	lda temp
	sta VERA_ADDR_L
	inc VERA_ADDR_M
	lda VERA_ADDR_M
	cmp hexnum
	bne hesc1
hesc3:	;wait for keypress
	jsr getin
	cmp #0
	beq hesc3
	cmp #$02   ;page down
	beq hesc6
	jmp scok2
hesc6:	lda #<help_text_page2
	sta source_l
	lda #>help_text_page2
	sta source_h
	jmp hedi1

help_text_page1:
	.byte $55,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$49
	.byte $5d
	scrcode "HEXEDIT 1.0 FOR COMMMANDER X16"
	.byte $5d
	.byte $5d
	scrcode "     BY DAVID MURRAY 2023     "
	.byte $5d
	.byte $6b,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$73
	.byte $5d
	scrcode "F1-CHANGE DATA SOURCE         "
	.byte $5d
	.byte $5d
	scrcode "F2-CHANGE BANK                "
	.byte $5d
	.byte $5d
	scrcode "F3-CHANGE TEXT REPRESENTATION "
	.byte $5d
	.byte $5d
	scrcode "H-THIS HELP SCREEN            "
	.byte $5d
	.byte $5d
	scrcode "G-GOTO ADDRESS                "
	.byte $5d
	.byte $5d
	scrcode "SHIFT D-DEVICE NUMBER         "
	.byte $5d
	.byte $5d
	scrcode "SHIFT L/S-LOAD OR SAVE FILE   "
	.byte $5d
	.byte $5d
	scrcode "PAGE DOWN FOR MORE HELP       "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "PRESS ANY KEY TO RETURN       "
	.byte $5d
	.byte $4a,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$4b
help_text_page2:
	.byte $55,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$49
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "SHIFT B/E/C-BEGIN/END/CLEAR   "
	.byte $5d
	.byte $5d
	scrcode "SHIFT Z-ZERO SELECTION        "
	.byte $5d
	.byte $5d
	scrcode "SHIFT+HOME-ZERO FILE AREA     "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "SEE HEXEDIT.TXT FILE OR X16   "
	.byte $5d
	.byte $5d
	scrcode "USER MANUAL FOR MORE DETAILED "
	.byte $5d
	.byte $5d
	scrcode "INSTRUCTIONS                  "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "                              "
	.byte $5d
	.byte $5d
	scrcode "PRESS ANY KEY TO RETURN       "
	.byte $5d
	.byte $4a,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$40,$4b

save_file:
	;make sure user has active selection
	lda select_active
	cmp #%00000011
	beq safi0
	lda #<err_save1
	sta source_l
	lda #>err_save1
	sta source_h
	jsr display_error
	jmp  user_input
safi0:	;get filename from user
	jsr erase_cursor
	jsr filename_input
	lda filename_length
	cmp #0	;zero means abort
	bne safib
	jmp save_finish
safib:	;launch appropriate save for this mode
	lda data_source
	cmp #0  ;system
	bne safi1
	jmp save_from_system
safi1:	cmp #1  ;vram
	bne safi2
	jmp save_from_vram
safi2:	jmp save_from_file

save_from_file:	
	;setup source location
	lda select_begin_l
	sta source_l
	sta temp_l
	lda select_begin_h
	sta source_h
	and #%00011111
	clc
	adc #$a0
	sta temp_h
	lda select_begin_h
	lsr
	lsr
	lsr
	lsr
	lsr
	inc
	sta ram_bank
	;tell kernal the filename
	lda filename_length  ;Length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam           ; (SETNAM) A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	;tell kernal to set the logical file system.
	lda #02
	ldx drive_number
	ldy #1               ; write mode
	jsr setlfs           ; SETLFS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	;Open the file
	jsr open             ; (OPEN) open file.
	;redirect CHROUT to the opened file
	ldx #02              ; set LFN
	jsr ckout            ; (CHKOUT) set output to file
	bcc wfloop           ; branch if no error
	;sta io_error         ; save error code
	bra wfdone           ; close and exit
	ldy #0
wfloop:	;start writing the bytes to the file
	lda (temp_l)
	jsr bsout            ; (CHROUT) send byte to file
	;Check if we've finished
	lda source_h
	cmp select_end_h
	bne wf3
	lda source_l
	cmp select_end_l
	beq wfdone           ;finished
wf3:	;Advance source_l/h
	inc source_l
	bne wf4
	inc source_h
wf4:	;Advance temp
	inc temp_l
	bne wfloop
	inc temp_h
	lda temp_h
	cmp #$c0
	bne wfloop
	lda #$a0
	sta temp_h
	inc ram_bank
	jmp wfloop
wfdone:	;close the file
	lda #02              ; LFN
	jsr close            ; (CLOSE) close file
	jsr clrch            ; (CLRCHN) restore I/O to screen/keyboard
	jmp save_finish
	
save_from_vram:
	;Setup VRAM start location
	lda #%00010000
	clc
	adc bank_sel
	sta VERA_ADDR_H
	lda select_begin_h
	sta VERA_ADDR_M
	lda select_begin_l
	sta VERA_ADDR_L
	;tell kernal the filename
	lda filename_length  ;Length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam           ; (SETNAM) A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	;tell kernal to set the logical file system.
	lda #02
	ldx drive_number
	ldy #1               ; write mode
	jsr setlfs           ; SETLFS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	;Open the file
	jsr open             ; (OPEN) open file.
	;redirect CHROUT to the opened file
	ldx #02              ; set LFN
	jsr ckout            ; (CHKOUT) set output to file
	bcc wrloop           ; branch if no error
	;sta io_error         ; save error code
	bra wrdone           ; close and exit
wrloop:	;start writing the bytes to the file	
	lda VERA_DATA0
	jsr bsout            ; (CHROUT) send byte to file
	lda VERA_ADDR_M
	cmp select_end_h
	bne wrloop
	lda VERA_ADDR_L
	cmp select_end_l
	bne wrloop
	;write last byte
	lda VERA_DATA0
	jsr bsout            ; (CHROUT) send byte to file
	;close the file
wrdone:	lda #02              ; LFN
	jsr close            ; (CLOSE) close file
	jsr clrch            ; (CLRCHN) restore I/O to screen/keyboard
	jmp save_finish	

save_from_system:
	;ask user about load address
	jsr ask_load_address
	lda #<txt_saving
	sta source_l
	lda #>txt_saving
	sta source_h
	jsr display_message
	;copy end address to source_l/h and increase
	;by one so that the last byte gets saved.
	lda select_end_l
	sta source_l
	lda select_end_h
	sta source_h
	inc source_l
	bne sfs2
	inc source_h
	;save file to disk using kernal save
sfs2:	lda filename_length   ;length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam            ;SETNAM A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	lda #$02
	ldx drive_number
	ldy #$02
	jsr setlfs            ;SETLFS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	ldx source_l          ;LOW BYTE FOR END OF FILE ADDRESS
	ldy source_h          ;HIGH BYTE FOR END OF FILE ADDRESS
	lda ula
	cmp #0                ;use load address? 0=no 1=yes
	bne sfs3
	lda #<select_begin_l  ;Tell kernal where to find start of file address
	jsr bsave             ;bsave (no load address)
	jmp sfs4
sfs3:	lda #<select_begin_l  ;Tell kernal where to find start of file address
	jsr save              ;SAVE FILE A=ADDRESS ZEROPAGE POINTER, X/Y= END OF ADDRESS+1
sfs4:	lda #$02
	jsr close             ;CLOSE FILE
save_finish:
	jsr display_dos_status
	jsr display_status_line
	jsr draw_cursor
	jmp user_input

load_file:
	;get filename from user
	jsr erase_cursor
	jsr filename_input
	lda filename_length
	cmp #0                ;zero means abort
	bne ldf0
	jmp load_file_finish
ldf0:	;launch appropriate save for this mode
	lda data_source
	cmp #0                ;system
	bne ldf1
	jmp load_to_system
ldf1:	cmp #1                ;vram
	bne ldf2
	jmp load_to_vram
ldf2:	jmp load_to_filemode

load_file_finish:
	jsr render_entire_area
	jsr display_dos_status
	jsr display_status_line
	jsr draw_cursor
	jmp user_input

load_to_filemode:
	;grab address of cursor
	jsr calc_current_address
	jsr calc_the_rest
	lda source_h
	lsr
	lsr
	lsr
	lsr
	lsr
	inc
	sta ram_bank
	lda source_h
	and #%00011111
	clc
	adc #$a0
	sta source_h
	;use kernal vload routine
	lda filename_length  ;Length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam           ;SETNAM A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	lda #$02
	ldx drive_number
	ldy #$02
	jsr setlfs           ;SETLFS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	ldx source_l         ;location in vram
	ldy source_h         ;location in vram
	lda #0		
	jsr $ffd5            ;LOAD FILE A=0 FOR LOAD X/Y=LOAD ADDRESS
	lda #$02
	jsr $ffc3            ;CLOSE FILE
	jmp load_file_finish

load_to_vram:
	;grab address of cursor
	jsr calc_current_address
	jsr calc_the_rest
	;use kernal vload routine
	lda filename_length  ;Length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam           ;SETNAM A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	lda #$02
	ldx drive_number
	ldy #$02
	jsr setlfs           ;SETLFS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	ldx source_l         ;location in vram
	ldy source_h         ;location in vram
	lda bank_sel         ;Set vram bank
	inc
	inc
	jsr load             ;LOAD FILE A=0 FOR LOAD X/Y=LOAD ADDRESS
	lda #$02
	jsr close            ;CLOSE FILE
	jmp load_file_finish
	
load_to_system:
	jsr ask_load_address
	;grab address of cursor
	jsr calc_current_address
	jsr calc_the_rest
	;do actual load
	lda filename_length  ;Length of filename
	ldx #<filename
	ldy #>filename
	jsr setnam           ;SETNAM A=FILE NAME LENGTH X/Y=POINTER TO FILENAME
	lda ula
	cmp #0               ;use load address? 0=no 1=yes
	bne lts1
	ldy #$02             ;secondary command (BLOAD)
	jmp lts2
lts1:	ldy #$00             ;secondary command (normal load)
lts2:	ldx drive_number
	lda #$02             ;LOGICAL
	jsr setlfs           ;SETFLS A=LOGICAL NUMBER X=DEVICE NUMBER Y=SECONDARY
	ldx source_l
	ldy source_h
	lda #$00
	jsr load             ;LOAD FILE A=0 FOR LOAD X/Y=LOAD ADDRESS
	lda #$02
	jsr close            ;CLOSE FILE
	jmp load_file_finish

ask_load_address:
	lda #<txt_load_address
	sta source_l
	lda #>txt_load_address
	sta source_h
	jsr display_message
ala1:	jsr getin
	cmp #78  ;N
	bne ala2
	stz ula
	rts
ala2:	cmp #89	 ;Y
	bne ala1
	lda #1
	sta ula
	rts

filename_input:
	stz filename_length
	lda #<txt_filename
	sta source_l
	lda #>txt_filename
	sta source_h
	jsr display_message
	;go back to screen location for filename
	lda #19
	sta VERA_ADDR_L
	lda #$05       ;green on black
	sta VERA_DATA0
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	;wait for user input
fnin3:	jsr getin
	cmp #0
	beq fnin3
	cmp #13        ;Return
	bne fnin4
	rts
fnin4:	cmp #20        ;Backspace
	bne fnin5
	jmp fnbs1
fnin5:	cmp #27        ;Escape
	bne fnin6
	stz filename_length
	rts
fnin6:	;check if we are at max length
	ldx filename_length
	cpx #16
	beq fnin3
	sta filename,x
	jsr convert_petscii_to_screen_code
	sta VERA_DATA0
	lda #$50       ;black on green
	sta VERA_DATA0
	inc VERA_ADDR_L
	lda #$05       ;green on black (CURSOR)
	sta VERA_DATA0
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	inc filename_length
	jmp fnin3
fnbs1:	;filename backspace
	;first make sure we aren't at zero already
	ldx filename_length
	cpx #0
	beq fnin3
	dec filename_length
	lda #32
	sta VERA_DATA0
	lda #$50       ;black on green
	sta VERA_DATA0
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	lda #$05       ;green on black (cursor)
	sta VERA_DATA0
	dec VERA_ADDR_L
	dec VERA_ADDR_L
	jmp fnin3
	
change_drive_number:
	stz filename_length
	lda #<txt_drive_number
	sta source_l
	lda #>txt_drive_number
	sta source_h
	jsr display_message
	jsr display_drive_number
chd5:	;get user input
	jsr getin
	cmp #$9d       ;Cursor Left
	bne chd6
	jsr dec_drive
	jsr display_drive_number
	jmp chd5
chd6:	cmp #$1d       ;Cursor Right
	bne chd7
	jsr inc_drive
	jsr display_drive_number
	jmp chd5
chd7:	cmp #$0d       ;Home
	bne chd5
chd8:	jsr display_status_line
	jsr draw_cursor
	jmp user_input

inc_drive:
	lda drive_number
	cmp #11
	beq incd1
	inc drive_number
	rts
incd1:	lda #8
	sta drive_number
	rts

dec_drive:
	lda drive_number
	cmp #8
	beq decd1
	dec drive_number
	rts
decd1:	lda #11
	sta drive_number
	rts

display_drive_number:
	;go to screen location for drive number
	lda #26
	sta VERA_ADDR_L
	lda #$05       ;green on black
	;Now write text
	lda drive_number
	sec
	sbc #8
	asl
	tax
	lda txt_drive_scr,x
	sta VERA_DATA0
	lda #$50       ;black on green
	sta VERA_DATA0
	inx
	lda txt_drive_scr,x
	sta VERA_DATA0
	lda #$50       ;black on green
	sta VERA_DATA0
	rts

txt_drive_scr:
	scrcode "08091011"

display_dos_status:
	;clear status line and add initial text
	lda #<txt_drive_status
	sta source_l
	lda #>txt_drive_status
	sta source_h
	jsr display_message
	;setup VERA registers for next part
	lda #26
	sta VERA_ADDR_L
	;read status channel of disk drive	
	lda #$ff       ; A=-1
	;sta dos_error ; set DOS error
	sta hexnum     ; set I/O error
	inc            ; A=0
	ldx #31        ; load LEN-1 into index
clrbuf:	sta buffer,x   ; store into buffer
	dex            ; dec index
	bpl clrbuf     ; branch until < 0
	; open 15,8,15,""
	lda #15        ; set LFN
	ldx drive_number ; set device #
	ldy #15        ; command channel
	jsr setlfs     ; (SETLFS) A=LFN, X=device #, Y=command
	ldx #0         ; no filename low
	ldy #0         ; no filename high
	lda #0         ; length 0
	jsr setnam     ; (SETNAM) set file name
	jsr open       ; (OPEN) open file
	jsr readst     ; (READST) get status
	cmp #1         ; compare error
	bcc cmdopen    ; branch if no error
	bra cmdcl      ; close and exit
cmdopen:
	ldx #15        ; LFN for DOS
	jsr chkin      ; (CHKIN) get input from DOS command
	bcc readbuf    ; branch if no error
	sta hexnum     ; save error code
	bra cmdcl      ; close and exit
readbuf:
	ldx #0         ; setup buf index
	; while no error, read character into buffer
readlp:	jsr basin      ; (CHRIN) read character from file
	tay
	jsr readst     ; (READST) read file status
	cmp #0         ; was there an error?
	bne readdn     ; branch if error to done
	tya
	jsr convert_petscii_to_screen_code
	sta VERA_DATA0 ; store it
	lda #$50       ; black on green
	sta VERA_DATA0
	inx            ; inc index
	bra readlp     ; keep reading
readdn:	bit #$40       ; was error EOF?
	;bne @convert  ; branch if no error (was EOF)
	sta hexnum     ; save error code
	bra cmdcl      ; close and exit
cmdcl:	;Command close
	lda #15        ; LFN
	jsr close      ; close file
	jsr clrch      ; (CLRCHN) restore I/O to screen/keyboard
	;lda dos_error  ; error code in A
	cmp #1         ; C = set if A >= 1
	bcs err        ; branch if there was an error
	stz hexnum     ; clear I/O error
err:	;NOW WAIT FOR KEYPRESS
	jsr getin
	cmp #0
	beq err	
	rts            ; return
	

display_error:
	lda source_l
	pha
	lda source_h
	pha
	jsr erase_cursor
	pla
	sta source_h
	pla
	sta source_l
	jsr display_message
	;beep
	lda #7
	jsr bsout
	;now wait for keypress
dier1:	jsr getin
	cmp #0
	beq dier1
	jsr display_status_line
	jsr draw_cursor
	rts

display_message:
	;set placement for screen write
	lda #%00010001
	sta VERA_ADDR_H
	lda screen_height
	clc
	adc #$af
	sta VERA_ADDR_M
	stz VERA_ADDR_L
	;Write "drive number" to status bar
	ldy #0
	ldx #$50       ;black on green
dmsg1:	lda (source_l),y
	cmp #0
	beq dmsg2
	sta VERA_DATA0
	stx VERA_DATA0
	iny
	bne dmsg1
	;clear rest of status bar
dmsg2:	lda #32
dmsg3:	sta VERA_DATA0
	stx VERA_DATA0
	iny
	cpy screen_width
	bne dmsg3
	rts

txt_drive_number:
	scrcode "DRIVE NUMBER:"
	.byte 0
txt_filename:
	scrcode "FILENAME:"
	.byte 0
txt_exit_message:
	scrcode "EXIT PROGRAM Y/N?"
	.byte 0
txt_status:
	scrcode "MODE:        BANK:    LOC:$"
	.byte 0
txt_load_address:
	scrcode "USE LOAD ADDRESS HEADER? Y/N"
	.byte 0
txt_saving:
	scrcode "SAVING..."
	.byte 0
txt_drive_status:
	scrcode "DRIVE STATUS:"
	.byte 0
err_save1:
	scrcode "MUST MARK SELECTION FIRST!"
	.byte 0
