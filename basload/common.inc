;BSD 2-Clause License
;
;Copyright (c) 2021-2023, Stefan Jakobsson
;All rights reserved.

;Redistribution and use in source and binary forms, with or without
;modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this
;   list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice,
;   this list of conditions and the following disclaimer in the documentation
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.export TEMP1, TEMP2

RAM_SEL = $00
ROM_SEL = $01
BASLOAD_RAM1 = 1

KERNAL_CLOSE = $ffc3
KERNAL_CLRCHN = $ffcc
KERNAL_SETLFS = $ffba
KERNAL_LOAD = $ffd5
KERNAL_SETNAM = $ffbd
KERNAL_OPEN = $ffc0
KERNAL_CHKIN = $ffc6
KERNAL_CHKOUT = $ffc9
KERNAL_CHRIN = $ffcf
KERNAL_READST = $ffb7
KERNAL_CHROUT = $ffd2
KERNAL_RDTIM = $ffde
KERNAL_VERSION = $ff80
KERNAL_VARTAB = $03E1
KERNAL_ARYTAB = $03E3
KERNAL_STREND = $03E5
KERNAL_LINNUM = $d4
KERNAL_FETVEC = $ff74
KERNAL_SAVE = $ffd8
KERNAL_MEMBOT = $ff9c
KERNAL_MEMTOP = $ff99  

BASIC_CHRGET = $00e7
BASIC_IGONE = $0308

KERNAL_R0 = $02
KERNAL_R1 = $04
KERNAL_R2 = $06
KERNAL_R3 = $08

.ZEROPAGE
    TEMP1: .res 2
    TEMP2: .res 2

.segment "VARS"
    bridge_code: .res 42
    rom_bank: .res 1
.CODE
