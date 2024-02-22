.ifndef CX16_INC
CX16_INC=1

KERNALVER	= $FF80
VIA1		= $9F00
VIA1PA		= VIA1+1
VIA1PB		= VIA1+0
VIA2		= $9F10
VIA2PA		= VIA2+1
VIA2PB		= VIA2+0
YM2151		= $9F40
YM2151ADDR	= YM2151
YM2151DATA	= YM2151+1
MMIO3		= $9F60
MMIO4		= $9F80
MMIO5		= $9FA0
MMIO6		= $9FC0
MMIO7		= $9FE0

RAM_BANK_START	= $A000
RAM_BANK_SIZE   = $2000
ROM_BANK_START	= $C000
ROM_BANK_SIZE   = $4000

; RAM/ROM bank control for PRE_RELEASE_VERSION=39+
RAM_BANK	= $00
ROM_BANK	= $01

; Emulator
GIFCTRL		= $9FB5
WAVCTRL		= $9FB6

; Vectors
IRQVECTOR	= $0314		; Left from previous version
CINV		= $0314		; IRQ interrupt routine
CBINV		= $0316		; BRK instruction interrupt
NMINV		= $0318		; Non-maskable interrupt
IOPEN		= $031A		; Kernal OPEN routine
ICLOSE		= $031C		; Kernal CLOSE routine
ICHKIN		= $031E		; Kernal CHKIN routine
ICKOUT		= $0320		; Kernal CHKOUT routine
ICLRCH		= $0322		; Kernal CLRCHN routine
IBASIN		= $0324		; Kernal CHRIN/BASIN routine
IBSOUT		= $0326		; Kernal CHROUT/BSOUT routine
ISTOP		= $0328		; Kernal STOP routine
IGETIN		= $032A		; Kernal GETIN routine
ICLALL		= $032C		; Kernal CLALL routine
KEYHANDLER	= $032E		; Kernal Key Event Handler
ILOAD		= $0330		; Kernal LOAD routine
ISAVE		= $0332		; Kernal SAVE routine

; Text mode ports (not supported and changes between ROM releases)
COLORPORT	= $0376
NUMCOLS		= $0386
NUMLINES	= $0387

; ROM Bank allocations
KERNAL_BANK	= 0
KEYBD_BANK	= 1
CBDOS_BANK	= 2
GEOS_BANK	= 3
BASIC_BANK	= 4
MONITOR_BANK	= 5
CHARSET_BANK	= 6
CODEX_BANK	= 7
GRAPH_BANK	= 8
DEMO_BANK	= 9
AUDIO_BANK	= 10
UTIL_BANK	= 11
BANNEX_BANK	= 12

; I2C device addresses
I2C_SMC		= $42
I2C_RTC		= $6F

; SMC registers
SMC_power	= $01
SMC_reset	= $02
SMC_NMI		= $03
SMC_power_led	= $04
SMC_activity_led= $05
SMC_kbd_buf	= $07
SMC_ps2_status	= $18
SMC_ps2_command	= $19
SMC_mouse_buffer= $21
; SMC values
SMC_power_off	= $00
SMC_hard_reboot	= $01
SMC_reset_val	= $00
SMC_inject_nmi	= $00

; RTC registers
RTC_clock_seconds	= $00
RTC_clock_minutes	= $01
RTC_clock_hours		= $02
RTC_clock_weekday	= $03
RTC_clock_day		= $04
RTC_clock_month		= $05
RTC_clock_year		= $06
RTC_control		= $07
RTC_oscillator_trim	= $08
RTC_alarm0_seconds	= $0A
RTC_alarm0_minutes	= $0B
RTC_alarm0_hours	= $0C
RTC_alarm0_weekday	= $0D
RTC_alarm0_day		= $0E
RTC_alarm0_month	= $0F
RTC_alarm1_seconds	= $11
RTC_alarm1_minutes	= $12
RTC_alarm1_hours	= $13
RTC_alarm1_weekday	= $14
RTC_alarm1_day		= $15
RTC_alarm1_month	= $16
RTC_power_fail_minutes	= $18
RTC_power_fail_hours	= $19
RTC_power_fail_day	= $1A
RTC_power_fail_month	= $1B
RTC_power_up_minutes	= $1C
RTC_power_up_hours	= $1D
RTC_power_up_day	= $1E
RTC_power_up_month	= $1F

; ZeroPage variables/pointers
TMP0		= $30
TMP1		= $31
TMP2		= $32
TMP3		= $33
TMP4		= $34
TMP5		= $35
TMP6		= $36
TMP7		= $37
TMP8		= $38
TMP9		= $39
TMPa		= $3A
TMPb		= $3B
TMPc		= $3C
TMPd		= $3D
TMPe		= $3E
TMPf		= $3F
TMP_PTR0	= TMP0
TMP_PTR1	= TMP2
TMP_PTR2	= TMP4
TMP_PTR3	= TMP6
TMP_PTR4	= TMP8
TMP_PTR5	= TMPa
TMP_PTR6	= TMPc
TMP_PTR7	= TMPe


; PETSCII color codes
PET_BLACK	= $90
PET_WHITE	= $05
PET_RED		= $1C
PET_CYAN	= $9F
PET_PURPLE	= $9C
PET_GREEN	= $1E
PET_BLUE	= $1F
PET_YELLOW	= $9E
PET_ORANGE	= $81
PET_BROWN	= $95
PET_LIGHTRED	= $96
PET_DARKGRAY	= $97
PET_MIDGRAY	= $98
PET_LIGHTGREEN	= $99
PET_LIGHTBLUE	= $9A
PET_LIGHTGRAY	= $9B

; PETSCII control codes
PET_SWAP_FGBG	= $01	; Swap foregound- & background- color
PET_STOP	= $03
PET_UNDERLINE	= $04	; only works in graphics text mode
PET_BOLD	= $06	; only works in graphics text mode
PET_BELL	= $07	; not yet implemented 27/01 2021
PET_BACKSPACE	= $08	; not yet implemented 27/01 2021
PET_TAB		= $09	; not yet implemented 27/01 2021
PET_LINEFEED	= $0A	; not yet implemented 27/01 2021
PET_ITALICS	= $0B	; only works in graphics text mode
PET_OUTLINE	= $0C	; only works in graphics text mode
PET_RETURN	= $0D
PET_CHR_LO_UP	= $0E	; Switch between lower and upper character set
PET_ISO_ON	= $0F	; Enable ISO mode
PET_CSR_DOWN	= $11	; Move cursor down
PET_REVERSE	= $12
PET_HOME	= $13
PET_DELETE	= $14
PET_SHIFT_TAB	= $18	; not yet implemented 27/01 2021
PET_CSR_RIGHT	= $1D	; Move cursor right
PET_RUN		= $83
PET_HELP	= $84
PET_SHIFT_RET	= $8D	; Shift+Return
PET_UP_GFX_CHAR	= $8E
PET_ISO_OFF	= $8F	; Disable ISO mode
PET_CSR_UP	= $91	; Move cursor up
PET_REVERSE_OFF	= $92
PET_CLEAR	= $93	; Clear screen
PET_INSERT	= $94
PET_CSR_LEFT	= $9D	; Move cursor left

; Color values
BLACK		= 0
WHITE		= 1
RED		= 2
CYAN		= 3
PURPLE		= 4
GREEN		= 5
BLUE		= 6
YELLOW		= 7
ORANGE		= 8
BROWN		= 9
LIGHTRED	= 10
DARKGRAY	= 11
MIDGRAY		= 12
LIGHTGREEEN	= 13
LIGHTBLUE	= 14
LIGHTGRAY	= 15

; VERA screen modes
SCR_MOD_80x60	= $00
SCR_MOD_80x30	= $01
SCR_MOD_40x60	= $02
SCR_MOD_40x30	= $03
SCR_MOD_40x15	= $04
SCR_MOD_20x30	= $05
SCR_MOD_20x15	= $06
SCR_MOD_22x23	= $07
SCR_MOD_64x50	= $08
SCR_MOD_64x25	= $09
SCR_MOD_32x50	= $0A
SCR_MOD_32x25	= $0B
SCR_GFX_320x200	= $80	; 320x200@256c - 40x25 text
SCR_GFX_640x400 = $81	; 640x400@16c (unsupported)
SCR_MOD_TOGGLE	= $FF	; Toggle between $00 and $03

; Joystick button values
SNES_B		= $80
SNES_Y		= $40
SNES_SEL	= $20
SNES_STA	= $10
SNES_UP		= $08
SNES_DN		= $04
SNES_LT		= $02
SNES_RT		= $01
SNES_A		= $80
SNES_X		= $40
SNES_L		= $20
SNES_R		= $10

; "ABI" registers in ZeroPage
r0		= $02
r0l		= r0
r0h		= r0+1
r1		= $04
r1l		= r1
r1h		= r1+1
r2		= $06
r2l		= r2
r2h		= r2+1
r3		= $08
r3l		= r3
r3h		= r3+1
r4		= $0A
r4l		= r4
r4h		= r4+1
r5		= $0C
r5l		= r5
r5h		= r5+1
r6		= $0E
r6l		= r6
r6h		= r6+1
r7		= $10
r7l		= r7
r7h		= r7+1
r8		= $12
r8l		= r8
r8h		= r8+1
r9		= $14
r9l		= r9
r9h		= r9+1
r10		= $16
r10l		= r10
r10h		= r10+1
r11		= $18
r11l		= r11
r11h		= r11+1
r12		= $1A
r12l		= r12
r12h		= r12+1
r13		= $1C
r13l		= r13
r13h		= r13+1
r14		= $1E
r14l		= r14
r14h		= r14+1
r15		= $20
r15l		= r15
r15h		= r15+1

; extra registers in ZeroPage - not used by CX16 kernal, but shown in debugger
x16		= $22
x16l		= x16
x16h		= x16+1
x17		= $24
x17l		= x17
x17h		= x17+1
x18		= $26
x18l		= x18
x18h		= x18+1
x19		= $28
x19l		= x19
x19h		= x19+1

; extra registers in ZeroPage - not used by CX16 at all
z20		= $2A
z20l		= z20
z20h		= z20+1
z21		= $2C
z21l		= z21
z21h		= z21+1
z22		= $2E
z22l		= z22
z22h		= z22+1

; Commodore 64 API - see https://cx16.dk/c64-kernal-routines/
ACPTR		= $FFA5
IECIN		= $FFA5
CHKIN		= $FFC6
CHKOUT		= $FFC9
CHRIN		= $FFCF
BASIN		= $FFCF
CHROUT		= $FFD2
BSOUT		= $FFD2
CIOUT		= $FFA8
IECOUT		= $FFA8
CINT		= $FF81
CLALL		= $FFE7
CLOSE		= $FFC3
CLRCHN		= $FFCC
GETIN		= $FFE4
IOBASE		= $FFF3
IOINIT		= $FF84
LISTEN		= $FFB1
LOAD		= $FFD5
MEMBOT		= $FF9C
MEMTOP		= $FF99
OPEN		= $FFC0
PLOT		= $FFF0
RAMTAS		= $FF87
RDTIM		= $FFDE
READST		= $FFB7
RESTOR		= $FF8A
SAVE		= $FFD8
SCNKEY		= $FF9F
SCREEN		= $FFED
SECOND		= $FF93
SETLFS		= $FFBA
SETMSG		= $FF90
SETNAM		= $FFBD
SETTIM		= $FFDB
SETTMO		= $FFA2
STOP		= $FFE1
TALK		= $FFB4
TKSA		= $FF96
UDTIM		= $FFEA
UNLSN		= $FFAE
UNTLK		= $FFAB
VECTOR		= $FF8D

; Commodore 128 API
CLOSE_ALL	= $FF4A
DLCHR		= $FF62
PFKEY		= $FF65
FETCH		= $FF74
STASH		= $FF77
CMPARE		= $FF7A
PRIMM		= $FF7D

; Commander X16 API
; ChIO
BSAVE			= $FEBA
LKUPLA			= $FF59
LKUPSA			= $FF5C
; I2C
i2c_read_byte		= $FEC6
i2c_write_byte		= $FEC9
;keyboard
kbdbuf_get_modifiers	= $FEC0
kbdbuf_peek		= $FEBD
kbdbuf_put		= $FEC3
keymap			= $FED2
;clock
Clock_set_data_time	= $FF4D
Clock_get_date_time	= $FF50
;mouse
Mouse_config		= $FF68
Mouse_scan		= $FF71
Mouse_get		= $FF6B
;joystick
Joystick_scan		= $FF53
Joystick_get		= $FF56
;sprites
Sprite_set_image	= $FEF0
Sprite_set_position	= $FEF3
;framebuffer
FB_init			= $FEF6
FB_get_info		= $FEF9
FB_set_palette		= $FEFC
FB_cursor_position	= $FEFF
FB_cursor_next_line	= $FF02
FB_get_pixel		= $FF05
FB_get_pixels		= $FF08
FB_set_pixel		= $FF0B
FB_set_pixels		= $FF0E
FB_set_8_pixels		= $FF11
FB_set_8_pixels_opaque	= $FF14
FB_fill_pixels		= $FF17
FB_filter_pixels	= $FF1A
FB_move_pixels		= $FF1D
;graphics
Graph_init		= $FF20
Graph_clear		= $FF23
Graph_set_window	= $FF26
Graph_set_colors	= $FF29
Graph_draw_line		= $FF2C
Graph_draw_rect		= $FF2F
Graph_move_rect		= $FF32
Graph_draw_oval		= $FF35
Graph_draw_image	= $FF38
Graph_set_font		= $FF3B
Graph_get_char_size	= $FF3E
Graph_put_char		= $FF41
;console
Console_init		= $FEDB
Console_put_char	= $FEDE
Console_put_image	= $FED8
Console_get_char	= $FEE1
Console_set_paging_message	= $FED5
;other
Memory_fill		= $FEE4
Memory_copy		= $FEE7
Memory_crc		= $FEEA
Memory_decompress	= $FEED
Entropy_get		= $FECF
MACPTR			= $FF44
Monitor			= $FECC
Enter_basic		= $FF47
Screen_mode		= $FF5F
Screen_set_charset	= $FF62
JSRFAR			= $FF6E

; Commander X16 API - Math Library (ROM bank 4)
; Format Conversions - Compatible with C128 & C65
AYINT	= $FE00
GIVAYF	= $FE03
FOUT	= $FE06
VAL_1	= $FE09
GETADR	= $FE0C
FLOATC	= $FE0F
; Math Functions - Compatible with C128 & C65
FSUB	= $FE12
FSUBT	= $FE15
FADD	= $FE18
FADDT	= $FE1B
FMULT	= $FE1E
FMULTT	= $FE21
FDIV	= $FE24
FDIVT	= $FE27
LOG	= $FE2A
INT	= $FE2D
SQR	= $FE30
NEGOP	= $FE33
FPWR	= $FE36
FPWRT	= $FE39
EXP	= $FE3C
COS	= $FE3F
SIN	= $FE42
TAN	= $FE45
ATN	= $FE48
ROUND	= $FE4B
ABS	= $FE4E
SIGN	= $FE51
FCOMP	= $FE54
RND_0	= $FE57
; Movement - Compatible with C128 & C65
CONUPK	= $FE5A
ROMUPK	= $FE5D
MOVFRM	= $FE60
MOVFM	= $FE63
MOVMF	= $FE66
MOVFA	= $FE69
MOVAF	= $FE6C
; X16 specific
FADDH	= $FE6F
ZEROFC	= $FE72
NORMAL	= $FE75
NEGFAC	= $FE78
MUL10	= $FE7B
DIV10	= $FE7E
MOVEF	= $FE81
SGN	= $FE84
FLOAT	= $FE87
FLOATS	= $FE8A
QINT	= $FE8D
FINLOG	= $FE90
FOUTC	= $FE93
POLYX	= $FE96
POLY	= $FE99

; Commander X16 API - Audio Library (ROM bank 10)
audio_init		= $C09F
; Basic commands
bas_fmchordstring	= $C08D
bas_fmfreq		= $C000
bas_fmnote		= $C003
bas_fmplaystring	= $C006
bas_fmvib		= $C009
bas_playstringvoice	= $C00C
bas_psgchordstring	= $C090
bas_psgfreq		= $C00F
bas_psgnote		= $C012
bas_psgwav		= $C015
bas_psgplaystring	= $C018
; Conversion commands
notecon_bas2fm		= $C01B
notecon_bas2midi	= $C01E
notecon_bas2psg		= $C021
notecon_fm2bas		= $C024
notecon_fm2midi		= $C027
notecon_fm2psg		= $C02A
notecon_freq2bas	= $C02D
notecon_freq2fm		= $C030
notecon_freq2midi	= $C033
notecon_freq2psg	= $C036
notecon_midi2bas	= $C039
notecon_midi2fm		= $C03C
notecon_midi2psg	= $C03F
notecon_psg2bas		= $C042
notecon_psg2fm		= $C045
notecon_psg2midi	= $C048
; PSG commands
psg_getatten		= $C093
psg_getpan		= $C096
psg_init		= $C04B
psg_playfreq		= $C04E
psg_read		= $C051
psg_setatten		= $C054
psg_setfreq		= $C057
psg_setpan		= $C05A
psg_setvol		= $C05D
psg_write		= $C060
psg_write_fast		= $C0A2
; YM2151 commands
ym_getatten		= $C099
ym_getpan		= $C09C
ym_init			= $C063
ym_loaddefpatches	= $C066
ym_loadpatch		= $C069
ym_loadpatchlfn		= $C06C
ym_playdrum		= $C06F
ym_playnote		= $C072
ym_setatten		= $C075
ym_setdrum		= $C078
ym_setnote		= $C07B
ym_setpan		= $C07E
ym_read			= $C081
ym_release		= $C084
ym_trigger		= $C087
ym_write		= $C08A

; *****************************************************************************
; Branch on bit set - This is to replace the w65c02 bbs0-bbs7 opcodes
; *****************************************************************************
; USES:		.A
; *****************************************************************************
.macro BBS bit_pos, data, dest 
	.if (bit_pos = 7)
		bit data
		bmi dest
	.else
		.if (bit_pos = 6)
			bit data
			bvs dest
		.else
			lda data
			and #1 << bit_pos
			bne dest
		.endif
	.endif
.endmacro

; *****************************************************************************
; Branch on bit reset - This is to replace the w65c02 bbr0-bbr7 opcodes
; *****************************************************************************
; USES:		.A
; *****************************************************************************
.macro BBR bit_pos, data, dest
	.if (bit_pos = 7)
		bit data
		bpl dest
	.else
		.if (bit_pos = 6)
			bit data
			bvc dest
		.else
			lda data
			and #1 << bit_pos
			beq dest
		.endif
	.endif
.endmacro

; *****************************************************************************
; Reset memory bit - This is to replace the w65c02 rmb0-rmb7 opcodes
; *****************************************************************************
; USES:		.A
; *****************************************************************************
.macro RMB bit, dest
	lda #1 << bit
	trb dest
.endmacro

; *****************************************************************************
; Set memory bit - This is to replace the w65c02 smb0-smb7 opcodes
; *****************************************************************************
; USES:		.A
; *****************************************************************************
.macro SMB bit, dest
	lda #1 << bit
	tsb dest
.endmacro

; *****************************************************************************
; Save the address of the original interrupt handler
; *****************************************************************************
; USES:		.A
; OUTPUTS:	Address of old handler will be passed back in .old_handler
; *****************************************************************************
.macro SAVE_INT_VECTOR old_handler
	lda	IRQVECTOR
	sta	old_handler
	lda	IRQVECTOR+1
	sta	old_handler+1
.endmacro

; *****************************************************************************
; Install new interrupt handler
; *****************************************************************************
; INPUTS:	.handler = address of new interrupt handler
; USES:		.A
; *****************************************************************************
.macro INSTALL_INT_HANDLER handler
	sei			; Disable interrupts
	lda	#1		; Tell VERA that we want interrupts
	sta	VERA_IEN	; on each VSYNC
	lda	#<handler	; Write address of local interrupt
	sta	IRQVECTOR	; handler to the interrupt
	lda	#>handler	; vector address ($0314)
	sta	IRQVECTOR+1
	cli			; Enable interrupts
.endmacro

.endif