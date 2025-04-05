.export upload_default_palette

.include "banks.inc"
.include "graphics.inc"

.import jsrfar

.macro graph_call addr
    jsr jsrfar
    .word addr
    .byte BANK_GRAPH
.endmacro

.segment "GRAPH"

upload_default_palette:
    graph_call gr_upload_default_palette
    rts
