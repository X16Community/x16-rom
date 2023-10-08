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

;******************************************************************************
;Function name.......: util_bin_to_bcd
;Purpose.............: Converts a binary value to a BCD value
;Input...............: 24 bit binary value, X=low, Y=mid, A=high
;Returns.............: Pointer to 32 bit BCD value, X=addressL, Y=addressH
;Error returns.......: None
;Credits.............: This routine is based on Andrew Jacobs code published
;                      here: http://www.6502.org/source/integers/hex2dec-more.htm
;                      The function basically switches to decimal mode and then
;                      adds the bits together
.proc util_bin_to_bcd
    ;Store 24 bit input
    stx input
    sty input+1
    sta input+2

    ;Clear 32 bit output
    stz output
    stz output+1
    stz output+2
    stz output+3

    ;Number of input bits
    ldx #24

    ;Set decimal mode
    sed

loop:
    ;Rotate input, leftmost bit -> C
    asl input
    rol input+1
    rol input+2
    
    ;32 bit addition. Value of C from previous operation is the actual input. Therefore C is not cleared.
    lda output
    adc output
    sta output
    
    lda output+1
    adc output+1
    sta output+1

    lda output+2
    adc output+2
    sta output+2

    lda output+3
    adc output+3
    sta output+3

    ;Decrease bit counter, continue if >0
    dex
    bne loop

    ;Go back to binary mode
    cld

    ;Set pointer to output, and we're done
    ldx #<output
    ldy #>output
 
    rts
    
input = tempvars        ;3 bytes
output = tempvars+3     ;4 bytes
.endproc

;******************************************************************************
;Function name.......: util_bcd_to_bin
;Purpose.............: Converts a BCD value to a binary value
;Input...............: Pointer to 32 bit BCD value, X=AddressL, Y=AddressH
;Returns.............: 24 bit binary value, X=low, Y=mid, A=high
;Error returns.......: None
;Credits.............: This routine is based on an article by Marvin L. De Jong
;                      published here: 
;                      https://www.atarimagazines.com/compute/issue17/221_1_A_GENERAL_PURPOSE_BCD-TO-BINARY_ROUTINE.php
;                      De Jong was in his turn inspired by the book 
;                      Microcomputer-Based Design, by John B. Peatman, 
;                      McGraw Hill, New York, 1977, p 400.
;
;                      The technique is based on continuous dividing the input by two and
;                      storing the remainders as answer. The trick is to adjust the 
;                      answer by subtracting 3 from each nibble if the highest 
;                      bit is set. Why does this work?  I guess you have to read 
;                      those publications.
.proc util_bcd_to_bin
    ;Copy input to local variable
    stx TMP1_ADR
    sty TMP1_ADR+1
    ldy #0

:   lda (TMP1_ADR),y
    sta bcd_val,y
    iny
    cpy #5          ;The input is 32 bits = 4 bytes. Thus we've copied all when Y=5
    bne :-
    
    ;Prepare loop
    ldy #32         ;Output bit count, internally 32 bits, but the function only returns the lowest 24 bits. The highest 8 bits are discarded.
    ldx #3          ;Byte index (corresponds to 32 bit input, bytes 0 to 3)

    clc             ;Clear carry and push processor status including carry flag to stack
    php

loop:
    ;Get processor status from stack. We're really only interested in carry flag
    plp

    ;Divide by 2, remainder in carry flag
    ror bcd_val,x

    ;Save processor status including carry flag on stack again
    php

    ;Adjust high nibble: If bit 7=1 subtract $30; This is the essential "trick" in De Jong's and Peatman's
    ;above mentioned publications. 
    bit bcd_val,x
    bpl :+              ;bpl branches if bit 7 is clear (a positive number)
    sec
    lda bcd_val,x
    sbc #$30
    sta bcd_val,x

    ;Adjust low nibble: If bit 3=1 subtract $3; The same "trick" but for the low nibble
:   lda bcd_val,x
    and #8              ;The bpl op code doesn't work here, checking bit 3 by anding it
    beq next_byte
    sec
    lda bcd_val,x
    sbc #3
    sta bcd_val,x

next_byte:
    dex
    cpx #$ff
    bne loop

    ;Reset X for next loop
    ldx #3

    ;Get C from stack, and rotate to binary output
    plp
    ror bin_val+3
    ror bin_val+2
    ror bin_val+1
    ror bin_val
    
    ;Prepare stack for next loop, carry not set when we start the loop
    clc
    php
    
    dey             ;If Y=0 we're done with all 32 bits
    bne loop

    ;Clean stack
    plp

    ;Fetch result and exit
    ldx bin_val
    ldy bin_val+1
    lda bin_val+2    

    rts

    bcd_val = tempvars      ;4 bytes
    bin_val = tempvars+4    ;4 bytes
.endproc

;******************************************************************************
;Function name.......: util_bcd_to_str
;Purpose.............: Converts a BCD value to a null terminated string
;Input...............: Pointer to 32 bit BCD value, X=AddressL, Y=AddressH
;Returns.............: Pointer to string, X=AddressL, Y=AddressH
;Error returns.......: None
.proc util_bcd_to_str
    ;Copy input to local variable
    stx TMP1_ADR
    sty TMP1_ADR+1
    ldy #0

:   lda (TMP1_ADR),y
    sta input,y
    iny
    cpy #5
    bne :-

    ldx #4      ;Byte index, start with rightmost byte (MSB)
    ldy #0      ;Char index, start from left

build_str:
    ;Get value from high nibble
    lda input-1,x       ;"input-1" is needed because X starts from 4 (i.e. last index+1); this makes the exit test simpler - maybe I'm optimizing too much?
    lsr
    lsr
    lsr
    lsr
    clc
    adc #48
    sta output,y
    iny

    ;Get value from low nibble
    lda input-1,x
    and #15
    clc
    adc #48
    sta output,y
    iny

    ;Decrease input byte index, if = 0 we're done
    dex
    bne build_str

add_null:
    lda #0
    sta output,y

strip_leading_zeros:
    ;Look for first non "0" value, and set the start of the output string to that position
    ldx #0
:   lda output,x
    cmp #48
    bne exit
    inx
    cpx #7          ;We must break this search at position 7. Otherwise input value 0 would return an empty string.
    bcc :-

exit:
    txa     ;Start of string from search for non 0 value above; added to the output pointer
    clc
    adc #<output
    tax
    lda #0
    adc #>output
    tay
 
    rts
    
input = tempvars            ;4 bytes
output = tempvars+4         ;9 bytes (8 figures + null)
.endproc

;******************************************************************************
;Function name.......: util_str_to_bcd
;Purpose.............: Converts string to bcd value
;Input...............: Pointer to null terminated string, X=AddressL, Y=AddressH
;                      Input beyond 8 digits will be ignored
;Returns.............: Pointer to 32 bit BCD value, X=AddressL, Y=AddressH
;Error returns.......: C=1 if invalid input, else C=0
.proc util_str_to_bcd
    ;Setup zero page vectors
    stx TMP1_ADR
    sty TMP1_ADR+1

    ;Clear output
    stz bcd_val
    stz bcd_val+1
    stz bcd_val+2
    stz bcd_val+3

;Going arabic. We need to parse from right to left, therefore go to end of string
    ldy #0
:   lda (TMP1_ADR),y
    beq prepare
    iny
    bra :-

prepare:
    cpy #0
    beq invalid     ;String len = 0 is invalid input

    dey             ;Decrease Y to step back to the last digit. Y was at the terminating null char before this.
    ldx #0

loop:
    ;Get input char and subtract 48
    lda (TMP1_ADR),y
    sec
    sbc #48
    bcc invalid         ;Char was less than 48, exit with error
    cmp #10
    bcs invalid         ;Char was greater than 57, exit with error
    sta bcd_val,x
    
    ;Move index to next char, if Y wraps around to $ff we're done
    dey
    cpy #$ff
    beq end

    ;Get input char and subtract 48 as above
    lda (TMP1_ADR),y
    sec
    sbc #48
    bcc invalid
    cmp #10
    bcs invalid

    ;Multiply by 16, to store every other input char in the outout high nibble
    asl
    asl
    asl
    asl
    ora bcd_val,x
    sta bcd_val,x
    
    ;Increase output index and decrease input index. Exit if input index=ff
    inx
    dey
    cpy #$ff
    bne loop

end:
    ;Default exit
    clc
    ldx #<bcd_val
    ldy #>bcd_val
    rts

invalid:
    ;Exit if input value invalid (not only digits in string or zero len string)
    sec
    ldx #<bcd_val
    ldy #>bcd_val
    rts

len = tempvars          ;1 byte
bcd_val = tempvars+1    ;4 bytes

.endproc

;******************************************************************************
;Function name.......: util_strlen
;Purpose.............: Returns length of null terminated string; this function
;                      assumes that the input string length is less than 
;                      256 chars
;Input...............: Pointer to null terminated string, X=AddressL, Y=AddressH
;Returns.............: Y=String len
;Error returns.......: Nothing
.proc util_strlen
    stx TMP1_ADR
    sty TMP1_ADR+1
    ldy #0

:   lda (TMP1_ADR),y
    beq done
    iny
    bra :-

done:
    rts
.endproc