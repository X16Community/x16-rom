;*******************************************************************************
;Copyright 2022-2023, Stefan Jakobsson
;
;Redistribution and use in source and binary forms, with or without modification, 
;are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this 
;   list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice, 
;   this list of conditions and the following disclaimer in the documentation 
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” 
;AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
;IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
;FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
;DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
;SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
;CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
;OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
;OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;*******************************************************************************

.import __ZP_START__, __ZP_LAST__, __VARS_LOAD__

;*****************************************************************************
;KERNAL
;*****************************************************************************

;RAM and ROM select
.define BNK_SEL $00 
.define ROM_SEL $01

;Current character set
.define KERNAL_MODE $0372

;File management
.define KERNAL_CLALL $ffe7
.define KERNAL_CLOSE $ffc3
.define KERNAL_CLRCHN $ffcc 
.define KERNAL_SETLFS $ffba
.define KERNAL_SETNAM $ffbd
.define KERNAL_OPEN $ffc0
.define KERNAL_CHKIN $ffc6
.define KERNAL_CHKOUT $ffc9
.define KERNAL_CHROUT $ffd2
.define KERNAL_CHRIN $ffcf
.define KERNAL_READST $ffb7
.define KERNAL_MEMTOP $ff99
.define KERNAL_DECOMPRESS $feed
.define KERNAL_MACPTR $ff44
.define KERNAL_SCREEN_MODE $ff5f

;Keyboard & mouse
.define KERNAL_GETIN $ffe4
.define KERNAL_MOUSE_CONFIG $ff68
.define KERNAL_MOUSE_GET $ff6b

;Other
.define KERNAL_SCREEN_SET_CHARSET $ff62

;*****************************************************************************
;VERA
;*****************************************************************************
.define VERA_L $9f20
.define VERA_M $9f21
.define VERA_H $9f22

.define VERA_D0 $9f23
.define VERA_D1 $9f24

.define VERA_CTRL $9f25
.define VERA_ISR $9F27
.define VERA_VIDEO $9f29

.define VERA_L0_CONFIG $9f2d
.define VERA_L0_TILEBASE $9f2f

.define VERA_L1_CONFIG $9f34
.define VERA_L1_MAPBASE $9f35
.define VERA_L1_TILEBASE $9f36

.define VERA_BUFADR_M $b0
.define VERA_BUFADR_H $01

;*****************************************************************************
;ZERO PAGE "REGISTERS"
;*****************************************************************************
r0 = $02
r1 = $04
r2 = $06
r3 = $08
r4 = $0a
r5 = $0c
r6 = $0e
r7 = $10
r8 = $12
r9 = $14
r10 = $16
r11 = $18
r12 = $1a
r13 = $1c
r14 = $1e
r15 = $20

;*****************************************************************************
;ZERO PAGE VECTORS AND VARIABLES
;*****************************************************************************
.segment "ZEROPAGE"

;Pointer to memory location: Cursor position
CRS_BNK:    .res 1   ;Bank
CRS_ADR:    .res 2   ;Address
CRS_IDX:    .res 1   ;Index

;Pointer to memory location: First visible character of the currently edited line
LNV_BNK:    .res 1   ;Bank
LNV_ADR:    .res 2   ;Address
LNV_IDX:    .res 1   ;Byte index

;Pointer to memory location: First visible character of the screen (top left)
SCR_BNK:    .res 1   ;Bank
SCR_ADR:    .res 2   ;Address
SCR_IDX:    .res 1   ;Index

;Temporary pointers to memory locations, used for miscellaneous (short-term) purposes
;Warning: Any routine may use these temp pointers at any time and for whatever reason
TMP1_BNK:   .res 1   ;Bank
TMP1_ADR:   .res 2   ;Address MSB
TMP1_IDX:   .res 1   ;Index

TMP2_BNK:   .res 1   ;Bank
TMP2_ADR:   .res 2   ;Address MSB
TMP2_IDX:   .res 1   ;Index

.CODE

;*****************************************************************************
;Global variables not stored in zero page
;*****************************************************************************
.segment "VARS"

bridge_code:            .res 84             ;Bridge code, used by ROM version of the program
APP_MOD:                .res 1              ;1 byte, application mode
APP_QUIT:               .res 1              ;1 byte, used to signal program exit
.if target_mem=target_rom
    rom_bank:           .res 1              ;Bank where ROM version of the program is stored
.endif
tempvars:               .res 16             ;Temporary variables

.CODE

;*****************************************************************************
;VARIABLES/BUFFERS STORED IN RAM BANK 1
;*****************************************************************************
mem_map                                 = $a000               ;1024 bytes ($a000-$a3ff)
clipboard_mem                           = $a400               ;3072 bytes ($a400-$afff)
ram_backup_storage                      = $b000               ;1280 bytes ($b000-$b4ff)
dir_entry                               = $b500               ;256 bytes
help_txt                                = $b600

;*****************************************************************************
;CONSTANTS
;*****************************************************************************
.define LF 10
.define CR 13          

.define SCREEN_TEXTMODE 0

.if SCREEN_TEXTMODE = 0
    .define SCREEN_WIDTH 80
    .define SCREEN_HEIGHT 60
.elseif SCREEN_TEXTMODE = 1
    .define SCREEN_WIDTH 80
    .define SCREEN_HEIGHT 30
.elseif SCREEN_TEXTMODE = 2
    .define SCREEN_WIDTH 40
    .define SCREEN_HEIGHT 60
.elseif SCREEN_TEXTMODE = 3
    .define SCREEN_WIDTH 40
    .define SCREEN_HEIGHT 30
.elseif SCREEN_TEXTMODE = 4
    .define SCREEN_WIDTH 40
    .define SCREEN_HEIGHT 15
.else
    .error "Unsupported screen mode"
.endif