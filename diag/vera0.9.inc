.ifndef VERA_INC
VERA_INC=1

; ******************** Registers ********************
VERA_BASE		= $9F20
VERA_ADDR_L		= VERA_BASE
VERA_ADDR_M		= VERA_BASE+1
VERA_ADDR_H		= VERA_BASE+2
VERA_DATA0		= VERA_BASE+3
VERA_DATA1		= VERA_BASE+4
VERA_CTRL		= VERA_BASE+5
VERA_IEN		= VERA_BASE+6
VERA_ISR		= VERA_BASE+7
VERA_IRQLINE_L		= VERA_BASE+8
VERA_DC			= VERA_BASE+9
VERA_DC_VIDEO		= VERA_DC	; DCSEL=0
VERA_DC_HSCALE		= VERA_DC+1	; DCSEL=0
VERA_DC_VSCALE		= VERA_DC+2	; DCSEL=0
VERA_DC_BORDER		= VERA_DC+3	; DCSEL=0
VERA_DC_HSTART		= VERA_DC	; DCSEL=1
VERA_DC_HSTOP		= VERA_DC+1	; DCSEL=1
VERA_DC_VSTART		= VERA_DC+2	; DCSEL=1
VERA_DC_VSTOP		= VERA_DC+3	; DCSEL=1
VERA_L0			= VERA_DC+4
VERA_L0_CONFIG		= VERA_L0
VERA_L0_MAPBASE		= VERA_L0+1
VERA_L0_TILEBASE	= VERA_L0+2
VERA_L0_HSCROLL_L	= VERA_L0+3
VERA_L0_HSCROLL_H	= VERA_L0+4
VERA_L0_VSCROLL_L	= VERA_L0+5
VERA_L0_VSCROLL_H	= VERA_L0+6
VERA_L1			= VERA_L0+7
VERA_L1_CONFIG		= VERA_L1
VERA_L1_MAPBASE		= VERA_L1+1
VERA_L1_TILEBASE	= VERA_L1+2
VERA_L1_HSCROLL_L	= VERA_L1+3
VERA_L1_HSCROLL_H	= VERA_L1+4
VERA_L1_VSCROLL_L	= VERA_L1+5
VERA_L1_VSCROLL_H	= VERA_L1+6
VERA_AUDIO		= VERA_L1+7
VERA_AUDIO_CTRL		= VERA_AUDIO
VERA_AUDIO_RATE		= VERA_AUDIO+1
VERA_AUDIO_DATA		= VERA_AUDIO+2
VERA_SPI_DATA		= VERA_AUDIO+3
VERA_SPI_CTRL		= VERA_AUDIO+4

; ******************** Macro Definitions ********************
; !macro VERA_SET_ADDR .addr, [.stride]
; !macro VERA_SET_STRIDE .stride
; !macro VERA_GOXY .xc, .yc, [.abs]
; !macro VERA_DCSEL .sel
; !macro VERA_ADDRSEL .sel
; !macro VERA_RESET
; !macro VERA_SET_SPRITES .ena
; !macro VERA_SET_L0 .ena
; !macro VERA_SET_L1 .ena

; ******************** Addresses ********************
VERA_PSG_REGISTERS	= $1F9C0
VERA_PALETTE		= $1FA00
VERA_SPRITE_ATTRIBS	= $1FC00

; ******************** Offsets ********************
VERA_PAL_GREEN_BLUE	= 0
VERA_PAL_RED		= 1

VERA_SPRITE_ADDR_LOW	= 0
VERA_SPRITE_ADDR_HIGH	= 1
VERA_SPRITE_X_LOW	= 2
VERA_SPRITE_X_HIGH	= 3
VERA_SPRITE_Y_LOW	= 4
VERA_SPRITE_Y_HIGH	= 5
VERA_SPRITE_CONFIG	= 6
VERA_SPRITE_SIZE	= 7

VERA_PSG_FREQ_LOW	= 0
VERA_PSG_FREQ_HIGH	= 1
VERA_PSG_VOLUME		= 2
VERA_PSG_PULSE_WIDTH	= 3

; ******************** Constants ********************
INC0			= 0
INC1			= 1
INC2			= 2
INC4			= 3
INC8			= 4
INC16			= 5
INC32			= 6
INC64			= 7
INC128			= 8
INC256			= 9
INC512			= 10
INC40			= 11
INC80			= 12
INC160			= 13
INC320			= 14
INC640			= 15

DISABLED		= 0
VGA			= 1
COMPOSITE		= 2
RGB			= 3

TILES32			= 0
TILES64			= 1
TILES128		= 2
TILES256		= 3

PIX8			= 0
PIX16			= 1
PIX32			= 2
PIX64			= 4

BPP1			= 0
BPP2			= 1
BPP4			= 2
BPP8			= 3

SPRITE_4BPP		= 0
SPRITE_8BPP		= 1

VSYNC_BIT		= %00000001
LINE_BIT		= %00000010
SPRCOL_BIT		= %00000100
AFLOW_BIT		= %00001000

; ******************** Macros ********************

; **************************************************************************
; Set the VERA Address and stride. if stride is negative, the DECR bit will
; be set, otherwise it is reset.
; **************************************************************************
; INPUT:	.addr = 17 bit address to set 0xxxx - 1xxxx
;		.stride = 4 bit signed inc/dec value - negative value decrements
; USES:		A register
; **************************************************************************
.macro VERA_SET_ADDR addr, stride
	.ifnblank stride
		.if stride < 0
			lda	#((^addr) | $08 | ((0-stride)<<4))
		.else
			lda	#((^addr) | (stride)<<4)
		.endif
	.else
		lda #(^addr) | $10
	.endif
	sta	VERA_ADDR_H
	lda	#>addr
	sta	VERA_ADDR_M
	lda	#<addr
	sta	VERA_ADDR_L
.endmacro

; **************************************************************************
; Set the stride, if it is negative, the DECR bit will be set
; **************************************************************************
; INPUT:	.stride = 4 bit signed inc/dec value - negative val decrements
; USES:		A register
; **************************************************************************
.macro VERA_SET_STRIDE stride
	lda	VERA_ADDR_H
	.if stride < 0
		and	#$0F
		ora	#($08 | ((0-stride)<<4))
	.else
		and	#$07
		ora	#(stride<<4)
	.endif
	sta	VERA_ADDR_H
.endmacro

; **************************************************************************
; Set VERA address to point at a specific X and Y coordinate in 80x60 or
; 40x30 text mode.
; **************************************************************************
; INPUT:	.xc = X coordinate
;		.yc = Y coordinate
;		[.abs] = absolute or immediate arguments
;			 1=absolute, 0 or omitted =immediate
; USES:		A register
; **************************************************************************
.macro VERA_GOXY xc, yc, abs
	.ifnblank abs
		.if abs = 0
			lda	#(yc+$B0)
			sta	VERA_ADDR_M
			lda	#(xc<<1)
			sta	VERA_ADDR_L
		.else
			lda	yc
			clc
			adc	#$B0
			sta	VERA_ADDR_M
			lda	xc
			asl
			sta	VERA_ADDR_L
		.endif
	.else
		lda	#(yc+$B0)
		sta	VERA_ADDR_M
		lda	#(xc<<1)
		sta	VERA_ADDR_L
	.endif
.endmacro

; **************************************************************************
; Set the VERA DCSEL bit
; **************************************************************************
; INPUT:	.sel = Value DCSEL bit should be set to
; USES:		A register
; **************************************************************************
.macro VERA_DCSEL sel
	lda	VERA_CTRL
	.if sel = 0
		and	#%11111101	; Clear DCSEL bit
	.else
		ora	#%00000010	; Set DCSEL bit
	.endif
	sta	VERA_CTRL
.endmacro

; **************************************************************************
; Set the VERA ADDRSEL bit
; **************************************************************************
; INPUT:	.sel = Value ADDRSEL bit should be set to
; USES:		A register
; **************************************************************************
.macro VERA_ADDRSEL sel
	lda	VERA_CTRL
	.if sel = 0
		and	#%11111110	; Clear ADDRSEL bit
	.else
		ora	#%00000001	; Set ADDRSEL bit
	.endif
	sta	VERA_CTRL
.endmacro

; **************************************************************************
; Reset the VERA
; **************************************************************************
; USES:		A register
; **************************************************************************
.macro VERA_RESET
	lda	#%10000000		; Set the RESET bit in CTRL register
	sta	VERA_CTRL
.endmacro

; **************************************************************************
; Set Sprites Enable bit
; **************************************************************************
; INPUT:	.ena - 0=Sprites Disabled, 1=Sprites Enabled
; USES:		A register
; **************************************************************************
.macro VERA_SET_SPRITES ena
	lda	VERA_DC_VIDEO
	.if ena = 0
		and	#%10111111	; Clear Sprites Enabled bit
	.else
		ora	#%01000000	; Set Sprites Enabled bit
	.endif
	sta	VERA_DC_VIDEO
.endmacro

; **************************************************************************
; Set Layer0 Enable bit
; **************************************************************************
; INPUT:	.ena - 0=Layer0 Disabled, 1=Layer0 Enabled
; USES:		A register
; **************************************************************************
.macro VERA_SET_L0 ena
	lda	VERA_DC_VIDEO
	.if ena = 0
		and	#%11101111	; Clear Layer0 Enabled bit
	.else
		ora	#%00010000	; Set Layer0 Enabled bit
	.endif
	sta	VERA_DC_VIDEO
.endmacro

; **************************************************************************
; Set Layer1 Enable bit
; **************************************************************************
; INPUT:	.ena - 0=Layer1 Disabled, 1=Layer1 Enabled
; USES:		A register
; **************************************************************************
.macro VERA_SET_L1 ena
	lda	VERA_DC_VIDEO
	.if ena = 0
		and	#%11011111	; Clear Layer1 Enabled bit
	.else
		ora	#%00100000	; Set Layer1 Enabled bit
	.endif
	sta	VERA_DC_VIDEO
.endmacro


.endif
