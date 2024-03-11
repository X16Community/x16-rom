.macro set_carry_if_65c816
clc
.byte $E2, $03 ; sep #$03
.endmacro
