.macro set_carry_if_65c816
clc
.byte $E2, $01 ; sep #$01
.endmacro
