.export default_palette

.include "banks.inc"
.include "graphics.inc"

.import jsrfar

.macro graph_call addr
    jsr jsrfar
    .word addr
    .byte BANK_GRAPH
.endmacro

.segment "GRAPH"

default_palette:
    graph_call gr_default_palette
    rts
