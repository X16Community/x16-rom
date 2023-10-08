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
;Function name.......: irq_init
;Purpose.............: Initializes the custom interrupt handler
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.if target_mem=target_ram
.proc irq_init
    ;Backup default interrupt handler
    lda $0314
    sta irq_default_handler
    lda $0315
    sta irq_default_handler+1

    ;Set vectors to our custom handler
    sei
    
    stz irq_flag
    lda #<irq_handler
    sta $0314
    lda #>irq_handler
    sta $0315

    cli
    rts
.endproc
.endif

.if target_mem=target_rom
.proc irq_init
    ;Backup default interrupt handler
    lda $0314
    sta irq_default_handler
    lda $0315
    sta irq_default_handler+1

    ;Set vectors to our custom handler
    sei
    
    lda #<(bridge_code+bridge_irq-bridge_kernal)
    sta $0314
    lda #>(bridge_code+bridge_irq-bridge_kernal)
    sta $0315

    cli
    rts
.endproc
.endif

;******************************************************************************
;Function name.......: irq_restore
;Purpose.............: Restores original IRQ handler
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc irq_restore
    sei
    lda irq_default_handler
    sta $0314
    lda irq_default_handler+1
    sta $0315
    cli
    rts
.endproc

;******************************************************************************
;Function name.......: irq_handler
;Purpose.............: Custom interrupt handler
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc irq_handler
    ;Verify vblank interrupt
    lda VERA_ISR
    and #$01
    beq exit

    ;Set IRQ flag
    lda #1
    sta irq_flag
    
exit:
    .if (::target_mem=target_ram)
        jmp (irq_default_handler)
    .endif

    .if (::target_mem=target_rom)
        rts
    .endif
.endproc

.segment "VARS"
    irq_default_handler:    .res 2              ;2 bytes
    irq_flag:               .res 1
.CODE