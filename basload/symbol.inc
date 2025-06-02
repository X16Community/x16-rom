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

; Symbol table layout
; -------------------
; In this code, symbols refer to BASIC commands, labels and variables. 
; The symbol table data is stored in RAM banks SYMBOL_FIRST_BANK to
; SYMBOL_LAST_BANK.
; 
; The symbols are kept in a hash map, where symbol names are used as keys.
; Pearson hashing is used to create hash values.
;
; As the hash function only produces an 8-bit value, collisions will happen 
; frequently. Testing shows that the number of collisions per hash value
; still is reasonable for the purpose of efficient symbol lookup.
;
; Collisions are handled by chaining. Symbols sharing the same hash value
; are arranged in linked lists, which in the source are referred to as
; "buckets".
;
; The arrays "symbol_bucket_bank" and "symbol_bucket_offset" point to the
; head of these linked lists. The arrays are stored in RAM bank BASLOAD_RAM1.
; There is one head pointer for each possible hash value (0..255).
; 
; An entry in the symbol table contains the following information:
; 
; Offset Size Description
; -----------------------------------------------------------------------------
; 00     03   Next symbol (bank, addrl, addrh), bank=0 => end of chain
; 03     01   Symbol name length
; 04     01   Symbol type
; 05     02   Value
; 07     ??   Symbol name, max 64 bytes
;
; The symbol table entry length varies according to the length of the symbol
; name. If symbol names are 10 characters in avarage, the table fits
; about 3,800 symbols.

; Exports needed for unit testing
.export symbol_init, symbol_add, symbol_find, symbol_buckets_bank, file_buf, line_dstlin, symbol_next_bank, symbol_pointer

; Banked RAM usage
SYMBOL_FIRST_BANK       = 2
SYMBOL_LAST_BANK        = 9

; Symbol table entry fields
SYMBOL_NEXT_BANK        = 0
SYMBOL_NEXT_ADDR        = 1
SYMBOL_LEN              = 3
SYMBOL_TYPE             = 4
SYMBOL_VALUE            = 5
SYMBOL_NAME             = 7
SYMBOL_MAXLEN           = 64

; Symbol entry types
SYMBOLTYPE_LABEL        = 0
SYMBOLTYPE_VARIABLE     = 1
SYMBOLTYPE_TOKEN        = 2
SYMBOLTYPE_RESERVED_VAR = 3
SYMBOLTYPE_CONTROL_CHAR = 4
SYMBOLTYPE_LITERAL_PASS1 = 5
SYMBOLTYPE_LITERAL_PASS2 = 6

; Variables
.ZEROPAGE
    symbol_pointer: .res 2

.segment "VARS"
    symbol_next_var: .res 2
    symbol_last_var: .res 2
    symbol_next_bank: .res 1
    symbol_next_addr: .res 2

.segment "RAM1"
    symbol_buckets_bank: .res $100
    symbol_buckets_addrl: .res $100
    symbol_buckets_addrh: .res $100
.CODE

;******************************************************************************
;Function name: symbol_init
;Purpose......: Initializes symbol functions and data
;Input........: Nothing
;Output.......: Nothing
;Error........: None
.proc symbol_init
    ; Set all buckets to null
    lda #BASLOAD_RAM1
    sta RAM_SEL

    ldx #0
    lda #0
:   sta symbol_buckets_bank,x
    inx
    cpx #0
    bne :-

    ; Set next symbol table entry location in banked RAM
    lda #SYMBOL_FIRST_BANK
    sta symbol_next_bank
    stz symbol_next_addr
    lda #$a0
    sta symbol_next_addr+1

    ; Set next available variable name to "A"
    lda #'A'
    sta symbol_next_var
    lda #0
    sta symbol_next_var+1

    ; Set last variable name to NULL
    stz symbol_last_var
    stz symbol_last_var+1

    ; Add ? as PRINT statement
    lda #'?'
    sta file_buf
    ldx #0
    ldy #0

    lda #$99
    sta token_next_id
    stz token_next_id+1
    lda #SYMBOLTYPE_TOKEN
    jsr symbol_add

    ; Add reserved variables to the symbol table
    lda #'S'
    sta file_buf
    lda #'T'
    sta file_buf+1
    ldx #0
    ldy #1
    lda #SYMBOLTYPE_RESERVED_VAR
    jsr symbol_add

    lda #'T'
    sta file_buf
    lda #'I'
    sta file_buf+1
    ldx #0
    ldy #1
    lda #SYMBOLTYPE_RESERVED_VAR
    jsr symbol_add
    
    lda #'D'
    sta file_buf
    lda #'A'
    sta file_buf+1
    ldx #0
    ldy #1
    lda #SYMBOLTYPE_RESERVED_VAR
    jsr symbol_add

    rts

PRINT_TOKEN:
    .byt $99, $00
.endproc

;******************************************************************************
;Function name: symbol_add
;Purpose......: Adds an element to the symbol table
;Input........: X   Index in file_buf where symbol starts
;               Y   Index in file_buf where symbol ends
;               A   Symbol type
;                   0: Label
;                   1: Variable
;                   2: BASIC command/token
;                   3: Reserved variable, stored as type 1=variable
;                   4: PETSCII control char
;                   5: Defined literal (pass 1)
;                   6: Defined literal (pass 2)
;               C   1: Skip duplicate check
;Output.......: X/Y Symbol value (low/high byte)
;               A   0: OK
;Error........: A   1: Duplicate symbol
;                   2: Symbol table full
;                   3: No available variable name
;                   4: Symbol name too long
.proc symbol_add
    ; Store input
    stx index1
    sty index2
    sta type

    ; Check if duplicate
    bcs :+  ; Skip duplicate label check if C=1
    jsr symbol_find
    bcs :+ ; Symbol not found, continue
    lda #1
    rts

    ; Calculate len
:   sec
    lda index2
    sbc index1
    inc
    sta len
    cmp #SYMBOL_MAXLEN+1
    bcc :+
    lda #4
    rts

    ; Check if symbol table entry fits in current RAM bank
:   clc
    adc #7
    adc symbol_next_addr
    lda symbol_next_addr+1
    adc #0
    cmp #$c0
    bcc :+
    inc symbol_next_bank
    stz symbol_next_addr        ; Symbol doesn't fit, select next RAM bank
    lda #$a0
    sta symbol_next_addr+1

    ; Check if symbol table is full
:   lda symbol_next_bank
    cmp #SYMBOL_LAST_BANK+1
    bcc :+
    lda #2
    rts

    ; Check variable name availability
:   lda type
    cmp #SYMBOLTYPE_LABEL
    bne :+
    lda symbol_next_var
    cmp #'Z'+1
    bcc :+
    lda #3
    rts

    ; Calculate symbol name hash value
:   lda #0
    ldx index1
:   eor file_buf,x
    tay
    lda pearson_tbl,y
    cpx index2
    beq :+
    inx
    bra :-

:   sta hash

    ; Check if bucket is empty
    lda #BASLOAD_RAM1
    sta RAM_SEL
    ldy hash
    lda symbol_buckets_bank,y
    bne bucket_not_empty

bucket_empty:
    lda symbol_next_bank
    sta symbol_buckets_bank,y
    lda symbol_next_addr
    sta symbol_buckets_addrl,y
    lda symbol_next_addr+1
    sta symbol_buckets_addrh,y
    bra set_values

bucket_not_empty:
    tax ; Store bank in X
    lda symbol_buckets_addrl,y
    sta symbol_pointer
    lda symbol_buckets_addrh,y
    sta symbol_pointer+1

find_tail:
    ; Select RAN bank where item is stored
    stx RAM_SEL

    ; Check if end of chain (bank=0)
    ldy #SYMBOL_NEXT_BANK
    lda (symbol_pointer),y
    beq tail_found
    
    ; There're more items in the list, prepare to look at next item
    tax ; Next bank stored in X
    ldy #SYMBOL_NEXT_ADDR
    lda (symbol_pointer),y
    pha
    iny
    lda (symbol_pointer),y
    sta symbol_pointer+1
    pla
    sta symbol_pointer
    bra find_tail

tail_found:
    ; Store link to the new item we're inserting in the current tail item
    lda #SYMBOL_NEXT_BANK
    lda symbol_next_bank
    sta (symbol_pointer),y
    ldy #SYMBOL_NEXT_ADDR
    lda symbol_next_addr
    sta (symbol_pointer),y
    iny
    lda symbol_next_addr+1
    sta (symbol_pointer),y

set_values:
    ; Select RAM bank where the new item is stored
    lda symbol_next_bank
    sta RAM_SEL

    ; Set address to new item
    lda symbol_next_addr
    sta symbol_pointer
    lda symbol_next_addr+1
    sta symbol_pointer+1

    ; Copy symbol name
    ldx index1
    ldy #SYMBOL_NAME
:   lda file_buf,x
    sta (symbol_pointer),y
    cpx index2
    beq :+
    inx
    iny
    bra :-

    ; Set symbol name len
:   ldy #SYMBOL_LEN
    lda len
    sta (symbol_pointer),y

    ; Set next bank to 0 = NULL
    ldy #SYMBOL_NEXT_BANK
    lda #0
    sta (symbol_pointer),y

    ; Set symbol type
    ldy #SYMBOL_TYPE
    lda type
    sta (symbol_pointer),y

    ; Check if symbol type
    cmp #SYMBOLTYPE_LABEL
    bne variable

    ; New item is a label: Set value to current line number
    ldy #SYMBOL_VALUE
    lda line_dstlin
    sta (symbol_pointer),y
    tax
    iny
    lda line_dstlin+1
    sta (symbol_pointer),y
    tay
    jmp exit

variable:
    cmp #SYMBOLTYPE_VARIABLE
    bne reserved_var

    ; New item is a variable: Set value to next available variable name
    ldy #SYMBOL_VALUE
    lda symbol_next_var
    sta (symbol_pointer),y
    pha
    iny
    lda symbol_next_var+1
    sta (symbol_pointer),y
    tay

    ; Remember last assigned variable
    lda symbol_next_var
    sta symbol_last_var
    lda symbol_next_var+1
    sta symbol_last_var+1   

inc_var:
    ; Advance second character of the next available variable name
    inc symbol_next_var+1
    lda symbol_next_var+1
    
    ; If 1 => The current variable name is one character, next variable ends with '0'
    cmp #1
    beq :+
    
    ; Current variable name ends with a '9' => The next variable will end with 'A'
    cmp #'9'+1
    beq :++
    
    ; The current variable name ends with a 'Z' => The next variable is a single char
    cmp #'Z'+1
    bne chk_var

    inc symbol_next_var
    stz symbol_next_var+1
    bra chk_var

:   lda #'0'
    sta symbol_next_var+1
    bra chk_var

:   lda #'A'
    sta symbol_next_var+1

chk_var:
    ; Check if the next variable name is reserved
    ldx #0

chk_var_loop:
    ; Compare first char
    lda SYMBOLTYPE_RESERVED_VARs,x
    inx
    cmp symbol_next_var
    bne :+
    
    ; Compare second char
    lda SYMBOLTYPE_RESERVED_VARs,x
    inx

    ; There's a match in the reserved names table => try again
    cmp symbol_next_var+1
    beq inc_var

    ; Are we done?
    cpx #SYMBOLTYPE_RESERVED_VARs_end-SYMBOLTYPE_RESERVED_VARs
    bne chk_var_loop
    bra :++

:   ; Are we done?
    inx
    cpx #SYMBOLTYPE_RESERVED_VARs_end-SYMBOLTYPE_RESERVED_VARs
    bne chk_var_loop

:   ; Pull symbol low value from stack
    plx
    bra exit

reserved_var:
    cmp #SYMBOLTYPE_RESERVED_VAR
    bne control_char

    ldy #SYMBOL_TYPE
    lda #SYMBOLTYPE_VARIABLE
    sta (symbol_pointer),y

    ldy #SYMBOL_VALUE
    ldx index1
:   lda file_buf,x
    sta (symbol_pointer),y
    cpx index2
    beq :+
    inx
    iny
    cpy #SYMBOL_VALUE+2
    bne :-
:   ldx #0
    ldy #0
    bra exit

control_char:
    cmp #SYMBOLTYPE_CONTROL_CHAR
    bne token

    ldy #SYMBOL_VALUE
    lda controlcode_value
    sta (symbol_pointer),y
    iny
    lda #0
    sta (symbol_pointer),y
    bra exit

token:
    ldy #SYMBOL_VALUE
    lda token_next_id
    sta (symbol_pointer),y
    iny
    lda token_next_id+1
    sta (symbol_pointer),y

exit:
    ; Set next item address
    clc
    lda symbol_next_addr
    adc len
    sta symbol_next_addr
    lda symbol_next_addr+1
    adc #0
    sta symbol_next_addr+1

    clc
    lda symbol_next_addr
    adc #7
    sta symbol_next_addr
    lda symbol_next_addr+1
    adc #0
    sta symbol_next_addr+1

    lda #0
    rts

.segment "VARS"
    index1: .res 1
    index2: .res 2
    type: .res 1
    hash: .res 1
    len: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: symbol_find
;Purpose......: Searches symbol table for a given symbol name
;Input........: X   Index in file_buf where symbol starts
;               Y   Index in file_buf where symbol ends
;Output.......: X,Y Value (low, high byte)
;               A   Symbol type
;                   0: Label
;                   1: Variable
;                   2: BASIC token
;                   3: Reserved variable, stored as type 1=variable
;                   4: PETSCII control char
;                   5: Defined literal (pass 1)
;                   6: Defined literal (pass 2)
;Error........: C=1 if symbol not found
.proc symbol_find
    ; Store input params
    stx index1
    sty index2

    ; Calculate symbol name length
    sec
    lda index2
    sbc index1
    ina
    sta len
    
    ; Calculate symbol name hash value
    lda #0
    ldx index1
:   eor file_buf,x
    tay
    lda pearson_tbl,y
    cpx index2
    beq :+
    inx
    bra :-
:   sta hash

    ; Check if bucket head is NULL
    lda #BASLOAD_RAM1               ; Select RAM bank 1
    sta RAM_SEL
    
    ldy hash
    lda symbol_buckets_bank,y
    beq not_found                   ; Bucket head was null => symbol doesn't exist

    ; OK, let's look what we find in the symbol table...
    tax                             ; Store bank in X temporarily

    lda symbol_buckets_addrl,y
    sta symbol_pointer
    lda symbol_buckets_addrh,y
    sta symbol_pointer+1

loop:    
    stx RAM_SEL                     ; Set RAM bank where item is stored

    ldy #SYMBOL_LEN                 ; Compare lengths
    lda (symbol_pointer),y
    cmp len
    bne next

    ldy #SYMBOL_NAME                ; Compare names
    ldx index1
:   lda (symbol_pointer),y
    cmp file_buf,x
    bne next
    cpx index2
    beq found
    inx
    iny
    bra :-

next:                               ; It wasn't a match, look at next item in the bucket
    ldy #SYMBOL_NEXT_BANK
    lda (symbol_pointer),y
    beq not_found                   ; Next bank = 0 => No more items in this bucket
    
    pha                             ; Store bank on stack
    ldy #SYMBOL_NEXT_ADDR
    lda (symbol_pointer),y
    pha
    iny
    lda (symbol_pointer),y
    sta symbol_pointer+1
    pla
    sta symbol_pointer
    
    plx                             ; Get bank from stack
    bra loop

found:
    ldy #SYMBOL_TYPE
    lda (symbol_pointer),y
    pha
    ldy #SYMBOL_VALUE
    lda (symbol_pointer),y
    tax
    ldy #SYMBOL_VALUE+1
    lda (symbol_pointer),y
    tay
    pla
    clc
    rts

not_found:
    sec
    rts

.segment "VARS"
    index1: .res 1
    index2: .res 2
    hash: .res 1
    len: .res 1
.CODE

.endproc

;******************************************************************************
;Function name: symbol_update
;Purpose......: Searches symbol table for a given symbol name
;Input........: X   Index in file_buf where symbol starts
;               Y   Index in file_buf where symbol ends
;               A   New symbol type
;               token_next_id new value
.proc symbol_update
    pha
    jsr symbol_find
    pla
    bcs not_found

found:
    ldy #SYMBOL_TYPE
    sta (symbol_pointer),y
    ldy #SYMBOL_VALUE
    lda token_next_id
    sta (symbol_pointer),y
    iny
    lda token_next_id+1
    sta (symbol_pointer),y

    clc
    rts

not_found:
    sec
    rts
.endproc

SYMBOLTYPE_RESERVED_VARs:
    .byt "DA"
    .byt "IF"
    .byt "FN"
    .byt "GO"
    .byt "MX"
    .byt "MY"
    .byt "MB"
    .byt "ON"
    .byt "OR"
    .byt "ST"
    .byt "TI"
    .byt "TO"
SYMBOLTYPE_RESERVED_VARs_end:
